//! Localiza o arquivo de ícone de um app (spec de temas de ícones do
//! freedesktop, simplificada): só formatos que o Flutter desenha.

use crate::paths;
use std::collections::HashSet;
use std::path::{Component, Path, PathBuf};

const USER_FLATPAK_EXPORTS: &str = ".local/share/flatpak/exports/share";
const EXTRA_DATA_DIRS: [&str; 2] = ["/var/lib/flatpak/exports/share", "/var/lib/snapd/desktop"];
/// `hicolor` é o tema base obrigatório; os demais cobrem apps do sistema
/// que só trazem ícone no tema da distribuição.
const THEMES: [&str; 5] = ["hicolor", "Cosmic", "Pop", "Adwaita", "breeze"];
/// Do melhor para o pior: vetorial primeiro, depois do maior para o menor.
const SIZES: [&str; 10] = [
    "scalable", "512x512", "256x256", "192x192", "128x128", "96x96", "64x64", "48x48", "32x32",
    "24x24",
];
const EXTENSIONS: [&str; 2] = ["svg", "png"];
const DRAWABLE: [&str; 4] = ["svg", "png", "jpg", "jpeg"];

fn has_extension(path: &Path, allowed: &[&str]) -> bool {
    path.extension()
        .and_then(|ext| ext.to_str())
        .is_some_and(|ext| allowed.iter().any(|ok| ok.eq_ignore_ascii_case(ext)))
}

/// Nome simples, sem barra nem `..`, para não sair das pastas de ícones.
fn is_plain_name(name: &str) -> bool {
    let mut components = Path::new(name).components();
    matches!(components.next(), Some(Component::Normal(_))) && components.next().is_none()
}

/// Tira uma extensão de imagem do nome (alguns `.desktop` escrevem `app.png`).
fn bare_name(name: &str) -> &str {
    let path = Path::new(name);
    if has_extension(path, &["svg", "png", "xpm"]) {
        path.file_stem()
            .and_then(|stem| stem.to_str())
            .unwrap_or(name)
    } else {
        name
    }
}

fn find_in_root(root: &Path, name: &str) -> Option<PathBuf> {
    THEMES
        .iter()
        .map(|theme| root.join(theme))
        // tema ausente custa uma consulta só, não uma por tamanho
        .filter(|theme_dir| theme_dir.is_dir())
        .find_map(|theme_dir| {
            SIZES.iter().find_map(|size| {
                EXTENSIONS
                    .iter()
                    .map(|ext| {
                        theme_dir
                            .join(size)
                            .join("apps")
                            .join(format!("{name}.{ext}"))
                    })
                    .find(|candidate| candidate.is_file())
            })
        })
}

fn find_in_pixmaps(pixmaps: &[PathBuf], name: &str) -> Option<PathBuf> {
    pixmaps.iter().find_map(|dir| {
        EXTENSIONS
            .iter()
            .map(|ext| dir.join(format!("{name}.{ext}")))
            .find(|candidate| candidate.is_file())
    })
}

/// Arquivo do ícone `icon` (nome do tema ou caminho absoluto), procurando
/// nas raízes de temas na ordem dada e, por último, nas pastas `pixmaps`.
pub fn resolve_icon(icon: &str, roots: &[PathBuf], pixmaps: &[PathBuf]) -> Option<PathBuf> {
    let path = Path::new(icon);
    if path.is_absolute() {
        return (path.is_file() && has_extension(path, &DRAWABLE)).then(|| path.to_path_buf());
    }
    let name = bare_name(icon);
    if !is_plain_name(name) {
        return None;
    }
    roots
        .iter()
        .find_map(|root| find_in_root(root, name))
        .or_else(|| find_in_pixmaps(pixmaps, name))
}

/// Raízes de temas de ícones, do usuário para o sistema, sem repetição.
pub fn icon_roots_from(
    data_home: Option<PathBuf>,
    home: Option<PathBuf>,
    system_data_dirs: &[PathBuf],
) -> Vec<PathBuf> {
    let legacy = home.as_ref().map(|home| home.join(".icons"));
    let user_data = data_home.map(|dir| dir.join("icons"));
    let user_flatpak = home.map(|home| home.join(USER_FLATPAK_EXPORTS).join("icons"));
    let system = system_data_dirs
        .iter()
        .cloned()
        .chain(EXTRA_DATA_DIRS.iter().map(PathBuf::from))
        .map(|dir| dir.join("icons"));
    let mut seen = HashSet::new();
    legacy
        .into_iter()
        .chain(user_data)
        .chain(user_flatpak)
        .chain(system)
        .filter(|dir| seen.insert(dir.clone()))
        .collect()
}

pub fn pixmap_dirs_from(system_data_dirs: &[PathBuf]) -> Vec<PathBuf> {
    system_data_dirs
        .iter()
        .map(|dir| dir.join("pixmaps"))
        .collect()
}

/// Pastas de ícones do ambiente atual: (raízes de temas, pixmaps).
pub fn default_icon_dirs() -> (Vec<PathBuf>, Vec<PathBuf>) {
    let data_dirs = paths::data_dirs();
    (
        icon_roots_from(paths::data_home(), paths::home_dir(), &data_dirs),
        pixmap_dirs_from(&data_dirs),
    )
}
