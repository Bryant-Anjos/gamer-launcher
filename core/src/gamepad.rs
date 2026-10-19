//! Leitura de controles de verdade (via `gilrs`) numa thread própria.
//! A interpretação dos eventos fica em [`crate::input`].

use crate::input::{GamepadAction, InputMapper, PadButton, PadEvent, StickAxis};
use gilrs::{Axis, Button, EventType, Gilrs};
use std::ops::ControlFlow;
use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::{Arc, mpsc};
use std::thread::{self, JoinHandle};
use std::time::{Duration, Instant};
use thiserror::Error;

/// Intervalo máximo entre verificações do pedido de parada.
const STOP_POLL: Duration = Duration::from_millis(200);

#[derive(Debug, Error)]
pub enum GamepadError {
    #[error("não foi possível iniciar a leitura de controles: {0}")]
    Init(String),
}

pub fn pad_button_from(button: Button) -> PadButton {
    match button {
        Button::South => PadButton::South,
        Button::East => PadButton::East,
        Button::North => PadButton::North,
        Button::West => PadButton::West,
        Button::DPadUp => PadButton::DPadUp,
        Button::DPadDown => PadButton::DPadDown,
        Button::DPadLeft => PadButton::DPadLeft,
        Button::DPadRight => PadButton::DPadRight,
        Button::Start => PadButton::Start,
        Button::Select => PadButton::Select,
        Button::Mode => PadButton::Mode,
        Button::LeftTrigger => PadButton::LeftBumper,
        Button::RightTrigger => PadButton::RightBumper,
        _ => PadButton::Other,
    }
}

/// Alguns controles mandam o direcional como eixo; tratamos como o analógico.
pub fn stick_axis_from(axis: Axis) -> Option<StickAxis> {
    match axis {
        Axis::LeftStickX | Axis::DPadX => Some(StickAxis::LeftX),
        Axis::LeftStickY | Axis::DPadY => Some(StickAxis::LeftY),
        _ => None,
    }
}

fn pad_event_from(event: EventType) -> Option<PadEvent> {
    match event {
        EventType::ButtonPressed(button, _) => {
            Some(PadEvent::ButtonPressed(pad_button_from(button)))
        }
        EventType::ButtonReleased(button, _) => {
            Some(PadEvent::ButtonReleased(pad_button_from(button)))
        }
        EventType::AxisChanged(axis, value, _) => {
            stick_axis_from(axis).map(|axis| PadEvent::AxisMoved(axis, value))
        }
        EventType::Disconnected => Some(PadEvent::Disconnected),
        _ => None,
    }
}

/// Mantém a leitura ativa; ao ser descartado, para a thread e espera ela acabar.
pub struct ListenerHandle {
    stop: Arc<AtomicBool>,
    thread: Option<JoinHandle<()>>,
}

impl Drop for ListenerHandle {
    fn drop(&mut self) {
        self.stop.store(true, Ordering::Relaxed);
        if let Some(thread) = self.thread.take() {
            let _ = thread.join();
        }
    }
}

fn run_loop<F>(mut gilrs: Gilrs, stop: &AtomicBool, mut on_action: F)
where
    F: FnMut(GamepadAction) -> ControlFlow<()>,
{
    let started = Instant::now();
    let mut mapper = InputMapper::new();
    while !stop.load(Ordering::Relaxed) {
        let now_ms = || started.elapsed().as_millis() as u64;
        let until_repeat = mapper.next_deadline_ms().map_or(STOP_POLL, |deadline| {
            Duration::from_millis(deadline.saturating_sub(now_ms()))
        });
        let event = gilrs.next_event_blocking(Some(until_repeat.min(STOP_POLL)));

        let from_event = event
            .and_then(|event| pad_event_from(event.event))
            .and_then(|event| mapper.handle(event, now_ms()));
        let from_repeat = mapper.tick(now_ms());
        for action in from_event.into_iter().chain(from_repeat) {
            if on_action(action).is_break() {
                return;
            }
        }
    }
}

/// Começa a ler os controles. `on_action` roda na thread de leitura e pode
/// devolver `Break` para encerrar (por exemplo, quando a UI deixou de ouvir).
pub fn spawn_listener<F>(on_action: F) -> Result<ListenerHandle, GamepadError>
where
    F: FnMut(GamepadAction) -> ControlFlow<()> + Send + 'static,
{
    let stop = Arc::new(AtomicBool::new(false));
    let (ready_tx, ready_rx) = mpsc::channel();
    let thread_stop = Arc::clone(&stop);
    // `Gilrs` não atravessa threads: nasce e morre dentro da thread de leitura.
    let thread = thread::Builder::new()
        .name("gamepad-listener".into())
        .spawn(move || match Gilrs::new() {
            Ok(gilrs) => {
                let _ = ready_tx.send(Ok(()));
                run_loop(gilrs, &thread_stop, on_action);
            }
            Err(error) => {
                let _ = ready_tx.send(Err(error.to_string()));
            }
        })
        .map_err(|error| GamepadError::Init(error.to_string()))?;

    match ready_rx.recv() {
        Ok(Ok(())) => Ok(ListenerHandle {
            stop,
            thread: Some(thread),
        }),
        Ok(Err(message)) => Err(GamepadError::Init(message)),
        Err(_) => Err(GamepadError::Init(
            "a thread de leitura terminou antes de iniciar".into(),
        )),
    }
}
