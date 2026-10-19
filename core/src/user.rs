//! Nome do usuário para a saudação da tela inicial.

use std::{env, fs};

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
pub fn current_first_name() -> Option<String> {
    let user = env::var("USER").or_else(|_| env::var("LOGNAME")).ok()?;
    let passwd = fs::read_to_string(PASSWD_PATH).ok()?;
    first_name_from_passwd(&passwd, &user)
}
