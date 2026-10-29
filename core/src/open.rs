//! Abre o que a pesquisa encontrou: apps, arquivos e páginas de configurações.

use crate::apps::{AppEntry, launch, spawn_detached};
use crate::catalog::{APP_PREFIX, FILE_PREFIX, SETTING_PREFIX, is_known_settings_page};
use crate::search::SearchItem;
use std::path::PathBuf;
use thiserror::Error;

#[cfg(not(windows))]
const DEFAULT_FILE_OPENER: &str = "xdg-open";
#[cfg(not(windows))]
const DEFAULT_SETTINGS_APP: &str = "cosmic-settings";
#[cfg(windows)]
const DEFAULT_FILE_OPENER: &str = "explorer.exe";
#[cfg(windows)]
const DEFAULT_SETTINGS_APP: &str = "explorer.exe";

#[derive(Debug, Error)]
pub enum OpenError {
    #[error("item de pesquisa desconhecido: {0:?}")]
    UnknownItem(String),
    #[error("aplicativo não encontrado: {0}")]
    AppNotFound(String),
    #[error("o arquivo não existe mais: {0}")]
    PathMissing(PathBuf),
    #[error("não foi possível abrir: {0}")]
    Launch(String),
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub enum OpenTarget {
    App(String),
    Path(PathBuf),
    Settings(String),
}

impl OpenTarget {
    /// Interpreta o `id` de um item do catálogo. Só aceita o que o catálogo
    /// produz: páginas de configuração conhecidas e caminhos absolutos.
    pub fn from_item(item: &SearchItem) -> Result<Self, OpenError> {
        let unknown = || OpenError::UnknownItem(item.id.clone());
        if let Some(id) = item.id.strip_prefix(APP_PREFIX) {
            return (!id.is_empty())
                .then(|| Self::App(id.into()))
                .ok_or_else(unknown);
        }
        if let Some(path) = item.id.strip_prefix(FILE_PREFIX) {
            let path = PathBuf::from(path);
            return path
                .is_absolute()
                .then_some(Self::Path(path))
                .ok_or_else(unknown);
        }
        if let Some(page) = item.id.strip_prefix(SETTING_PREFIX) {
            return is_known_settings_page(page)
                .then(|| Self::Settings(page.into()))
                .ok_or_else(unknown);
        }
        Err(unknown())
    }
}

/// Quem abre arquivos e configurações; trocável para teste.
#[derive(Debug, Clone)]
pub struct Opener {
    file_opener: String,
    settings_app: String,
}

/// No Windows as configurações abrem pelo esquema `ms-settings:`.
#[cfg(windows)]
fn settings_argument(page: &str) -> String {
    match page {
        "bluetooth" => "ms-settings:bluetooth",
        "network" | "wifi" => "ms-settings:network",
        "sound" | "audio" => "ms-settings:sound",
        "display" => "ms-settings:display",
        "power" => "ms-settings:powersleep",
        _ => "ms-settings:",
    }
    .to_string()
}

#[cfg(not(windows))]
fn settings_argument(page: &str) -> String {
    page.to_string()
}

impl Opener {
    pub fn system() -> Self {
        Self::with_programs(DEFAULT_FILE_OPENER, DEFAULT_SETTINGS_APP)
    }

    pub fn with_programs(file_opener: &str, settings_app: &str) -> Self {
        Self {
            file_opener: file_opener.to_string(),
            settings_app: settings_app.to_string(),
        }
    }

    pub fn open(&self, target: &OpenTarget, apps: &[AppEntry]) -> Result<(), OpenError> {
        match target {
            OpenTarget::App(id) => {
                let app = apps
                    .iter()
                    .find(|app| &app.id == id)
                    .ok_or_else(|| OpenError::AppNotFound(id.clone()))?;
                launch(app).map_err(|error| OpenError::Launch(error.to_string()))
            }
            OpenTarget::Path(path) => {
                if !path.exists() {
                    return Err(OpenError::PathMissing(path.clone()));
                }
                self.spawn(&self.file_opener, path.display().to_string())
            }
            OpenTarget::Settings(page) => self.spawn(&self.settings_app, settings_argument(page)),
        }
    }

    fn spawn(&self, program: &str, argument: String) -> Result<(), OpenError> {
        spawn_detached(program, &[argument], None)
            .map_err(|error| OpenError::Launch(format!("{program}: {error}")))
    }
}
