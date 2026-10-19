use launcher_core::paths::{
    config_home_with, data_dirs_with, data_home_with, history_path_with, home_dir_with,
    recents_path_with, settings_path_with, state_home_with,
};
use std::ffi::OsString;
use std::path::PathBuf;

fn env<'a>(pairs: &'a [(&'a str, &'a str)]) -> impl Fn(&str) -> Option<OsString> + 'a {
    move |name| {
        pairs
            .iter()
            .find(|(key, _)| *key == name)
            .map(|(_, value)| OsString::from(value))
    }
}

#[test]
fn data_home_prefers_an_absolute_xdg_value() {
    let lookup = env(&[("XDG_DATA_HOME", "/data"), ("HOME", "/home/b")]);

    assert_eq!(data_home_with(&lookup), Some(PathBuf::from("/data")));
}

#[test]
fn data_home_ignores_relative_xdg_values() {
    let lookup = env(&[("XDG_DATA_HOME", "relative/dir"), ("HOME", "/home/b")]);

    assert_eq!(
        data_home_with(&lookup),
        Some(PathBuf::from("/home/b/.local/share"))
    );
}

#[test]
fn data_home_needs_xdg_or_home() {
    assert_eq!(data_home_with(&env(&[])), None);
}

#[test]
fn config_home_falls_back_to_dot_config() {
    let lookup = env(&[("HOME", "/home/b")]);

    assert_eq!(
        config_home_with(&lookup),
        Some(PathBuf::from("/home/b/.config"))
    );
}

#[test]
fn data_dirs_default_when_unset_or_empty() {
    let expected = vec![
        PathBuf::from("/usr/local/share"),
        PathBuf::from("/usr/share"),
    ];

    assert_eq!(data_dirs_with(&env(&[])), expected);
    assert_eq!(data_dirs_with(&env(&[("XDG_DATA_DIRS", "")])), expected);
}

#[test]
fn data_dirs_keep_order_and_drop_relative_entries() {
    let lookup = env(&[("XDG_DATA_DIRS", "/a:rel:/b")]);

    assert_eq!(
        data_dirs_with(&lookup),
        vec![PathBuf::from("/a"), PathBuf::from("/b")]
    );
}

#[test]
fn settings_and_recents_live_under_the_xdg_homes() {
    let lookup = env(&[("XDG_CONFIG_HOME", "/cfg"), ("XDG_DATA_HOME", "/data")]);

    assert_eq!(
        settings_path_with(&lookup),
        Some(PathBuf::from("/cfg/gamer-launcher/settings.json"))
    );
    assert_eq!(
        recents_path_with(&lookup),
        Some(PathBuf::from("/data/recently-used.xbel"))
    );
}

#[test]
fn empty_or_relative_home_is_not_a_home() {
    assert_eq!(home_dir_with(&env(&[("HOME", "")])), None);
    assert_eq!(home_dir_with(&env(&[("HOME", ".")])), None);
    assert_eq!(data_home_with(&env(&[("HOME", "relative")])), None);
    assert_eq!(config_home_with(&env(&[("HOME", "")])), None);
}

#[test]
fn absolute_home_is_used() {
    assert_eq!(
        home_dir_with(&env(&[("HOME", "/home/b")])),
        Some(PathBuf::from("/home/b"))
    );
}

#[test]
fn state_home_prefers_xdg_and_falls_back_to_local_state() {
    assert_eq!(
        state_home_with(&env(&[("XDG_STATE_HOME", "/state"), ("HOME", "/home/b")])),
        Some(PathBuf::from("/state"))
    );
    assert_eq!(
        state_home_with(&env(&[("HOME", "/home/b")])),
        Some(PathBuf::from("/home/b/.local/state"))
    );
}

#[test]
fn launch_history_lives_under_the_state_home() {
    assert_eq!(
        history_path_with(&env(&[("XDG_STATE_HOME", "/state")])),
        Some(PathBuf::from("/state/gamer-launcher/history.json"))
    );
}
