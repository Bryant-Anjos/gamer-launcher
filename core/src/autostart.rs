//! Iniciar com o sistema, pelo mecanismo padrão do freedesktop: um arquivo
//! `.desktop` em `~/.config/autostart`. A existência do arquivo é a verdade;
//! nada disso fica nas configurações do launcher.

use crate::fs_util::write_atomic;
use crate::paths;
use std::ffi::OsString;
use std::path::{Path, PathBuf};
use std::{env, fs, io};

const AUTOSTART_FILE: &str = "autostart/gamer-launcher.desktop";
const APPIMAGE_ENV: &str = "APPIMAGE";
/// Caracteres que obrigam o `Exec` a ir entre aspas (especificação do freedesktop).
const EXEC_RESERVED: &str = " \t\n\"'\\<>~|&;$*?#()`";

pub fn autostart_file_with(lookup: &impl Fn(&str) -> Option<OsString>) -> Option<PathBuf> {
    paths::config_home_with(lookup).map(|dir| dir.join(AUTOSTART_FILE))
}

pub fn autostart_file() -> Option<PathBuf> {
    autostart_file_with(&|name| env::var_os(name))
}

/// Escapa um caminho para o campo `Exec`. Dentro de aspas, `"`, `` ` ``, `$` e
/// `\` levam barra, e como o valor ainda passa pelo escape de string do
/// `.desktop`, a barra invertida precisa de quatro. `%` vira `%%` sempre.
fn escape_exec_path(path: &str) -> String {
    let needs_quotes = path.chars().any(|c| EXEC_RESERVED.contains(c));
    let mut escaped = String::with_capacity(path.len() + 2);
    for c in path.chars() {
        match c {
            '%' => escaped.push_str("%%"),
            '\\' if needs_quotes => escaped.push_str("\\\\\\\\"),
            '"' | '`' | '$' if needs_quotes => {
                escaped.push('\\');
                escaped.push(c);
            }
            other => escaped.push(other),
        }
    }
    if needs_quotes {
        format!("\"{escaped}\"")
    } else {
        escaped
    }
}

/// Comando a gravar no `Exec`. Num AppImage o executável em execução está num
/// ponto de montagem temporário; vale o caminho do próprio AppImage.
pub fn exec_line(exe: &Path, appimage: Option<&Path>) -> String {
    escape_exec_path(&appimage.unwrap_or(exe).to_string_lossy())
}

/// O comando que reabre o launcher que está rodando agora.
pub fn current_exec_line() -> io::Result<String> {
    let appimage = env::var_os(APPIMAGE_ENV).map(PathBuf::from);
    Ok(exec_line(&env::current_exe()?, appimage.as_deref()))
}

pub fn desktop_entry(exec: &str) -> String {
    format!(
        "[Desktop Entry]\n\
         Type=Application\n\
         Name=Gamer Launcher\n\
         Comment=Launcher em tela cheia, estilo console, controlado por gamepad\n\
         Exec={exec}\n\
         Icon=gamer-launcher\n\
         Terminal=false\n\
         X-GNOME-Autostart-enabled=true\n"
    )
}

/// Ligado quando o arquivo existe e ninguém o desligou por fora
/// (`Hidden=true` ou `X-GNOME-Autostart-enabled=false`).
pub fn is_enabled(file: &Path) -> bool {
    let Ok(text) = fs::read_to_string(file) else {
        return false;
    };
    !text
        .lines()
        .map(str::trim)
        .any(|line| line == "Hidden=true" || line == "X-GNOME-Autostart-enabled=false")
}

/// Liga (grava o arquivo, substituindo o que houver) ou desliga (apaga; não
/// reclama se já não existe).
pub fn set_enabled(file: &Path, enabled: bool, exec: &str) -> io::Result<()> {
    if enabled {
        return write_atomic(file, desktop_entry(exec).as_bytes());
    }
    match fs::remove_file(file) {
        Err(error) if error.kind() != io::ErrorKind::NotFound => Err(error),
        _ => Ok(()),
    }
}

/// Iniciar com o Windows: um valor em `HKCU\...\Run`, que não exige
/// administrador. A chave é a verdade, como o arquivo no Linux.
#[cfg(windows)]
pub mod windows {
    use std::io;
    use std::process::{Command, Stdio};

    const RUN_KEY: &str = r"HKCU\Software\Microsoft\Windows\CurrentVersion\Run";
    const VALUE_NAME: &str = "GamerLauncher";
    const NO_WINDOW: u32 = 0x0800_0000;

    fn reg(args: &[&str]) -> io::Result<bool> {
        let mut command = Command::new("reg");
        command
            .args(args)
            .stdin(Stdio::null())
            .stdout(Stdio::null())
            .stderr(Stdio::null());
        std::os::windows::process::CommandExt::creation_flags(&mut command, NO_WINDOW);
        command.status().map(|status| status.success())
    }

    pub fn is_enabled() -> bool {
        reg(&["query", RUN_KEY, "/v", VALUE_NAME]).unwrap_or(false)
    }

    /// Liga com o caminho do programa que está rodando; desligar sem a
    /// chave presente também é sucesso.
    pub fn set_enabled(enabled: bool) -> io::Result<()> {
        if enabled {
            let exe = std::env::current_exe()?;
            let command_line = format!("\"{}\"", exe.display());
            let done = reg(&[
                "add", RUN_KEY, "/v", VALUE_NAME, "/t", "REG_SZ", "/d", &command_line, "/f",
            ])?;
            return done
                .then_some(())
                .ok_or_else(|| io::Error::other("não foi possível gravar no registro"));
        }
        if is_enabled() {
            reg(&["delete", RUN_KEY, "/v", VALUE_NAME, "/f"])?;
        }
        Ok(())
    }
}