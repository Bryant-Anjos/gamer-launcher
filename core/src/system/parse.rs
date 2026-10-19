//! Interpretação das saídas dos programas do sistema (funções puras).

use super::SystemError;

const SSID_ACTIVE: &str = "yes";

fn unexpected(what: &str, text: &str) -> SystemError {
    SystemError::Parse(format!("{what}: {:?}", text.trim()))
}

pub fn wifi_radio(output: &str) -> Result<bool, SystemError> {
    match output.trim() {
        "enabled" => Ok(true),
        "disabled" => Ok(false),
        _ => Err(unexpected("rádio wifi", output)),
    }
}

/// `nmcli -t` separa campos com ':' e escapa ':' e '\' dentro deles.
fn split_terse(line: &str) -> Vec<String> {
    let mut fields = vec![String::new()];
    let mut chars = line.chars();
    while let Some(c) = chars.next() {
        match c {
            '\\' => {
                if let Some(escaped) = chars.next() {
                    fields.last_mut().expect("sempre há um campo").push(escaped);
                }
            }
            ':' => fields.push(String::new()),
            c => fields.last_mut().expect("sempre há um campo").push(c),
        }
    }
    fields
}

pub fn active_ssid(output: &str) -> Option<String> {
    output
        .lines()
        .map(split_terse)
        .find(|fields| fields.first().map(String::as_str) == Some(SSID_ACTIVE))
        .and_then(|fields| fields.into_iter().nth(1))
        .filter(|ssid| !ssid.is_empty())
}

pub fn bluetooth_powered(output: &str) -> Result<bool, SystemError> {
    let value = output
        .lines()
        .find_map(|line| line.trim().strip_prefix("Powered:"))
        .ok_or_else(|| SystemError::Unavailable("sem adaptador bluetooth".into()))?;
    match value.trim() {
        "yes" => Ok(true),
        "no" => Ok(false),
        _ => Err(unexpected("bluetooth", output)),
    }
}

/// Resultado de `wpctl get-volume`: "Volume: 0.45" com " [MUTED]" opcional.
pub fn volume(output: &str) -> Result<(u8, bool), SystemError> {
    let rest = output
        .trim()
        .strip_prefix("Volume:")
        .ok_or_else(|| unexpected("volume", output))?;
    let level: f64 = rest
        .split_whitespace()
        .next()
        .and_then(|number| number.parse().ok())
        .ok_or_else(|| unexpected("volume", output))?;
    let percent = (level * 100.0).round().clamp(0.0, 100.0) as u8;
    Ok((percent, rest.contains("[MUTED]")))
}

pub fn flag(text: &str) -> Result<bool, SystemError> {
    match text.trim() {
        "true" => Ok(true),
        "false" => Ok(false),
        _ => Err(unexpected("valor lógico", text)),
    }
}
