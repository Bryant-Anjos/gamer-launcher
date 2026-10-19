use flutter_rust_bridge::frb;
use launcher_core::sound::{find_program, SoundPlayer, UiSound, PLAYERS};
use std::sync::{Mutex, PoisonError};

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum LauncherSound {
    Navigate,
    Confirm,
    Back,
}

/// Criado na primeira vez que um som toca; nada é gravado com os sons desligados.
static PLAYER: Mutex<Option<SoundPlayer>> = Mutex::new(None);

fn sound_dir() -> std::path::PathBuf {
    std::env::temp_dir().join(format!("gamer-launcher-sons-{}", std::process::id()))
}

fn ui_sound(sound: LauncherSound) -> UiSound {
    match sound {
        LauncherSound::Navigate => UiSound::Navigate,
        LauncherSound::Confirm => UiSound::Confirm,
        LauncherSound::Back => UiSound::Back,
    }
}

/// Toca um som curto sem esperar. Falha se nenhum programa de áudio existir.
#[frb(sync)]
pub fn play_ui_sound(sound: LauncherSound) -> Result<(), String> {
    let mut player = PLAYER.lock().unwrap_or_else(PoisonError::into_inner);
    if player.is_none() {
        let program = find_program(std::env::var_os("PATH").as_deref(), PLAYERS)
            .ok_or_else(|| "nenhum programa de áudio (pw-play, paplay ou aplay)".to_string())?;
        *player = Some(SoundPlayer::prepare(program, &sound_dir()).map_err(|e| e.to_string())?);
    }
    player
        .as_ref()
        .map_or(Ok(()), |player| player.play(ui_sound(sound)))
        .map_err(|error| error.to_string())
}
