use crate::fs_util::write_atomic;
use crate::input::ButtonLayoutSetting;
use crate::time_of_day::TimeOfDay;
use serde::{Deserialize, Serialize};
use std::collections::HashSet;
use std::path::{Path, PathBuf};
use std::{fs, io};
use thiserror::Error;

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum ThemeMode {
    Light,
    Dark,
    Auto,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum Panel {
    Search,
    QuickControls,
    System,
    Recents,
    Favorites,
    FeaturedCards,
}

impl Panel {
    pub const ALL: [Panel; 6] = [
        Panel::Search,
        Panel::QuickControls,
        Panel::System,
        Panel::Recents,
        Panel::Favorites,
        Panel::FeaturedCards,
    ];
}

/// Visibilidade de cada painel; tudo visível por padrão.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(default)]
struct Panels {
    search: bool,
    quick_controls: bool,
    system: bool,
    recents: bool,
    favorites: bool,
    featured_cards: bool,
}

impl Default for Panels {
    fn default() -> Self {
        Self {
            search: true,
            quick_controls: true,
            system: true,
            recents: true,
            favorites: true,
            featured_cards: true,
        }
    }
}

impl Panels {
    fn slot(&mut self, panel: Panel) -> &mut bool {
        match panel {
            Panel::Search => &mut self.search,
            Panel::QuickControls => &mut self.quick_controls,
            Panel::System => &mut self.system,
            Panel::Recents => &mut self.recents,
            Panel::Favorites => &mut self.favorites,
            Panel::FeaturedCards => &mut self.featured_cards,
        }
    }

    fn is_visible(&self, panel: Panel) -> bool {
        match panel {
            Panel::Search => self.search,
            Panel::QuickControls => self.quick_controls,
            Panel::System => self.system,
            Panel::Recents => self.recents,
            Panel::Favorites => self.favorites,
            Panel::FeaturedCards => self.featured_cards,
        }
    }
}

#[derive(Debug, Error)]
pub enum SettingsError {
    #[error("falha ao ler ou gravar as configurações: {0}")]
    Io(#[from] io::Error),
    #[error("arquivo de configurações inválido: {0}")]
    Parse(#[from] serde_json::Error),
    #[error("configurações incoerentes: {0}")]
    Invalid(String),
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(default)]
pub struct Settings {
    pub theme_mode: ThemeMode,
    pub dark_starts_at: TimeOfDay,
    pub light_starts_at: TimeOfDay,
    pub wallpaper: Option<PathBuf>,
    pub favorites: Vec<String>,
    pub button_layout: ButtonLayoutSetting,
    panels: Panels,
}

impl Default for Settings {
    fn default() -> Self {
        Self {
            theme_mode: ThemeMode::Auto,
            dark_starts_at: TimeOfDay::from_minutes(19 * 60).expect("19:00 é válido"),
            light_starts_at: TimeOfDay::from_minutes(6 * 60).expect("06:00 é válido"),
            wallpaper: None,
            favorites: Vec::new(),
            button_layout: ButtonLayoutSetting::default(),
            panels: Panels::default(),
        }
    }
}

impl Settings {
    pub fn is_panel_visible(&self, panel: Panel) -> bool {
        self.panels.is_visible(panel)
    }

    pub fn with_theme_mode(&self, theme_mode: ThemeMode) -> Self {
        Self {
            theme_mode,
            ..self.clone()
        }
    }

    pub fn with_wallpaper(&self, wallpaper: Option<PathBuf>) -> Self {
        Self {
            wallpaper,
            ..self.clone()
        }
    }

    pub fn with_button_layout(&self, button_layout: ButtonLayoutSetting) -> Self {
        Self {
            button_layout,
            ..self.clone()
        }
    }

    pub fn with_favorites(&self, favorites: Vec<String>) -> Result<Self, SettingsError> {
        let next = Self {
            favorites,
            ..self.clone()
        };
        next.validate()?;
        Ok(next)
    }

    pub fn with_panel_visible(&self, panel: Panel, visible: bool) -> Self {
        let mut next = self.clone();
        *next.panels.slot(panel) = visible;
        next
    }

    pub fn with_auto_schedule(
        &self,
        dark_starts_at: TimeOfDay,
        light_starts_at: TimeOfDay,
    ) -> Result<Self, SettingsError> {
        let next = Self {
            dark_starts_at,
            light_starts_at,
            ..self.clone()
        };
        next.validate()?;
        Ok(next)
    }

    fn validate(&self) -> Result<(), SettingsError> {
        if self.dark_starts_at == self.light_starts_at {
            return Err(SettingsError::Invalid(
                "os horários do tema escuro e claro não podem ser iguais".into(),
            ));
        }
        if self.favorites.iter().any(String::is_empty) {
            return Err(SettingsError::Invalid("favorito com id vazio".into()));
        }
        let mut seen = HashSet::new();
        if let Some(repeated) = self.favorites.iter().find(|id| !seen.insert(id.as_str())) {
            return Err(SettingsError::Invalid(format!(
                "favorito repetido: {repeated}"
            )));
        }
        Ok(())
    }

    /// Arquivo ausente vale como configurações padrão; arquivo quebrado é erro.
    pub fn load(path: &Path) -> Result<Self, SettingsError> {
        let text = match fs::read_to_string(path) {
            Ok(text) => text,
            Err(error) if error.kind() == io::ErrorKind::NotFound => return Ok(Self::default()),
            Err(error) => return Err(error.into()),
        };
        let settings: Self = serde_json::from_str(&text)?;
        settings.validate()?;
        Ok(settings)
    }

    /// Gravação atômica (ver [`write_atomic`]).
    pub fn save(&self, path: &Path) -> Result<(), SettingsError> {
        self.validate()?;
        let json = serde_json::to_string_pretty(self)?;
        Ok(write_atomic(path, json.as_bytes())?)
    }
}
