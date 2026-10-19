use super::*;
use crate::api::settings::{LauncherSettings, LauncherThemeMode, PanelVisibility, ResolvedTheme};
use launcher_core::apps::AppEntry;
use launcher_core::recents::RecentItem;
use launcher_core::settings::{Panel, Settings};
use launcher_core::stats::SystemStats;
use launcher_core::system::{QuickControlsSnapshot, SystemError, Volume, WifiState};
use launcher_core::theme::Theme;
use std::io;
use std::path::{Path, PathBuf};

fn all_panels(visible: bool) -> PanelVisibility {
    PanelVisibility {
        search: visible,
        quick_controls: visible,
        system: visible,
        recents: visible,
        favorites: visible,
        featured_cards: visible,
    }
}

fn dto() -> LauncherSettings {
    LauncherSettings {
        theme_mode: LauncherThemeMode::Dark,
        dark_starts_minute: 20 * 60,
        light_starts_minute: 7 * 60 + 30,
        wallpaper: Some("/walls/a.png".into()),
        favorites: vec!["code.desktop".into(), "firefox.desktop".into()],
        panels: PanelVisibility {
            system: false,
            ..all_panels(true)
        },
    }
}

#[test]
fn default_settings_become_a_dto_with_every_panel_visible() {
    let converted = settings_to_dto(&Settings::default());

    assert_eq!(converted.theme_mode, LauncherThemeMode::Auto);
    assert_eq!(converted.dark_starts_minute, 19 * 60);
    assert_eq!(converted.light_starts_minute, 6 * 60);
    assert_eq!(converted.wallpaper, None);
    assert_eq!(converted.panels, all_panels(true));
}

#[test]
fn a_dto_round_trips_through_core_settings() {
    let settings = settings_from_dto(&dto()).unwrap();

    assert!(!settings.is_panel_visible(Panel::System));
    assert!(settings.is_panel_visible(Panel::Recents));
    assert_eq!(settings.wallpaper, Some(PathBuf::from("/walls/a.png")));
    assert_eq!(settings_to_dto(&settings), dto());
}

#[test]
fn every_panel_flag_maps_to_its_own_panel() {
    let hidden = settings_from_dto(&LauncherSettings {
        panels: all_panels(false),
        ..dto()
    })
    .unwrap();

    for panel in Panel::ALL {
        assert!(!hidden.is_panel_visible(panel), "{panel:?}");
    }
}

#[test]
fn invalid_dtos_are_refused_with_a_message() {
    let same_times = LauncherSettings {
        light_starts_minute: 20 * 60,
        ..dto()
    };
    let out_of_range = LauncherSettings {
        dark_starts_minute: 24 * 60,
        ..dto()
    };
    let repeated = LauncherSettings {
        favorites: vec!["a".into(), "a".into()],
        ..dto()
    };

    for invalid in [same_times, out_of_range, repeated] {
        let error = settings_from_dto(&invalid).unwrap_err();
        assert!(!error.is_empty());
    }
}

fn entry(id: &str, name: &str, icon: Option<&str>, categories: &[&str]) -> AppEntry {
    AppEntry {
        id: id.into(),
        name: name.into(),
        exec: "x".into(),
        icon: icon.map(str::to_string),
        categories: categories.iter().map(|c| c.to_string()).collect(),
        terminal: false,
        working_dir: None,
    }
}

#[test]
fn the_catalog_resolves_icons_and_featured_apps() {
    let pixmaps = tempfile::tempdir().unwrap();
    let icon = pixmaps.path().join("steam.png");
    std::fs::write(&icon, b"x").unwrap();
    let apps = [
        entry(
            "spotify.desktop",
            "Spotify",
            None,
            &["Audio", "Music", "Player"],
        ),
        entry("steam.desktop", "Steam", Some("steam"), &["Game"]),
    ];
    let history = Ok(LaunchHistory::default().with_launch("steam.desktop"));

    let catalog = build_catalog(&apps, &[], &[pixmaps.path().to_path_buf()], history);

    assert_eq!(catalog.apps.len(), 2);
    assert_eq!(catalog.apps[0].icon_path, None);
    assert_eq!(
        catalog.apps[1].icon_path.as_deref(),
        Some(icon.to_str().unwrap())
    );
    assert_eq!(catalog.apps[1].categories, vec!["Game"]);
    assert_eq!(catalog.game_launcher_ids, vec!["steam.desktop"]);
    assert_eq!(catalog.music_player_id.as_deref(), Some("spotify.desktop"));
    assert_eq!(catalog.last_app_id.as_deref(), Some("steam.desktop"));
    assert!(catalog.warnings.is_empty());
}

#[test]
fn an_uninstalled_last_app_is_not_offered() {
    let apps = [entry("a.desktop", "A", None, &[])];
    let history = Ok(LaunchHistory::default().with_launch("gone.desktop"));

    let catalog = build_catalog(&apps, &[], &[], history);

    assert_eq!(catalog.last_app_id, None);
}

#[test]
fn an_unreadable_history_becomes_a_warning() {
    let catalog = build_catalog(&[], &[], &[], Err("histórico inválido".into()));

    assert_eq!(catalog.last_app_id, None);
    assert_eq!(catalog.warnings, vec!["histórico inválido"]);
}

#[test]
fn recent_files_show_the_folder_relative_to_home() {
    let item = RecentItem {
        path: PathBuf::from("/home/b/Projetos/granspace"),
        modified: "2026-10-19T10:00:00Z".into(),
    };

    let file = recent_file(&item, Some(Path::new("/home/b")));

    assert_eq!(file.name, "granspace");
    assert_eq!(file.location, "~/Projetos");
    assert_eq!(file.path, "/home/b/Projetos/granspace");
    assert_eq!(file.modified, "2026-10-19T10:00:00Z");
}

#[test]
fn recent_files_outside_home_keep_the_full_folder() {
    let item = RecentItem {
        path: PathBuf::from("/srv/data/report.pdf"),
        modified: String::new(),
    };

    let file = recent_file(&item, Some(Path::new("/home/b")));

    assert_eq!(file.location, "/srv/data");
    assert!(!file.is_dir);
}

#[test]
fn a_file_directly_in_home_shows_the_tilde() {
    let item = RecentItem {
        path: PathBuf::from("/home/b/notes.txt"),
        modified: String::new(),
    };

    assert_eq!(recent_file(&item, Some(Path::new("/home/b"))).location, "~");
}

#[test]
fn quick_controls_keep_each_failure_separate() {
    let snapshot = QuickControlsSnapshot {
        wifi: Ok(WifiState {
            enabled: true,
            ssid: Some("Casa_5G".into()),
        }),
        bluetooth: Err(SystemError::Unavailable("sem adaptador bluetooth".into())),
        volume: Ok(Volume {
            percent: 80,
            muted: true,
        }),
        brightness: Err(SystemError::Parse("x".into())),
        dark_mode: Ok(false),
    };

    let controls = quick_controls(&snapshot);

    assert_eq!(controls.wifi.enabled, Some(true));
    assert_eq!(controls.wifi_name.as_deref(), Some("Casa_5G"));
    assert_eq!(controls.bluetooth.enabled, None);
    assert_eq!(
        controls.bluetooth.error.as_deref(),
        Some("indisponível: sem adaptador bluetooth")
    );
    assert_eq!(controls.volume.percent, Some(80));
    assert!(controls.volume.muted);
    assert_eq!(controls.volume.error, None);
    assert_eq!(controls.brightness.percent, None);
    assert!(controls.brightness.error.is_some());
    assert_eq!(controls.dark_mode.enabled, Some(false));
}

#[test]
fn a_failed_wifi_reading_has_no_network_name() {
    let snapshot = QuickControlsSnapshot {
        wifi: Err(SystemError::Unavailable("nmcli".into())),
        bluetooth: Ok(true),
        volume: Err(SystemError::Unavailable("wpctl".into())),
        brightness: Ok(60),
        dark_mode: Err(SystemError::Unavailable("cosmic".into())),
    };

    let controls = quick_controls(&snapshot);

    assert_eq!(controls.wifi.enabled, None);
    assert_eq!(controls.wifi_name, None);
    assert!(!controls.volume.muted);
    assert_eq!(controls.brightness.percent, Some(60));
}

#[test]
fn stats_are_copied_as_bytes() {
    let stats = SystemStats {
        cpu_percent: 12.5,
        ram_used: 4_200,
        ram_total: 16_000,
        disk_used: 120,
        disk_total: 500,
    };

    let sample = stats_sample(&stats);

    assert_eq!(sample.cpu_percent, 12.5);
    assert_eq!(sample.ram_used_bytes, 4_200.0);
    assert_eq!(sample.ram_total_bytes, 16_000.0);
    assert_eq!(sample.disk_used_bytes, 120.0);
    assert_eq!(sample.disk_total_bytes, 500.0);
}

#[test]
fn io_errors_get_friendly_messages() {
    let missing = io::Error::new(io::ErrorKind::NotFound, "No such file");
    let denied = io::Error::new(io::ErrorKind::PermissionDenied, "denied");
    let terminal = io::Error::new(io::ErrorKind::Unsupported, "apps de terminal");
    let other = io::Error::other("boom");

    assert_eq!(
        friendly_io_error(&missing),
        "programa ou arquivo não encontrado"
    );
    assert_eq!(friendly_io_error(&denied), "sem permissão para abrir");
    assert_eq!(friendly_io_error(&terminal), "apps de terminal");
    assert_eq!(friendly_io_error(&other), "boom");
}

#[test]
fn every_theme_mode_round_trips() {
    for mode in [
        LauncherThemeMode::Light,
        LauncherThemeMode::Dark,
        LauncherThemeMode::Auto,
    ] {
        let settings = settings_from_dto(&LauncherSettings {
            theme_mode: mode,
            ..dto()
        })
        .unwrap();
        assert_eq!(settings_to_dto(&settings).theme_mode, mode);
    }
}

#[test]
fn core_themes_map_to_resolved_themes() {
    assert_eq!(resolved_theme(Theme::Light), ResolvedTheme::Light);
    assert_eq!(resolved_theme(Theme::Dark), ResolvedTheme::Dark);
}
