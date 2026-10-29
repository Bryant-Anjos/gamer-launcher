//! Nome do usuário para a saudação da tela inicial.

use std::env;

#[cfg(not(windows))]
const PASSWD_PATH: &str = "/etc/passwd";
const GECOS_FIELD: usize = 4;

/// Primeira palavra do nome real (campo GECOS) de `user` num texto no
/// formato do `/etc/passwd`.
pub fn first_name_from_passwd(passwd: &str, user: &str) -> Option<String> {
    if user.is_empty() {
        return None;
    }
    passwd
        .lines()
        .map(|line| line.split(':').collect::<Vec<_>>())
        .find(|fields| fields.len() > GECOS_FIELD && fields[0] == user)
        .and_then(|fields| {
            let real_name = fields[GECOS_FIELD].split(',').next().unwrap_or_default();
            real_name.split_whitespace().next().map(str::to_string)
        })
}

/// Primeiro nome do usuário da sessão. Contas fora do `/etc/passwd`
/// (LDAP, por exemplo) ficam sem nome.
#[cfg(not(windows))]
pub fn current_first_name() -> Option<String> {
    let user = env::var("USER").or_else(|_| env::var("LOGNAME")).ok()?;
    let passwd = std::fs::read_to_string(PASSWD_PATH).ok()?;
    first_name_from_passwd(&passwd, &user)
}

/// Nome de exibição da conta do Windows (o nome completo, para contas
/// Microsoft); sem ele vale o nome de usuário. Sai só a primeira palavra.
#[cfg(windows)]
pub fn current_first_name() -> Option<String> {
    let name = display_name()
        .filter(|name| !name.trim().is_empty())
        .or_else(|| env::var("USERNAME").ok())?;
    name.split_whitespace().next().map(str::to_string)
}

#[cfg(windows)]
fn display_name() -> Option<String> {
    use windows_sys::Win32::Security::Authentication::Identity::{GetUserNameExW, NameDisplay};
    let mut size: u32 = 256;
    let mut buffer = vec![0u16; size as usize];
    // SAFETY: `buffer` tem `size` posições e a API grava no máximo isso.
    let ok = unsafe { GetUserNameExW(NameDisplay, buffer.as_mut_ptr(), &mut size) };
    ok.then(|| String::from_utf16_lossy(&buffer[..size as usize]))
}
