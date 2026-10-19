//! Diretórios padrão do Linux (XDG). Windows e macOS entram nas fases próprias.
//!
//! Cada função `*_with` recebe a consulta ao ambiente, o que permite testar
//! sem alterar variáveis de ambiente do processo.

use std::env;
use std::ffi::OsString;
use std::path::PathBuf;

const APP_DIR: &str = "gamer-launcher";
const COSMIC_DARK_MODE_FILE: &str = "cosmic/com.system76.CosmicTheme.Mode/v1/is_dark";
const DEFAULT_DATA_DIRS: &str = "/usr/local/share:/usr/share";

fn absolute_env_dir(lookup: &impl Fn(&str) -> Option<OsString>, name: &str) -> Option<PathBuf> {
    lookup(name)
        .map(PathBuf::from)
        .filter(|path| path.is_absolute())
}

pub fn home_dir_with(lookup: &impl Fn(&str) -> Option<OsString>) -> Option<PathBuf> {
    absolute_env_dir(lookup, "HOME")
}

fn under_home(lookup: &impl Fn(&str) -> Option<OsString>, relative: &str) -> Option<PathBuf> {
    home_dir_with(lookup).map(|home| home.join(relative))
}

pub fn data_home_with(lookup: &impl Fn(&str) -> Option<OsString>) -> Option<PathBuf> {
    absolute_env_dir(lookup, "XDG_DATA_HOME").or_else(|| under_home(lookup, ".local/share"))
}

pub fn config_home_with(lookup: &impl Fn(&str) -> Option<OsString>) -> Option<PathBuf> {
    absolute_env_dir(lookup, "XDG_CONFIG_HOME").or_else(|| under_home(lookup, ".config"))
}

/// Diretórios de dados do sistema, do mais prioritário para o menos.
pub fn data_dirs_with(lookup: &impl Fn(&str) -> Option<OsString>) -> Vec<PathBuf> {
    let configured = lookup("XDG_DATA_DIRS")
        .and_then(|value| value.into_string().ok())
        .unwrap_or_default();
    let raw = if configured.is_empty() {
        DEFAULT_DATA_DIRS
    } else {
        configured.as_str()
    };
    raw.split(':')
        .map(PathBuf::from)
        .filter(|path| path.is_absolute())
        .collect()
}

pub fn settings_path_with(lookup: &impl Fn(&str) -> Option<OsString>) -> Option<PathBuf> {
    config_home_with(lookup).map(|dir| dir.join(APP_DIR).join("settings.json"))
}

pub fn recents_path_with(lookup: &impl Fn(&str) -> Option<OsString>) -> Option<PathBuf> {
    data_home_with(lookup).map(|dir| dir.join("recently-used.xbel"))
}

fn process_env(name: &str) -> Option<OsString> {
    env::var_os(name)
}

/// Arquivo em que o COSMIC guarda se o tema do sistema é escuro.
pub fn cosmic_dark_mode_path_with(lookup: &impl Fn(&str) -> Option<OsString>) -> Option<PathBuf> {
    config_home_with(lookup).map(|dir| dir.join(COSMIC_DARK_MODE_FILE))
}

pub fn cosmic_dark_mode_path() -> Option<PathBuf> {
    cosmic_dark_mode_path_with(&process_env)
}

pub fn data_home() -> Option<PathBuf> {
    data_home_with(&process_env)
}

pub fn home_dir() -> Option<PathBuf> {
    home_dir_with(&process_env)
}

pub fn data_dirs() -> Vec<PathBuf> {
    data_dirs_with(&process_env)
}

pub fn default_settings_path() -> Option<PathBuf> {
    settings_path_with(&process_env)
}

pub fn default_recents_path() -> Option<PathBuf> {
    recents_path_with(&process_env)
}
