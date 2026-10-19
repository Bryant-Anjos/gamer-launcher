//! Leitura de controles de verdade (via `gilrs`) numa thread própria.
//! A interpretação dos eventos fica em [`crate::input`].

use crate::input::{
    ButtonLayoutSetting, GamepadAction, InputMapper, PadButton, PadEvent, StickAxis,
};
use gilrs::{Axis, Button, EventType, Gilrs};
use std::ops::ControlFlow;
use std::sync::atomic::{AtomicBool, AtomicU8, AtomicUsize, Ordering};
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

/// Layout de botões escolhido pelo usuário, compartilhado entre a UI (que
/// muda) e a thread de leitura (que consulta a cada evento).
#[derive(Debug, Clone)]
pub struct SharedLayout(Arc<AtomicU8>);

impl SharedLayout {
    const AUTO: u8 = 0;
    const XBOX: u8 = 1;
    const NINTENDO: u8 = 2;

    pub fn new(setting: ButtonLayoutSetting) -> Self {
        let shared = Self(Arc::new(AtomicU8::new(Self::AUTO)));
        shared.set(setting);
        shared
    }

    pub fn set(&self, setting: ButtonLayoutSetting) {
        let code = match setting {
            ButtonLayoutSetting::Auto => Self::AUTO,
            ButtonLayoutSetting::Xbox => Self::XBOX,
            ButtonLayoutSetting::Nintendo => Self::NINTENDO,
        };
        self.0.store(code, Ordering::Relaxed);
    }

    pub fn get(&self) -> ButtonLayoutSetting {
        match self.0.load(Ordering::Relaxed) {
            Self::XBOX => ButtonLayoutSetting::Xbox,
            Self::NINTENDO => ButtonLayoutSetting::Nintendo,
            _ => ButtonLayoutSetting::Auto,
        }
    }
}

/// Mantém a leitura ativa; ao ser descartado, para a thread e espera ela acabar.
pub struct ListenerHandle {
    stop: Arc<AtomicBool>,
    connected: Arc<AtomicUsize>,
    layout: SharedLayout,
    thread: Option<JoinHandle<()>>,
}

impl ListenerHandle {
    /// Controles conectados agora (atualizado pela thread de leitura).
    pub fn connected_gamepads(&self) -> usize {
        self.connected.load(Ordering::Relaxed)
    }

    /// Muda o layout de botões sem reiniciar a leitura.
    pub fn set_layout_setting(&self, setting: ButtonLayoutSetting) {
        self.layout.set(setting);
    }

    pub fn layout_setting(&self) -> ButtonLayoutSetting {
        self.layout.get()
    }
}

fn count_connected(gilrs: &Gilrs) -> usize {
    gilrs
        .gamepads()
        .filter(|(_, pad)| pad.is_connected())
        .count()
}

impl Drop for ListenerHandle {
    fn drop(&mut self) {
        self.stop.store(true, Ordering::Relaxed);
        if let Some(thread) = self.thread.take() {
            let _ = thread.join();
        }
    }
}

fn run_loop<F>(
    mut gilrs: Gilrs,
    stop: &AtomicBool,
    connected: &AtomicUsize,
    layout: &SharedLayout,
    mut on_action: F,
) where
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
        // recontar só quando a lista pode ter mudado, não a cada eixo
        if event.as_ref().is_none_or(|event| {
            matches!(event.event, EventType::Connected | EventType::Disconnected)
        }) {
            connected.store(count_connected(&gilrs), Ordering::Relaxed);
        }

        let from_event = event.and_then(|event| {
            // o layout vale para o controle que mandou o evento: no modo
            // automático, um Nintendo e um Xbox conectados juntos não se misturam
            let vendor = gilrs
                .connected_gamepad(event.id)
                .and_then(|pad| pad.vendor_id());
            let layout = layout.get().resolve(vendor);
            let pad_event = pad_event_from(event.event)?;
            mapper.handle_with(layout, pad_event, now_ms())
        });
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
    spawn_listener_with(ButtonLayoutSetting::Auto, on_action)
}

/// Como [`spawn_listener`], com o layout de botões inicial escolhido.
pub fn spawn_listener_with<F>(
    layout: ButtonLayoutSetting,
    on_action: F,
) -> Result<ListenerHandle, GamepadError>
where
    F: FnMut(GamepadAction) -> ControlFlow<()> + Send + 'static,
{
    let shared_layout = SharedLayout::new(layout);
    let thread_layout = shared_layout.clone();
    let stop = Arc::new(AtomicBool::new(false));
    let connected = Arc::new(AtomicUsize::new(0));
    let (ready_tx, ready_rx) = mpsc::channel();
    let thread_stop = Arc::clone(&stop);
    let thread_connected = Arc::clone(&connected);
    // `Gilrs` não atravessa threads: nasce e morre dentro da thread de leitura.
    let thread = thread::Builder::new()
        .name("gamepad-listener".into())
        .spawn(move || match Gilrs::new() {
            Ok(gilrs) => {
                thread_connected.store(count_connected(&gilrs), Ordering::Relaxed);
                let _ = ready_tx.send(Ok(()));
                run_loop(
                    gilrs,
                    &thread_stop,
                    &thread_connected,
                    &thread_layout,
                    on_action,
                );
            }
            Err(error) => {
                let _ = ready_tx.send(Err(error.to_string()));
            }
        })
        .map_err(|error| GamepadError::Init(error.to_string()))?;

    match ready_rx.recv() {
        Ok(Ok(())) => Ok(ListenerHandle {
            stop,
            connected,
            layout: shared_layout,
            thread: Some(thread),
        }),
        Ok(Err(message)) => Err(GamepadError::Init(message)),
        Err(_) => Err(GamepadError::Init(
            "a thread de leitura terminou antes de iniciar".into(),
        )),
    }
}
