use launcher_core::apps::AppEntry;
use launcher_core::featured::{game_launchers, music_player};

fn app(id: &str, name: &str, categories: &[&str]) -> AppEntry {
    AppEntry {
        id: id.into(),
        name: name.into(),
        exec: "x".into(),
        icon: None,
        categories: categories.iter().map(|c| c.to_string()).collect(),
        terminal: false,
        working_dir: None,
    }
}

fn ids(apps: &[&AppEntry]) -> Vec<String> {
    apps.iter().map(|app| app.id.clone()).collect()
}

#[test]
fn game_launchers_are_found_in_steam_heroic_lutris_order() {
    let apps = [
        app("net.lutris.Lutris.desktop", "Lutris", &[]),
        app("firefox.desktop", "Firefox", &[]),
        app("com.heroicgameslauncher.hgl.desktop", "Heroic", &[]),
        app("steam.desktop", "Steam", &[]),
    ];

    assert_eq!(
        ids(&game_launchers(&apps)),
        vec![
            "steam.desktop",
            "com.heroicgameslauncher.hgl.desktop",
            "net.lutris.Lutris.desktop"
        ]
    );
}

#[test]
fn flatpak_steam_counts_and_runtimes_do_not() {
    let apps = [
        app("Steam Linux Runtime 3.0 (sniper).desktop", "Runtime", &[]),
        app("com.valvesoftware.Steam.desktop", "Steam", &[]),
    ];

    assert_eq!(
        ids(&game_launchers(&apps)),
        vec!["com.valvesoftware.Steam.desktop"]
    );
}

#[test]
fn the_same_launcher_installed_twice_appears_once() {
    let apps = [
        app("steam.desktop", "Steam", &[]),
        app("com.valvesoftware.Steam.desktop", "Steam (Flatpak)", &[]),
    ];

    assert_eq!(ids(&game_launchers(&apps)), vec!["steam.desktop"]);
}

#[test]
fn no_launchers_installed_gives_an_empty_list() {
    assert!(game_launchers(&[app("a.desktop", "A", &[])]).is_empty());
}

#[test]
fn music_players_are_preferred_over_generic_audio_players() {
    let apps = [
        app(
            "rhythmbox.desktop",
            "Rhythmbox",
            &["AudioVideo", "Audio", "Player"],
        ),
        app("spotify.desktop", "Spotify", &["Audio", "Music", "Player"]),
    ];

    assert_eq!(
        music_player(&apps).map(|app| app.id.as_str()),
        Some("spotify.desktop")
    );
}

#[test]
fn an_audio_player_is_used_when_there_is_no_music_app() {
    let apps = [
        app("vlc.desktop", "VLC", &["AudioVideo", "Player", "Video"]),
        app(
            "rhythmbox.desktop",
            "Rhythmbox",
            &["AudioVideo", "Audio", "Player"],
        ),
    ];

    assert_eq!(
        music_player(&apps).map(|app| app.id.as_str()),
        Some("rhythmbox.desktop")
    );
}

#[test]
fn audio_tools_that_are_not_players_do_not_count() {
    let apps = [app(
        "audacity.desktop",
        "Audacity",
        &["Audio", "AudioVideo"],
    )];

    assert_eq!(music_player(&apps), None);
}
