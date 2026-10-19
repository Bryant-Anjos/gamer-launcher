//! Histórico de uso do launcher: hoje só o último app aberto (cartão
//! "Continuar"). Fica separado das configurações porque não é escolha do
//! usuário e é gravado a cada abertura de app.

use crate::fs_util::write_atomic;
use serde::{Deserialize, Serialize};
use std::path::Path;
use std::{fs, io};
use thiserror::Error;

#[derive(Debug, Clone, Default, PartialEq, Eq, Serialize, Deserialize)]
#[serde(default)]
pub struct LaunchHistory {
    pub last_app: Option<String>,
}

#[derive(Debug, Error)]
pub enum HistoryError {
    #[error("falha ao ler ou gravar o histórico: {0}")]
    Io(#[from] io::Error),
    #[error("histórico inválido: {0}")]
    Parse(#[from] serde_json::Error),
}

impl LaunchHistory {
    pub fn with_launch(&self, app_id: &str) -> Self {
        Self {
            last_app: Some(app_id.to_string()),
        }
    }

    /// Arquivo ausente significa histórico vazio.
    pub fn load(path: &Path) -> Result<Self, HistoryError> {
        match fs::read_to_string(path) {
            Ok(text) => Ok(serde_json::from_str(&text)?),
            Err(error) if error.kind() == io::ErrorKind::NotFound => Ok(Self::default()),
            Err(error) => Err(error.into()),
        }
    }

    pub fn save(&self, path: &Path) -> Result<(), HistoryError> {
        let json = serde_json::to_string_pretty(self)?;
        Ok(write_atomic(path, json.as_bytes())?)
    }
}
