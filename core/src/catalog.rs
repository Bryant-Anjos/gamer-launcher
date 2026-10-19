//! Catálogo da pesquisa global: junta apps, arquivos recentes e páginas de
//! configurações num só formato. O `id` de cada item diz o que ele abre
//! (`app:`, `file:` ou `setting:`); veja [`crate::open`].

use crate::apps::AppEntry;
use crate::recents::RecentItem;
use crate::search::{ItemKind, SearchItem};

pub(crate) const APP_PREFIX: &str = "app:";
pub(crate) const FILE_PREFIX: &str = "file:";
pub(crate) const SETTING_PREFIX: &str = "setting:";

/// Página das configurações do COSMIC: `page` é o subcomando de
/// `cosmic-settings`, `title` o nome mostrado ao usuário.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct SettingsPage {
    pub page: &'static str,
    pub title: &'static str,
}

const fn page(page: &'static str, title: &'static str) -> SettingsPage {
    SettingsPage { page, title }
}

pub const SETTINGS_PAGES: &[SettingsPage] = &[
    page("wireless", "Wi-Fi"),
    page("network", "Rede"),
    page("wired", "Rede cabeada"),
    page("vpn", "VPN"),
    page("bluetooth", "Bluetooth"),
    page("sound", "Som"),
    page("displays", "Telas"),
    page("power", "Energia"),
    page("appearance", "Aparência"),
    page("wallpaper", "Papel de parede"),
    page("desktop", "Área de trabalho"),
    page("dock", "Dock"),
    page("panel", "Painel"),
    page("workspaces", "Espaços de trabalho"),
    page("window-management", "Gerenciamento de janelas"),
    page("keyboard", "Teclado"),
    page("mouse", "Mouse"),
    page("touchpad", "Touchpad"),
    page("date-time", "Data e hora"),
    page("region-language", "Idioma e região"),
    page("default-apps", "Aplicativos padrão"),
    page("startup-apps", "Aplicativos de inicialização"),
    page("users", "Usuários"),
    page("accessibility", "Acessibilidade"),
    page("about", "Sobre"),
];

pub(crate) fn is_known_settings_page(name: &str) -> bool {
    SETTINGS_PAGES.iter().any(|page| page.page == name)
}

fn app_item(app: &AppEntry) -> SearchItem {
    SearchItem {
        kind: ItemKind::App,
        id: format!("{APP_PREFIX}{}", app.id),
        title: app.name.clone(),
        subtitle: None,
    }
}

/// Arquivo sem nome (a raiz, por exemplo) não vira item.
fn file_item(recent: &RecentItem) -> Option<SearchItem> {
    let title = recent.path.file_name()?.to_string_lossy().into_owned();
    Some(SearchItem {
        kind: ItemKind::File,
        id: format!("{FILE_PREFIX}{}", recent.path.display()),
        title,
        subtitle: recent
            .path
            .parent()
            .map(|folder| folder.display().to_string()),
    })
}

fn setting_item(page: &SettingsPage) -> SearchItem {
    SearchItem {
        kind: ItemKind::Setting,
        id: format!("{SETTING_PREFIX}{}", page.page),
        title: page.title.to_string(),
        subtitle: None,
    }
}

/// Apps, depois arquivos, depois configurações, cada grupo na ordem recebida.
pub fn build_catalog(apps: &[AppEntry], recents: &[RecentItem]) -> Vec<SearchItem> {
    apps.iter()
        .map(app_item)
        .chain(recents.iter().filter_map(file_item))
        .chain(SETTINGS_PAGES.iter().map(setting_item))
        .collect()
}
