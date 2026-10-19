//! Imagens que o usuário pode escolher como wallpaper.

use crate::paths;
use std::fs;
use std::path::{Path, PathBuf};

const IMAGE_EXTENSIONS: [&str; 4] = ["png", "jpg", "jpeg", "webp"];
const SYSTEM_BACKGROUNDS: &str = "/usr/share/backgrounds";
const USER_DIRS_FILE: &str = "user-dirs.dirs";
const PICTURES_KEY: &str = "XDG_PICTURES_DIR=";
const FALLBACK_PICTURES: &str = "Pictures";
/// A pasta do sistema guarda os wallpapers um nível abaixo (ex.: `cosmic/`).
pub const DEFAULT_DEPTH: usize = 2;

fn is_hidden(path: &Path) -> bool {
    path.file_name()
        .and_then(|name| name.to_str())
        .is_some_and(|name| name.starts_with('.'))
}

fn is_image(path: &Path) -> bool {
    path.extension()
        .and_then(|ext| ext.to_str())
        .is_some_and(|ext| {
            IMAGE_EXTENSIONS
                .iter()
                .any(|ok| ok.eq_ignore_ascii_case(ext))
        })
}

fn sorted_entries(dir: &Path) -> Vec<PathBuf> {
    let Ok(read_dir) = fs::read_dir(dir) else {
        return Vec::new();
    };
    let mut entries: Vec<PathBuf> = read_dir
        .filter_map(Result::ok)
        .map(|entry| entry.path())
        .filter(|path| !is_hidden(path))
        .collect();
    entries.sort();
    entries
}

fn collect(dir: &Path, depth: usize, limit: usize, found: &mut Vec<PathBuf>) {
    if depth == 0 {
        return;
    }
    let entries = sorted_entries(dir);
    let (folders, files): (Vec<_>, Vec<_>) = entries.into_iter().partition(|path| path.is_dir());
    for file in files.into_iter().filter(|path| is_image(path)) {
        if found.len() >= limit {
            return;
        }
        found.push(file);
    }
    for folder in folders {
        if found.len() >= limit {
            return;
        }
        collect(&folder, depth - 1, limit, found);
    }
}

/// Imagens das pastas, em ordem de nome, descendo até `max_depth` níveis
/// (1 = só a própria pasta). Pastas e arquivos ocultos ficam de fora.
pub fn find_images(dirs: &[PathBuf], max_depth: usize, limit: usize) -> Vec<PathBuf> {
    let mut found = Vec::new();
    for dir in dirs {
        collect(dir, max_depth, limit, &mut found);
    }
    found
}

/// Pasta de imagens do usuário a partir do `user-dirs.dirs`; sem ele (ou
/// com valor relativo), `~/Pictures`.
pub fn pictures_dir_from(user_dirs: Option<&str>, home: Option<&Path>) -> Option<PathBuf> {
    let home = home?;
    let configured = user_dirs
        .and_then(|text| {
            text.lines()
                .map(str::trim)
                .find_map(|line| line.strip_prefix(PICTURES_KEY))
        })
        .map(|value| value.trim_matches('"'))
        .and_then(|value| match value.strip_prefix("$HOME") {
            Some(rest) => Some(home.join(rest.trim_start_matches('/'))),
            None => Some(PathBuf::from(value)).filter(|path| path.is_absolute()),
        });
    configured.or_else(|| Some(home.join(FALLBACK_PICTURES)))
}

/// Pasta de imagens do usuário e a de wallpapers do sistema.
pub fn default_wallpaper_dirs() -> Vec<PathBuf> {
    let user_dirs =
        paths::config_home().and_then(|dir| fs::read_to_string(dir.join(USER_DIRS_FILE)).ok());
    let pictures = pictures_dir_from(user_dirs.as_deref(), paths::home_dir().as_deref());
    pictures
        .into_iter()
        .chain(std::iter::once(PathBuf::from(SYSTEM_BACKGROUNDS)))
        .collect()
}
