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

const NO_ADAPTER_MESSAGE: &str = "No default controller available";
const ADDRESS_GROUPS: usize = 6;

fn is_bluetooth_address(text: &str) -> bool {
    let groups: Vec<&str> = text.split(':').collect();
    groups.len() == ADDRESS_GROUPS
        && groups
            .iter()
            .all(|group| group.len() == 2 && group.bytes().all(|b| b.is_ascii_hexdigit()))
}

/// Endereço no formato `AA:BB:CC:DD:EE:FF`, em maiúsculas. Qualquer outra
/// coisa é recusada: o valor vira argumento do `bluetoothctl`.
pub fn bluetooth_address(text: &str) -> Result<String, SystemError> {
    if is_bluetooth_address(text) {
        Ok(text.to_ascii_uppercase())
    } else {
        Err(unexpected("endereço bluetooth", text))
    }
}

/// Linhas "Device ENDEREÇO Nome" de `bluetoothctl devices ...`; o resto é ignorado.
pub fn bluetooth_device_lines(output: &str) -> Result<Vec<(String, String)>, SystemError> {
    if output.contains(NO_ADAPTER_MESSAGE) {
        return Err(SystemError::Unavailable("sem adaptador bluetooth".into()));
    }
    Ok(output
        .lines()
        .filter_map(|line| line.trim().strip_prefix("Device "))
        .filter_map(|rest| rest.split_once(' '))
        .filter(|(address, _)| is_bluetooth_address(address))
        .map(|(address, name)| (address.to_ascii_uppercase(), name.trim().to_string()))
        .collect())
}

/// O `bluetoothctl` às vezes escreve a falha na saída e sai com sucesso.
pub fn bluetooth_failure(output: &str) -> Option<String> {
    output
        .lines()
        .map(str::trim)
        .find(|line| line.starts_with("Failed to"))
        .map(str::to_string)
}

/// Identificador de sessão do logind (letras e números); recusa o que
/// poderia virar opção do `loginctl`.
pub fn session_id(id: Option<&str>) -> Result<String, SystemError> {
    let id = id.ok_or_else(|| SystemError::Unavailable("sem sessão do logind".into()))?;
    if id.is_empty() || !id.chars().all(|c| c.is_ascii_alphanumeric()) {
        return Err(SystemError::Parse(format!("sessão inválida: {id:?}")));
    }
    Ok(id.to_string())
}
