use launcher_core::settings::{Settings, ThemeMode};
use launcher_core::theme::{Theme, resolve_theme};
use launcher_core::time_of_day::TimeOfDay;

fn at(text: &str) -> TimeOfDay {
    TimeOfDay::parse(text).unwrap()
}

fn auto_settings(dark_from: &str, light_from: &str) -> Settings {
    Settings::default()
        .with_theme_mode(ThemeMode::Auto)
        .with_auto_schedule(at(dark_from), at(light_from))
        .unwrap()
}

#[test]
fn parses_hours_and_minutes() {
    assert_eq!(at("07:05").minutes(), 7 * 60 + 5);
    assert_eq!(at("00:00").minutes(), 0);
    assert_eq!(at("23:59").minutes(), 23 * 60 + 59);
}

#[test]
fn rejects_malformed_times() {
    for bad in ["24:00", "12:60", "7:5", "abc", "", "12-30", "12:3"] {
        assert!(TimeOfDay::parse(bad).is_err(), "{bad} should be rejected");
    }
}

#[test]
fn displays_as_zero_padded_text() {
    assert_eq!(at("07:05").to_string(), "07:05");
}

#[test]
fn from_minutes_rejects_values_past_midnight() {
    assert!(TimeOfDay::from_minutes(1440).is_err());
    assert_eq!(TimeOfDay::from_minutes(61).unwrap().to_string(), "01:01");
}

#[test]
fn fixed_modes_ignore_the_clock() {
    let light = Settings::default().with_theme_mode(ThemeMode::Light);
    let dark = Settings::default().with_theme_mode(ThemeMode::Dark);

    assert_eq!(resolve_theme(&light, at("23:00")), Theme::Light);
    assert_eq!(resolve_theme(&dark, at("12:00")), Theme::Dark);
}

#[test]
fn auto_is_dark_across_midnight() {
    let settings = auto_settings("19:00", "06:30");

    assert_eq!(resolve_theme(&settings, at("20:00")), Theme::Dark);
    assert_eq!(resolve_theme(&settings, at("03:00")), Theme::Dark);
    assert_eq!(resolve_theme(&settings, at("19:00")), Theme::Dark);
}

#[test]
fn auto_is_light_during_the_day() {
    let settings = auto_settings("19:00", "06:30");

    assert_eq!(resolve_theme(&settings, at("06:30")), Theme::Light);
    assert_eq!(resolve_theme(&settings, at("12:00")), Theme::Light);
    assert_eq!(resolve_theme(&settings, at("18:59")), Theme::Light);
}

#[test]
fn auto_handles_a_dark_window_that_does_not_cross_midnight() {
    let settings = auto_settings("01:00", "05:00");

    assert_eq!(resolve_theme(&settings, at("02:00")), Theme::Dark);
    assert_eq!(resolve_theme(&settings, at("12:00")), Theme::Light);
    assert_eq!(resolve_theme(&settings, at("05:00")), Theme::Light);
}
