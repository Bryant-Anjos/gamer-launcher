use launcher_core::history::{HistoryError, LaunchHistory};
use std::fs;
use tempfile::tempdir;

#[test]
fn a_missing_file_means_no_history() {
    let dir = tempdir().unwrap();

    let history = LaunchHistory::load(&dir.path().join("history.json")).unwrap();

    assert_eq!(history, LaunchHistory::default());
    assert_eq!(history.last_app, None);
}

#[test]
fn recording_a_launch_returns_a_new_history() {
    let empty = LaunchHistory::default();

    let next = empty.with_launch("code.desktop");

    assert_eq!(next.last_app.as_deref(), Some("code.desktop"));
    assert_eq!(empty.last_app, None, "o original não muda");
}

#[test]
fn saved_history_loads_back() {
    let dir = tempdir().unwrap();
    let path = dir.path().join("state/gamer-launcher/history.json");

    LaunchHistory::default()
        .with_launch("firefox.desktop")
        .save(&path)
        .unwrap();

    let loaded = LaunchHistory::load(&path).unwrap();
    assert_eq!(loaded.last_app.as_deref(), Some("firefox.desktop"));
}

#[test]
fn a_broken_file_is_an_error() {
    let dir = tempdir().unwrap();
    let path = dir.path().join("history.json");
    fs::write(&path, "{ not json").unwrap();

    let error = LaunchHistory::load(&path).unwrap_err();

    assert!(matches!(error, HistoryError::Parse(_)), "{error:?}");
}

#[test]
fn unknown_fields_are_tolerated() {
    let dir = tempdir().unwrap();
    let path = dir.path().join("history.json");
    fs::write(&path, r#"{"last_app":"a.desktop","future":1}"#).unwrap();

    let loaded = LaunchHistory::load(&path).unwrap();

    assert_eq!(loaded.last_app.as_deref(), Some("a.desktop"));
}
