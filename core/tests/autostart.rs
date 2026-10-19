use launcher_core::apps::{exec_args, parse_desktop_entry};
use launcher_core::autostart::{
    autostart_file_with, desktop_entry, exec_line, is_enabled, set_enabled,
};
use std::ffi::OsString;
use std::fs;
use std::path::{Path, PathBuf};
use tempfile::tempdir;

fn env<'a>(pairs: &'a [(&'a str, &'a str)]) -> impl Fn(&str) -> Option<OsString> + 'a {
    move |name| {
        pairs
            .iter()
            .find(|(key, _)| *key == name)
            .map(|(_, value)| OsString::from(value))
    }
}

#[test]
fn the_autostart_file_lives_in_the_xdg_autostart_folder() {
    let lookup = env(&[("XDG_CONFIG_HOME", "/cfg"), ("HOME", "/home/b")]);

    assert_eq!(
        autostart_file_with(&lookup),
        Some(PathBuf::from("/cfg/autostart/gamer-launcher.desktop"))
    );
}

#[test]
fn without_xdg_it_falls_back_to_dot_config() {
    let lookup = env(&[("HOME", "/home/b")]);

    assert_eq!(
        autostart_file_with(&lookup),
        Some(PathBuf::from(
            "/home/b/.config/autostart/gamer-launcher.desktop"
        ))
    );
}

#[test]
fn without_any_home_there_is_no_autostart_file() {
    assert_eq!(autostart_file_with(&env(&[])), None);
}

#[test]
fn a_plain_path_is_used_as_is() {
    assert_eq!(
        exec_line(Path::new("/usr/bin/gamer-launcher"), None),
        "/usr/bin/gamer-launcher"
    );
}

#[test]
fn paths_with_spaces_are_quoted() {
    assert_eq!(
        exec_line(Path::new("/opt/My App/gamer-launcher"), None),
        "\"/opt/My App/gamer-launcher\""
    );
}

#[test]
fn special_characters_are_escaped_inside_the_quotes() {
    let line = exec_line(Path::new("/opt/a \"b\" $c `d` \\e%f/run"), None);

    // a barra invertida precisa de quatro: o escape de string do .desktop e o
    // das aspas se somam (veja a especificação, seção do campo Exec)
    assert_eq!(line, "\"/opt/a \\\"b\\\" \\$c \\`d\\` \\\\\\\\e%%f/run\"");
}

#[test]
fn an_appimage_path_wins_over_the_temporary_mount() {
    let line = exec_line(
        Path::new("/tmp/.mount_abc/usr/lib/gamer-launcher/gamer_launcher"),
        Some(Path::new("/home/b/Apps/Gamer_Launcher.AppImage")),
    );

    assert_eq!(line, "/home/b/Apps/Gamer_Launcher.AppImage");
}

#[test]
fn the_exec_line_survives_the_desktop_file_parser() {
    for exe in ["/usr/bin/gamer-launcher", "/opt/My App/run", "/opt/a$b/run"] {
        let entry = desktop_entry(&exec_line(Path::new(exe), None));

        let app = parse_desktop_entry("gamer-launcher.desktop", &entry).unwrap();

        assert_eq!(exec_args(&app.exec), vec![exe.to_string()], "{exe}");
    }
}

#[test]
fn the_entry_has_what_a_session_needs_to_autostart_it() {
    let entry = desktop_entry("gamer-launcher");

    for line in [
        "[Desktop Entry]",
        "Type=Application",
        "Name=Gamer Launcher",
        "Exec=gamer-launcher",
        "Terminal=false",
        "X-GNOME-Autostart-enabled=true",
    ] {
        assert!(entry.lines().any(|l| l == line), "falta {line}");
    }
}

#[test]
fn enabling_creates_the_folder_and_the_file() {
    let dir = tempdir().unwrap();
    let file = dir.path().join("config/autostart/gamer-launcher.desktop");

    set_enabled(&file, true, "gamer-launcher").unwrap();

    assert!(is_enabled(&file));
    assert!(
        fs::read_to_string(&file)
            .unwrap()
            .contains("Exec=gamer-launcher")
    );
}

#[test]
fn disabling_removes_the_file_and_is_idempotent() {
    let dir = tempdir().unwrap();
    let file = dir.path().join("autostart/gamer-launcher.desktop");
    set_enabled(&file, true, "gamer-launcher").unwrap();

    set_enabled(&file, false, "gamer-launcher").unwrap();
    set_enabled(&file, false, "gamer-launcher").unwrap();

    assert!(!file.exists());
    assert!(!is_enabled(&file));
}

#[test]
fn enabling_again_replaces_the_command() {
    let dir = tempdir().unwrap();
    let file = dir.path().join("autostart/gamer-launcher.desktop");
    set_enabled(&file, true, "velho").unwrap();

    set_enabled(&file, true, "novo").unwrap();

    let text = fs::read_to_string(&file).unwrap();
    assert!(text.contains("Exec=novo") && !text.contains("velho"));
}

#[test]
fn an_entry_turned_off_elsewhere_counts_as_disabled() {
    let dir = tempdir().unwrap();
    for off in ["Hidden=true", "X-GNOME-Autostart-enabled=false"] {
        let file = dir.path().join(format!("{off}.desktop"));
        fs::write(
            &file,
            format!("[Desktop Entry]\nType=Application\nName=X\nExec=x\n{off}\n"),
        )
        .unwrap();

        assert!(!is_enabled(&file), "{off}");
    }
}

#[test]
fn enabling_overwrites_an_entry_turned_off_elsewhere() {
    let dir = tempdir().unwrap();
    let file = dir.path().join("autostart/gamer-launcher.desktop");
    fs::create_dir_all(file.parent().unwrap()).unwrap();
    fs::write(&file, "[Desktop Entry]\nHidden=true\n").unwrap();

    set_enabled(&file, true, "gamer-launcher").unwrap();

    assert!(is_enabled(&file));
}

#[test]
fn a_failed_write_is_an_error_not_a_panic() {
    let dir = tempdir().unwrap();
    let blocker = dir.path().join("arquivo");
    fs::write(&blocker, "x").unwrap();

    // a "pasta" pai é um arquivo comum
    let result = set_enabled(&blocker.join("autostart/gamer-launcher.desktop"), true, "x");

    assert!(result.is_err());
}
