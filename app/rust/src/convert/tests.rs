use super::*;
use crate::api::search::SearchKind;
use crate::api::settings::{
    LauncherButtonLayout, LauncherSettings, LauncherThemeMode, PanelVisibility, ResolvedTheme,
};
use launcher_core::apps::AppEntry;
use launcher_core::input::ButtonLayoutSetting;
use launcher_core::recents::RecentItem;
use launcher_core::search::{ItemKind, SearchItem};
use launcher_core::settings::{Panel, Settings};
use launcher_core::stats::SystemStats;
use launcher_core::system::BluetoothDevice;
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
        button_layout: LauncherButtonLayout::Nintendo,
        sounds: true,
        reduce_animations: false,
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
    assert_eq!(converted.button_layout, LauncherButtonLayout::Auto);
    assert!(!converted.sounds);
    assert!(!converted.reduce_animations);
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

#[test]
fn every_button_layout_round_trips() {
    for (dto_layout, core_layout) in [
        (LauncherButtonLayout::Auto, ButtonLayoutSetting::Auto),
        (LauncherButtonLayout::Xbox, ButtonLayoutSetting::Xbox),
        (
            LauncherButtonLayout::Nintendo,
            ButtonLayoutSetting::Nintendo,
        ),
    ] {
        assert_eq!(button_layout_from_dto(dto_layout), core_layout);
        let settings = settings_from_dto(&LauncherSettings {
            button_layout: dto_layout,
            ..dto()
        })
        .unwrap();
        assert_eq!(settings.button_layout, core_layout);
        assert_eq!(settings_to_dto(&settings).button_layout, dto_layout);
    }
}

#[test]
fn sounds_and_reduced_animations_reach_the_core_settings() {
    let settings = settings_from_dto(&LauncherSettings {
        sounds: true,
        reduce_animations: true,
        ..dto()
    })
    .unwrap();

    assert!(settings.sounds);
    assert!(settings.reduce_animations);
}

fn search_item(kind: ItemKind, id: &str, title: &str, subtitle: Option<&str>) -> SearchItem {
    SearchItem {
        kind,
        id: id.into(),
        title: title.into(),
        subtitle: subtitle.map(str::to_string),
    }
}

#[test]
fn search_items_keep_their_kind_and_apps_their_id() {
    let app = search_result(&search_item(
        ItemKind::App,
        "app:code.desktop",
        "VS Code",
        None,
    ));
    let file = search_result(&search_item(
        ItemKind::File,
        "file:/home/b/notas.md",
        "notas.md",
        Some("/home/b"),
    ));
    let setting = search_result(&search_item(
        ItemKind::Setting,
        "setting:sound",
        "Som",
        None,
    ));

    assert_eq!(app.kind, SearchKind::App);
    assert_eq!(app.app_id.as_deref(), Some("code.desktop"));
    assert_eq!(app.id, "app:code.desktop");
    assert_eq!(app.title, "VS Code");
    assert_eq!(file.kind, SearchKind::File);
    assert_eq!(file.subtitle.as_deref(), Some("/home/b"));
    assert_eq!(file.app_id, None);
    assert_eq!(setting.kind, SearchKind::Setting);
    assert_eq!(setting.app_id, None);
}

#[test]
fn file_results_show_the_folder_relative_to_home() {
    let file = search_item(
        ItemKind::File,
        "file:/home/b/Projetos/notas.md",
        "notas.md",
        Some("/home/b/Projetos"),
    );

    let result = search_result_in(&file, Some(Path::new("/home/b")));

    assert_eq!(result.subtitle.as_deref(), Some("~/Projetos"));
}

#[test]
fn paired_devices_are_copied_in_order() {
    let devices = [
        BluetoothDevice {
            address: "AA:BB:CC:DD:EE:01".into(),
            name: "Fone".into(),
            connected: true,
        },
        BluetoothDevice {
            address: "AA:BB:CC:DD:EE:02".into(),
            name: "Controle".into(),
            connected: false,
        },
    ];

    let converted = paired_devices(&devices);

    assert_eq!(converted.len(), 2);
    assert_eq!(converted[0].address, "AA:BB:CC:DD:EE:01");
    assert_eq!(converted[0].name, "Fone");
    assert!(converted[0].connected);
    assert!(!converted[1].connected);
}

#[test]
fn detected_layouts_map_to_the_forced_settings() {
    use launcher_core::input::ButtonLayout;

    assert_eq!(
        detected_layout_to_dto(ButtonLayout::Xbox),
        LauncherButtonLayout::Xbox
    );
    assert_eq!(
        detected_layout_to_dto(ButtonLayout::Nintendo),
        LauncherButtonLayout::Nintendo
    );
}
