//! Testes das funções expostas que só leem o sistema. As que escrevem
//! (Wi-Fi, Bluetooth, volume, brilho, tema, abrir apps) delegam ao núcleo,
//! testado com executor falso, e aqui não rodam para não mexer na máquina.

use crate::api::catalog::{launch_app, load_catalog};
use crate::api::files::{list_recents, list_wallpapers, open_path};
use crate::api::input::{gamepad_connected, gamepad_detected_layout};
use crate::api::meta::{core_version, user_first_name};
use crate::api::settings::{
    default_settings, resolve_theme, LauncherButtonLayout, LauncherSettings, LauncherThemeMode,
    ResolvedTheme,
};
use crate::api::system::{autostart_enabled, read_battery, sample_stats};

const NOON: u16 = 12 * 60;
const NIGHT: u16 = 22 * 60;

#[test]
fn default_settings_use_the_automatic_theme() {
    assert_eq!(default_settings().theme_mode, LauncherThemeMode::Auto);
}

#[test]
fn the_theme_is_resolved_from_the_schedule() {
    let auto = default_settings();

    assert_eq!(resolve_theme(auto.clone(), NOON), Ok(ResolvedTheme::Light));
    assert_eq!(resolve_theme(auto, NIGHT), Ok(ResolvedTheme::Dark));
}

#[test]
fn invalid_input_to_resolve_theme_is_an_error() {
    let broken = LauncherSettings {
        light_starts_minute: 19 * 60,
        ..default_settings()
    };

    assert!(resolve_theme(default_settings(), 24 * 60).is_err());
    assert!(resolve_theme(broken, NOON).is_err());
}

#[test]
fn launching_an_unknown_app_is_refused_before_running_anything() {
    let error = launch_app("definitely-not-installed.desktop".into()).unwrap_err();

    assert!(error.contains("não foi encontrado"), "{error}");
}

#[test]
fn opening_a_missing_path_is_an_error() {
    let error = open_path("/no/such/file/at/all".into()).unwrap_err();

    assert_eq!(error, "programa ou arquivo não encontrado");
}

#[test]
fn without_a_listener_no_gamepad_is_connected() {
    assert!(!gamepad_connected());
}

#[test]
fn without_a_listener_the_detected_layout_is_xbox() {
    assert_eq!(gamepad_detected_layout(), LauncherButtonLayout::Xbox);
}

#[test]
fn read_only_queries_answer_consistently() {
    let stats = sample_stats();
    assert!(stats.ram_total_bytes >= stats.ram_used_bytes);
    assert!((0.0..=100.0).contains(&stats.cpu_percent));

    assert!(list_wallpapers(3).len() <= 3);
    assert!(list_recents(2).map_or(true, |recents| recents.len() <= 2));
    assert!(user_first_name().is_none_or(|name| !name.is_empty()));
    assert!(!core_version().is_empty());
}

#[test]
fn the_catalog_lists_apps_with_their_featured_ids_inside_it() {
    let catalog = load_catalog();

    let ids: Vec<_> = catalog.apps.iter().map(|app| app.id.as_str()).collect();
    for id in &catalog.game_launcher_ids {
        assert!(ids.contains(&id.as_str()), "{id}");
    }
    if let Some(id) = &catalog.music_player_id {
        assert!(ids.contains(&id.as_str()), "{id}");
    }
}

#[test]
fn the_battery_reading_never_fails_and_stays_in_range() {
    let reading = read_battery().expect("sem bateria é None, não erro");

    assert!(reading.is_none_or(|battery| battery.percent <= 100));
}

#[test]
fn reading_the_autostart_state_does_not_touch_it() {
    assert_eq!(autostart_enabled(), autostart_enabled());
}
