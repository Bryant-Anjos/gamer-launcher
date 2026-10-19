use crate::convert::{resolved_theme, settings_from_dto, settings_to_dto};
use flutter_rust_bridge::frb;
use launcher_core::paths::default_settings_path;
use launcher_core::settings::Settings;
use launcher_core::time_of_day::TimeOfDay;

/// Escolha de tema do usuário. Nome próprio para não colidir com o
/// `ThemeMode` do Flutter.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum LauncherThemeMode {
    Light,
    Dark,
    Auto,
}

/// Tema efetivo depois de aplicar o horário.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum ResolvedTheme {
    Light,
    Dark,
}

/// Disposição dos botões do controle. `Auto` detecta o fabricante.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum LauncherButtonLayout {
    Auto,
    Xbox,
    Nintendo,
}

/// Quais painéis aparecem na tela inicial.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct PanelVisibility {
    pub search: bool,
    pub quick_controls: bool,
    pub system: bool,
    pub recents: bool,
    pub favorites: bool,
    pub featured_cards: bool,
}

/// Configurações como a UI as vê. Horários em minutos desde a meia-noite.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct LauncherSettings {
    pub theme_mode: LauncherThemeMode,
    pub dark_starts_minute: u16,
    pub light_starts_minute: u16,
    pub wallpaper: Option<String>,
    pub favorites: Vec<String>,
    pub panels: PanelVisibility,
    pub button_layout: LauncherButtonLayout,
    pub sounds: bool,
    pub reduce_animations: bool,
}

fn settings_path() -> Result<std::path::PathBuf, String> {
    default_settings_path().ok_or_else(|| "sem pasta de configuração (HOME ausente)".to_string())
}

#[frb(sync)]
pub fn default_settings() -> LauncherSettings {
    settings_to_dto(&Settings::default())
}

/// Arquivo ausente dá o padrão; arquivo inválido é erro (a UI usa o padrão
/// e avisa, sem sobrescrever o arquivo até o usuário mudar algo).
pub fn load_settings() -> Result<LauncherSettings, String> {
    let settings = Settings::load(&settings_path()?).map_err(|error| error.to_string())?;
    Ok(settings_to_dto(&settings))
}

/// Valida e grava de forma atômica.
pub fn save_settings(settings: LauncherSettings) -> Result<(), String> {
    let settings = settings_from_dto(&settings)?;
    settings
        .save(&settings_path()?)
        .map_err(|error| error.to_string())
}

/// Tema efetivo no minuto do dia dado (o relógio fica na UI).
#[frb(sync)]
pub fn resolve_theme(
    settings: LauncherSettings,
    minute_of_day: u16,
) -> Result<ResolvedTheme, String> {
    let settings = settings_from_dto(&settings)?;
    let now = TimeOfDay::from_minutes(minute_of_day).map_err(|error| error.to_string())?;
    Ok(resolved_theme(launcher_core::theme::resolve_theme(
        &settings, now,
    )))
}
