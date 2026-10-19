use launcher_core::settings::{Panel, Settings, SettingsError, ThemeMode};
use launcher_core::time_of_day::TimeOfDay;
use std::fs;
use std::path::PathBuf;
use tempfile::tempdir;

fn at(text: &str) -> TimeOfDay {
    TimeOfDay::parse(text).unwrap()
}

#[test]
fn defaults_are_auto_theme_with_every_panel_visible() {
    let settings = Settings::default();

    assert_eq!(settings.theme_mode, ThemeMode::Auto);
    assert_eq!(settings.dark_starts_at, at("19:00"));
    assert_eq!(settings.light_starts_at, at("06:00"));
    assert_eq!(settings.wallpaper, None);
    assert!(settings.favorites.is_empty());
    for panel in Panel::ALL {
        assert!(settings.is_panel_visible(panel), "{panel:?}");
    }
}

#[test]
fn loading_a_missing_file_gives_defaults() {
    let dir = tempdir().unwrap();

    let loaded = Settings::load(&dir.path().join("settings.json")).unwrap();

    assert_eq!(loaded, Settings::default());
}

#[test]
fn saved_settings_load_back_identical() {
    let dir = tempdir().unwrap();
    let path = dir.path().join("nested/deeper/settings.json");
    let settings = Settings::default()
        .with_theme_mode(ThemeMode::Dark)
        .with_wallpaper(Some(PathBuf::from("/walls/mountain.png")))
        .with_panel_visible(Panel::System, false)
        .with_favorites(vec!["code.desktop".into(), "spotify.desktop".into()])
        .unwrap();

    settings.save(&path).unwrap();

    assert_eq!(Settings::load(&path).unwrap(), settings);
}

#[test]
fn saving_leaves_no_temporary_file_behind() {
    let dir = tempdir().unwrap();
    let path = dir.path().join("settings.json");

    Settings::default().save(&path).unwrap();

    let names: Vec<_> = fs::read_dir(dir.path())
        .unwrap()
        .map(|entry| entry.unwrap().file_name().to_string_lossy().into_owned())
        .collect();
    assert_eq!(names, vec!["settings.json"]);
}

#[test]
fn partial_files_fill_the_rest_with_defaults() {
    let dir = tempdir().unwrap();
    let path = dir.path().join("settings.json");
    fs::write(&path, r#"{"theme_mode":"dark"}"#).unwrap();

    let loaded = Settings::load(&path).unwrap();

    assert_eq!(loaded.theme_mode, ThemeMode::Dark);
    assert_eq!(loaded.dark_starts_at, at("19:00"));
    assert!(loaded.is_panel_visible(Panel::Recents));
}

#[test]
fn broken_json_is_reported_not_swallowed() {
    let dir = tempdir().unwrap();
    let path = dir.path().join("settings.json");
    fs::write(&path, "{not json").unwrap();

    assert!(matches!(
        Settings::load(&path),
        Err(SettingsError::Parse(_))
    ));
}

#[test]
fn invalid_times_in_a_file_are_rejected() {
    let dir = tempdir().unwrap();
    let path = dir.path().join("settings.json");
    fs::write(&path, r#"{"dark_starts_at":"25:00"}"#).unwrap();

    assert!(matches!(
        Settings::load(&path),
        Err(SettingsError::Parse(_))
    ));
}

#[test]
fn identical_schedule_times_are_invalid() {
    let dir = tempdir().unwrap();
    let path = dir.path().join("settings.json");
    fs::write(
        &path,
        r#"{"dark_starts_at":"08:00","light_starts_at":"08:00"}"#,
    )
    .unwrap();

    assert!(matches!(
        Settings::load(&path),
        Err(SettingsError::Invalid(_))
    ));
}

#[test]
fn duplicate_favorites_are_invalid() {
    let dir = tempdir().unwrap();
    let path = dir.path().join("settings.json");
    fs::write(&path, r#"{"favorites":["a.desktop","a.desktop"]}"#).unwrap();

    assert!(matches!(
        Settings::load(&path),
        Err(SettingsError::Invalid(_))
    ));
}

#[test]
fn schedule_with_equal_times_is_refused_by_the_builder() {
    let result = Settings::default().with_auto_schedule(at("08:00"), at("08:00"));

    assert!(matches!(result, Err(SettingsError::Invalid(_))));
}

#[test]
fn builders_return_new_values_and_leave_the_original_untouched() {
    let original = Settings::default();

    let changed = original
        .with_theme_mode(ThemeMode::Light)
        .with_panel_visible(Panel::Search, false);

    assert_eq!(original.theme_mode, ThemeMode::Auto);
    assert!(original.is_panel_visible(Panel::Search));
    assert_eq!(changed.theme_mode, ThemeMode::Light);
    assert!(!changed.is_panel_visible(Panel::Search));
}

#[test]
fn favorites_builder_refuses_duplicates_right_away() {
    let result = Settings::default().with_favorites(vec!["a.desktop".into(), "a.desktop".into()]);

    assert!(matches!(result, Err(SettingsError::Invalid(_))));
}

#[test]
fn favorites_builder_refuses_empty_ids() {
    let result = Settings::default().with_favorites(vec!["".into()]);

    assert!(matches!(result, Err(SettingsError::Invalid(_))));
}

#[test]
fn empty_favorite_ids_in_a_file_are_rejected() {
    let dir = tempdir().unwrap();
    let path = dir.path().join("settings.json");
    fs::write(&path, r#"{"favorites":[""]}"#).unwrap();

    assert!(matches!(
        Settings::load(&path),
        Err(SettingsError::Invalid(_))
    ));
}

#[test]
fn a_failed_save_leaves_no_temporary_file() {
    let dir = tempdir().unwrap();
    let path = dir.path().join("settings.json");
    fs::create_dir(&path).unwrap();

    assert!(Settings::default().save(&path).is_err());

    let leftovers: Vec<_> = fs::read_dir(dir.path())
        .unwrap()
        .map(|entry| entry.unwrap().file_name().to_string_lossy().into_owned())
        .filter(|name| name != "settings.json")
        .collect();
    assert!(leftovers.is_empty(), "{leftovers:?}");
}

#[test]
fn the_button_layout_is_automatic_by_default_and_survives_a_round_trip() {
    use launcher_core::input::ButtonLayoutSetting;
    let dir = tempdir().unwrap();
    let path = dir.path().join("settings.json");
    assert_eq!(Settings::default().button_layout, ButtonLayoutSetting::Auto);

    Settings::default()
        .with_button_layout(ButtonLayoutSetting::Nintendo)
        .save(&path)
        .unwrap();

    assert_eq!(
        Settings::load(&path).unwrap().button_layout,
        ButtonLayoutSetting::Nintendo
    );
    assert!(fs::read_to_string(&path).unwrap().contains("\"nintendo\""));
}

#[test]
fn files_without_a_button_layout_fall_back_to_automatic() {
    use launcher_core::input::ButtonLayoutSetting;
    let dir = tempdir().unwrap();
    let path = dir.path().join("settings.json");
    fs::write(&path, r#"{"theme_mode":"dark"}"#).unwrap();

    assert_eq!(
        Settings::load(&path).unwrap().button_layout,
        ButtonLayoutSetting::Auto
    );
}

#[test]
fn an_unknown_button_layout_in_a_file_is_a_parse_error() {
    let dir = tempdir().unwrap();
    let path = dir.path().join("settings.json");
    fs::write(&path, r#"{"button_layout":"playstation"}"#).unwrap();

    assert!(matches!(
        Settings::load(&path),
        Err(SettingsError::Parse(_))
    ));
}
