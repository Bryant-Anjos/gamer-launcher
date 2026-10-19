use crate::frb_generated::StreamSink;
use flutter_rust_bridge::frb;
use launcher_core::gamepad::{spawn_listener, ListenerHandle};
pub use launcher_core::input::GamepadAction;
use std::ops::ControlFlow;
use std::sync::{Mutex, MutexGuard, PoisonError};

#[frb(mirror(GamepadAction))]
pub enum _GamepadAction {
    Up,
    Down,
    Left,
    Right,
    Confirm,
    Back,
    Search,
    QuickControls,
    TabPrevious,
    TabNext,
    Close,
}

/// A leitura fica viva enquanto o handle estiver aqui.
static LISTENER: Mutex<Option<ListenerHandle>> = Mutex::new(None);

fn lock_listener() -> MutexGuard<'static, Option<ListenerHandle>> {
    // um pânico em outra thread não deve travar a leitura para sempre
    LISTENER.lock().unwrap_or_else(PoisonError::into_inner)
}

/// Para a leitura atual, se houver. O `join` da thread acontece depois que
/// o mutex é solto.
fn stop_listener() {
    let previous = lock_listener().take();
    drop(previous);
}

/// Ações do controle como stream. Uma nova chamada para a anterior antes de
/// começar, para nunca haver dois leitores ativos. Falha se o sistema não
/// permitir ler controles.
pub fn gamepad_actions(sink: StreamSink<GamepadAction>) -> Result<(), String> {
    stop_listener();
    let handle = spawn_listener(move |action| match sink.add(action) {
        Ok(()) => ControlFlow::Continue(()),
        Err(_) => ControlFlow::Break(()),
    })
    .map_err(|error| error.to_string())?;
    *lock_listener() = Some(handle);
    Ok(())
}

/// Para de ler controles (chamado quando a UI deixa de ouvir o stream).
pub fn gamepad_stop() {
    stop_listener();
}

/// Há algum controle conectado agora? Sem leitura ativa, não.
#[frb(sync)]
pub fn gamepad_connected() -> bool {
    lock_listener()
        .as_ref()
        .is_some_and(|handle| handle.connected_gamepads() > 0)
}
