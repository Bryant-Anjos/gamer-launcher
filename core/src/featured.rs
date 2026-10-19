//! Apps por trás dos cartões de destaque: lançadores de jogos (o cartão
//! "Jogos" só abre um deles, o launcher não tem biblioteca própria) e o
//! player de música.

use crate::apps::AppEntry;

/// Ids (sem `.desktop`, em minúsculas) de cada lançador, na ordem de
/// preferência: pacote nativo primeiro, depois Flatpak.
const GAME_LAUNCHERS: [&[&str]; 3] = [
    &["steam", "com.valvesoftware.steam"],
    &["heroic", "com.heroicgameslauncher.hgl"],
    &["lutris", "net.lutris.lutris"],
];

fn stem(app: &AppEntry) -> String {
    app.id
        .strip_suffix(".desktop")
        .unwrap_or(&app.id)
        .to_lowercase()
}

/// Steam, Heroic e Lutris instalados, nessa ordem, um de cada.
pub fn game_launchers(apps: &[AppEntry]) -> Vec<&AppEntry> {
    GAME_LAUNCHERS
        .iter()
        .filter_map(|known_ids| {
            known_ids
                .iter()
                .find_map(|known| apps.iter().find(|app| stem(app) == *known))
        })
        .collect()
}

fn has_category(app: &AppEntry, category: &str) -> bool {
    app.categories.iter().any(|c| c == category)
}

/// Um player de música: primeiro os da categoria `Music`, depois qualquer
/// player de áudio. A lista já vem em ordem alfabética.
pub fn music_player(apps: &[AppEntry]) -> Option<&AppEntry> {
    let players = || apps.iter().filter(|app| has_category(app, "Player"));
    players()
        .find(|app| has_category(app, "Music"))
        .or_else(|| players().find(|app| has_category(app, "Audio")))
}
