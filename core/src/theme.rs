use crate::settings::{Settings, ThemeMode};
use crate::time_of_day::TimeOfDay;

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum Theme {
    Light,
    Dark,
}

/// Tema efetivo agora. No modo automático o escuro vale de `dark_starts_at`
/// (inclusive) até `light_starts_at` (exclusive), podendo cruzar a meia-noite.
pub fn resolve_theme(settings: &Settings, now: TimeOfDay) -> Theme {
    match settings.theme_mode {
        ThemeMode::Light => Theme::Light,
        ThemeMode::Dark => Theme::Dark,
        ThemeMode::Auto => {
            let dark_from = settings.dark_starts_at;
            let light_from = settings.light_starts_at;
            let is_dark = if dark_from < light_from {
                now >= dark_from && now < light_from
            } else {
                now >= dark_from || now < light_from
            };
            if is_dark { Theme::Dark } else { Theme::Light }
        }
    }
}
