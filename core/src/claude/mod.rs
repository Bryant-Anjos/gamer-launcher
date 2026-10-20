//! Acompanhamento do Claude Code (sessões, agentes e uso), **só leitura**.
//!
//! O formato interno do Claude muda sem aviso: todo campo é opcional, linha
//! ou arquivo inválido é ignorado e versão desconhecida só mostra menos.
//! Nada aqui escreve em `~/.claude` nem fala com o Claude. Só metadados são
//! lidos (projeto, branch, modelo, contagens, estados, descrições curtas);
//! o conteúdo das mensagens nunca sai daqui.

pub mod agents;
pub mod cache;
mod fields;
pub mod sessions;
pub mod time;
pub mod usage;

use std::ffi::OsStr;
use std::path::{Path, PathBuf};

const PROGRAM: &str = "claude";

/// Pasta de dados padrão (`~/.claude`).
pub fn default_root(home: &Path) -> PathBuf {
    home.join(".claude")
}

/// Instalado se existe a pasta de dados ou o programa `claude` no PATH. Sem
/// isso, a tela não mostra nada do Claude e nada mais é lido.
pub fn is_installed(root: &Path, path_env: Option<&OsStr>) -> bool {
    root.is_dir()
        || path_env.is_some_and(|paths| {
            std::env::split_paths(paths).any(|dir| dir.join(PROGRAM).is_file())
        })
}

/// Corta textos longos (títulos, descrições) no limite, com reticências.
pub(crate) fn shorten(text: &str, limit: usize) -> String {
    let trimmed = text.trim();
    if trimmed.chars().count() <= limit {
        return trimmed.to_string();
    }
    let cut: String = trimmed.chars().take(limit).collect();
    format!("{}…", cut.trim_end())
}
