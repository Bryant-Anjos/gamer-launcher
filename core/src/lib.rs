//! Núcleo do gamer-launcher: lógica de sistema sem UI.

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
