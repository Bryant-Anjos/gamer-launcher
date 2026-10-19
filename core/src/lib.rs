//! Núcleo do gamer-launcher: lógica de sistema sem UI.

pub mod apps;
pub mod catalog;
mod fs_util;
pub mod gamepad;
pub mod input;
pub mod open;
pub mod paths;
pub mod recents;
pub mod search;
pub mod settings;
pub mod stats;
pub mod system;
pub mod theme;
pub mod time_of_day;

/// Versão do núcleo, usada para confirmar que a ponte Flutter↔Rust está viva.
pub fn version() -> String {
    env!("CARGO_PKG_VERSION").to_string()
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn version_matches_cargo_manifest() {
        assert_eq!(version(), "0.1.0");
    }
}
