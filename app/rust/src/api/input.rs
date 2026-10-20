use crate::api::settings::LauncherButtonLayout;
use crate::convert::{button_layout_from_dto, detected_layout_to_dto};
use crate::frb_generated::StreamSink;
use flutter_rust_bridge::frb;
use launcher_core::gamepad::{spawn_listener_with, ListenerHandle};
use launcher_core::input::ButtonLayout;
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
pub fn gamepad_actions(
    sink: StreamSink<GamepadAction>,
    layout: LauncherButtonLayout,
) -> Result<(), String> {
    stop_listener();
    let handle = spawn_listener_with(button_layout_from_dto(layout), move |action| {
        match sink.add(action) {
            Ok(()) => ControlFlow::Continue(()),
            Err(_) => ControlFlow::Break(()),
        }
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

/// Troca a disposição dos botões com a leitura rodando.
#[frb(sync)]
pub fn gamepad_set_layout(layout: LauncherButtonLayout) {
    if let Some(handle) = lock_listener().as_ref() {
        handle.set_layout_setting(button_layout_from_dto(layout));
    }
}

/// Layout que o modo automático escolhe para o último controle usado (Xbox
/// ou Nintendo), para a tela mostrar os nomes certos dos botões. Sem leitura
/// ativa, Xbox.
#[frb(sync)]
pub fn gamepad_detected_layout() -> LauncherButtonLayout {
    let detected = lock_listener()
        .as_ref()
        .map_or(ButtonLayout::Xbox, ListenerHandle::detected_layout);
    detected_layout_to_dto(detected)
}
