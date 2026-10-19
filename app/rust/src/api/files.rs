use crate::convert::{friendly_io_error, recent_file};
use launcher_core::apps;
use launcher_core::paths::{default_recents_path, home_dir};
use launcher_core::recents::load_recents;
use launcher_core::wallpapers::{default_wallpaper_dirs, find_images, DEFAULT_DEPTH};
use std::path::Path;

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct RecentFile {
    pub path: String,
    pub name: String,
    /// Pasta onde está, com `~` no lugar da pasta pessoal.
    pub location: String,
    /// Data ISO 8601 em UTC.
    pub modified: String,
    pub is_dir: bool,
}

/// Arquivos e pastas recentes que ainda existem, do mais novo ao mais antigo.
pub fn list_recents(limit: u32) -> Result<Vec<RecentFile>, String> {
    let path =
        default_recents_path().ok_or_else(|| "sem pasta de dados (HOME ausente)".to_string())?;
    let items = load_recents(&path, limit as usize).map_err(|error| error.to_string())?;
    let home = home_dir();
    Ok(items
        .iter()
        .map(|item| recent_file(item, home.as_deref()))
        .collect())
}

/// Abre um arquivo ou pasta com o programa padrão do sistema.
pub fn open_path(path: String) -> Result<(), String> {
    apps::open_path(Path::new(&path)).map_err(|error| friendly_io_error(&error))
}

/// Imagens que podem virar wallpaper (pasta de imagens e as do sistema).
pub fn list_wallpapers(limit: u32) -> Vec<String> {
    find_images(&default_wallpaper_dirs(), DEFAULT_DEPTH, limit as usize)
        .iter()
        .map(|path| path.to_string_lossy().into_owned())
        .collect()
}
