use launcher_core::apps::{
    AppEntry, app_dirs_from, discover_apps, exec_args, find_app, launch, open_path_with,
    parse_desktop_entry,
};
use std::fs;
use std::path::PathBuf;
use tempfile::tempdir;

const VSCODE: &str = "\
[Desktop Entry]
Name=Visual Studio Code
Exec=code --unity-launch %F
Icon=vscode
Type=Application
Categories=Utility;TextEditor;Development;

[Desktop Action new-empty-window]
Name=New Empty Window
Exec=code --new-window %F
";

#[test]
fn parses_the_main_group_only() {
    let app = parse_desktop_entry("code.desktop", VSCODE).unwrap();

    assert_eq!(app.id, "code.desktop");
    assert_eq!(app.name, "Visual Studio Code");
    assert_eq!(app.exec, "code --unity-launch %F");
    assert_eq!(app.icon.as_deref(), Some("vscode"));
    assert_eq!(app.categories, vec!["Utility", "TextEditor", "Development"]);
}

#[test]
fn hidden_entries_are_skipped() {
    for flag in ["NoDisplay=true", "Hidden=true"] {
        let text = format!("[Desktop Entry]\nName=X\nExec=x\nType=Application\n{flag}\n");
        assert!(parse_desktop_entry("x.desktop", &text).is_none(), "{flag}");
    }
}

#[test]
fn non_applications_are_skipped() {
    let text = "[Desktop Entry]\nName=Site\nExec=x\nType=Link\n";

    assert!(parse_desktop_entry("site.desktop", text).is_none());
}

#[test]
fn entries_without_name_or_exec_are_skipped() {
    assert!(
        parse_desktop_entry("a.desktop", "[Desktop Entry]\nType=Application\nExec=a\n").is_none()
    );
    assert!(
        parse_desktop_entry("b.desktop", "[Desktop Entry]\nType=Application\nName=B\n").is_none()
    );
}

#[test]
fn comments_and_blank_lines_are_ignored() {
    let text = "# top\n\n[Desktop Entry]\n# note\nName=Calc\nExec=calc\nType=Application\n";

    assert_eq!(
        parse_desktop_entry("calc.desktop", text).unwrap().name,
        "Calc"
    );
}

#[test]
fn exec_drops_field_codes() {
    assert_eq!(
        exec_args("code --unity-launch %F"),
        vec!["code", "--unity-launch"]
    );
    assert_eq!(exec_args("firefox %u"), vec!["firefox"]);
}

#[test]
fn exec_keeps_quoted_arguments_together() {
    assert_eq!(
        exec_args(r#""/opt/My App/run" --flag %u"#),
        vec!["/opt/My App/run", "--flag"]
    );
}

#[test]
fn exec_turns_double_percent_into_a_literal_percent() {
    assert_eq!(exec_args("echo 100%%"), vec!["echo", "100%"]);
}

#[test]
fn discovery_merges_dirs_with_the_first_one_winning() {
    let first = tempdir().unwrap();
    let second = tempdir().unwrap();
    let entry = |name: &str| format!("[Desktop Entry]\nName={name}\nExec=x\nType=Application\n");
    fs::write(first.path().join("same.desktop"), entry("From first")).unwrap();
    fs::write(second.path().join("same.desktop"), entry("From second")).unwrap();
    fs::write(second.path().join("zeta.desktop"), entry("zeta")).unwrap();
    fs::write(second.path().join("alpha.desktop"), entry("Alpha")).unwrap();
    fs::write(second.path().join("readme.txt"), "not an app").unwrap();

    let apps = discover_apps(&[
        first.path().to_path_buf(),
        second.path().to_path_buf(),
        first.path().join("does-not-exist"),
    ]);

    let names: Vec<_> = apps.iter().map(|app| app.name.as_str()).collect();
    assert_eq!(names, vec!["Alpha", "From first", "zeta"]);
}

fn app_running(exec: &str) -> AppEntry {
    AppEntry {
        id: "x.desktop".into(),
        name: "X".into(),
        exec: exec.into(),
        icon: None,
        categories: Vec::new(),
        terminal: false,
        working_dir: None,
    }
}

#[test]
fn app_dirs_list_user_dirs_first_then_system_without_repeats() {
    let dirs = app_dirs_from(
        Some(PathBuf::from("/home/b/.local/share")),
        Some(PathBuf::from("/home/b")),
        &[
            PathBuf::from("/usr/local/share"),
            PathBuf::from("/usr/share"),
            PathBuf::from("/usr/share"),
        ],
    );

    let expected: Vec<PathBuf> = [
        "/home/b/.local/share/applications",
        "/home/b/.local/share/flatpak/exports/share/applications",
        "/usr/local/share/applications",
        "/usr/share/applications",
        "/var/lib/flatpak/exports/share/applications",
        "/var/lib/snapd/desktop/applications",
    ]
    .iter()
    .map(PathBuf::from)
    .collect();
    assert_eq!(dirs, expected);
}

#[cfg(unix)]
#[test]
fn launch_starts_a_real_program() {
    assert!(launch(&app_running("true")).is_ok());
}

#[test]
fn launch_fails_for_an_empty_command() {
    let error = launch(&app_running("%U")).unwrap_err();

    assert_eq!(error.kind(), std::io::ErrorKind::InvalidInput);
}

#[test]
fn launch_reports_a_missing_program() {
    let error = launch(&app_running("definitely-not-a-real-program-xyz")).unwrap_err();

    assert_eq!(error.kind(), std::io::ErrorKind::NotFound);
}

#[test]
fn explicit_empty_arguments_are_kept() {
    assert_eq!(exec_args(r#"foo "" bar %U"#), vec!["foo", "", "bar"]);
}

#[test]
fn parses_terminal_and_working_directory() {
    let text =
        "[Desktop Entry]\nName=Htop\nExec=htop\nType=Application\nTerminal=true\nPath=/opt/htop\n";

    let app = parse_desktop_entry("htop.desktop", text).unwrap();

    assert!(app.terminal);
    assert_eq!(app.working_dir, Some(PathBuf::from("/opt/htop")));
}

#[test]
fn terminal_and_path_default_to_off() {
    let app = parse_desktop_entry("code.desktop", VSCODE).unwrap();

    assert!(!app.terminal);
    assert_eq!(app.working_dir, None);
}

#[test]
fn terminal_apps_are_refused_instead_of_failing_silently() {
    let app = AppEntry {
        terminal: true,
        ..app_running("true")
    };

    let error = launch(&app).unwrap_err();

    assert_eq!(error.kind(), std::io::ErrorKind::Unsupported);
}

#[cfg(unix)]
#[test]
fn launch_runs_in_the_working_directory() {
    let dir = tempdir().unwrap();
    let app = AppEntry {
        working_dir: Some(dir.path().to_path_buf()),
        ..app_running(r#"sh -c "pwd > where.txt""#)
    };

    launch(&app).unwrap();

    let marker = dir.path().join("where.txt");
    for _ in 0..40 {
        if marker.exists() && std::fs::metadata(&marker).unwrap().len() > 0 {
            break;
        }
        std::thread::sleep(std::time::Duration::from_millis(50));
    }
    let written = std::fs::read_to_string(&marker).unwrap();
    assert_eq!(
        PathBuf::from(written.trim()).canonicalize().unwrap(),
        dir.path().canonicalize().unwrap()
    );
}

#[test]
fn apps_are_found_by_id() {
    let apps = vec![
        app_running("a"),
        AppEntry {
            id: "b.desktop".into(),
            ..app_running("b")
        },
    ];

    assert_eq!(
        find_app(&apps, "b.desktop").map(|app| app.exec.as_str()),
        Some("b")
    );
    assert_eq!(find_app(&apps, "missing.desktop"), None);
}

#[cfg(unix)]
#[test]
fn opening_an_existing_path_runs_the_opener() {
    let dir = tempdir().unwrap();

    assert!(open_path_with("true", dir.path()).is_ok());
}

#[test]
fn opening_a_missing_path_fails_before_running_anything() {
    let error = open_path_with("true", std::path::Path::new("/no/such/file")).unwrap_err();

    assert_eq!(error.kind(), std::io::ErrorKind::NotFound);
}

#[test]
fn opening_without_an_opener_reports_it() {
    let dir = tempdir().unwrap();

    let error = open_path_with("definitely-not-a-real-opener-xyz", dir.path()).unwrap_err();

    assert_eq!(error.kind(), std::io::ErrorKind::NotFound);
}

#[test]
fn opening_a_relative_path_is_refused() {
    let error = open_path_with("true", std::path::Path::new("-v")).unwrap_err();

    assert_eq!(error.kind(), std::io::ErrorKind::InvalidInput);
}
