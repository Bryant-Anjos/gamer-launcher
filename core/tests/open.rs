use launcher_core::apps::AppEntry;
use launcher_core::open::{OpenError, OpenTarget, Opener};
use launcher_core::search::{ItemKind, SearchItem};
use std::fs;
use std::path::PathBuf;
use tempfile::tempdir;

fn item(kind: ItemKind, id: &str) -> SearchItem {
    SearchItem {
        kind,
        id: id.into(),
        title: "x".into(),
        subtitle: None,
    }
}

fn app_running(id: &str, exec: &str) -> AppEntry {
    AppEntry {
        id: id.into(),
        name: "X".into(),
        exec: exec.into(),
        icon: None,
        categories: Vec::new(),
        terminal: false,
        working_dir: None,
    }
}

#[test]
fn items_resolve_to_targets() {
    assert_eq!(
        OpenTarget::from_item(&item(ItemKind::App, "app:code.desktop")).unwrap(),
        OpenTarget::App("code.desktop".into())
    );
    assert_eq!(
        OpenTarget::from_item(&item(ItemKind::File, "file:/home/b/x.md")).unwrap(),
        OpenTarget::Path(PathBuf::from("/home/b/x.md"))
    );
    assert_eq!(
        OpenTarget::from_item(&item(ItemKind::Setting, "setting:sound")).unwrap(),
        OpenTarget::Settings("sound".into())
    );
}

#[test]
fn unknown_prefixes_and_pages_are_refused() {
    for id in [
        "",
        "code.desktop",
        "cmd:rm",
        "setting:nao-existe",
        "setting:sound; rm -rf /",
    ] {
        assert!(
            matches!(
                OpenTarget::from_item(&item(ItemKind::App, id)),
                Err(OpenError::UnknownItem(_))
            ),
            "{id:?}"
        );
    }
}

#[test]
fn relative_file_paths_are_refused() {
    assert!(matches!(
        OpenTarget::from_item(&item(ItemKind::File, "file:relativo/x.md")),
        Err(OpenError::UnknownItem(_))
    ));
}

#[test]
fn opening_an_app_launches_it() {
    let apps = [app_running("ok.desktop", "true")];

    let result = Opener::system().open(&OpenTarget::App("ok.desktop".into()), &apps);

    assert!(result.is_ok());
}

#[test]
fn opening_an_unknown_app_is_an_error() {
    let result = Opener::system().open(&OpenTarget::App("sumiu.desktop".into()), &[]);

    assert!(matches!(result, Err(OpenError::AppNotFound(_))));
}

#[test]
fn a_failing_app_launch_is_reported() {
    let apps = [app_running("ruim.desktop", "programa-que-nao-existe-xyz")];

    let result = Opener::system().open(&OpenTarget::App("ruim.desktop".into()), &apps);

    assert!(matches!(result, Err(OpenError::Launch(_))));
}

#[cfg(unix)]
fn recording_script(dir: &std::path::Path, name: &str) -> (String, PathBuf) {
    use std::os::unix::fs::PermissionsExt;
    let out = dir.join(format!("{name}.out"));
    let script = dir.join(name);
    fs::write(
        &script,
        format!("#!/bin/sh\necho \"$@\" > '{}'\n", out.display()),
    )
    .unwrap();
    fs::set_permissions(&script, fs::Permissions::from_mode(0o755)).unwrap();
    (script.display().to_string(), out)
}

#[cfg(unix)]
fn wait_for(path: &std::path::Path) -> String {
    for _ in 0..60 {
        if let Ok(text) = fs::read_to_string(path)
            && !text.is_empty()
        {
            return text;
        }
        std::thread::sleep(std::time::Duration::from_millis(50));
    }
    panic!("{} nunca foi escrito", path.display());
}

#[cfg(unix)]
#[test]
fn files_open_through_the_file_opener_with_their_path() {
    let dir = tempdir().unwrap();
    let (script, out) = recording_script(dir.path(), "opener");
    let file = dir.path().join("notas.md");
    fs::write(&file, "oi").unwrap();
    let opener = Opener::with_programs(&script, "unused");

    opener.open(&OpenTarget::Path(file.clone()), &[]).unwrap();

    assert_eq!(wait_for(&out).trim(), file.display().to_string());
}

#[cfg(unix)]
#[test]
fn settings_pages_open_through_the_settings_app() {
    let dir = tempdir().unwrap();
    let (script, out) = recording_script(dir.path(), "settings");
    let opener = Opener::with_programs("unused", &script);

    opener
        .open(&OpenTarget::Settings("wireless".into()), &[])
        .unwrap();

    assert_eq!(wait_for(&out).trim(), "wireless");
}

#[test]
fn opening_a_missing_file_is_an_error() {
    let dir = tempdir().unwrap();

    let result = Opener::with_programs("true", "true")
        .open(&OpenTarget::Path(dir.path().join("sumiu.txt")), &[]);

    assert!(matches!(result, Err(OpenError::PathMissing(_))));
}

#[test]
fn a_missing_opener_program_is_reported() {
    let dir = tempdir().unwrap();
    let file = dir.path().join("a.txt");
    fs::write(&file, "x").unwrap();

    let result = Opener::with_programs("programa-que-nao-existe-xyz", "true")
        .open(&OpenTarget::Path(file), &[]);

    assert!(matches!(result, Err(OpenError::Launch(_))));
}
