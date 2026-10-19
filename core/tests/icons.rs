use launcher_core::icons::{icon_roots_from, pixmap_dirs_from, resolve_icon};
use std::fs;
use std::path::{Path, PathBuf};
use tempfile::tempdir;

fn touch(path: &Path) {
    fs::create_dir_all(path.parent().unwrap()).unwrap();
    fs::write(path, b"x").unwrap();
}

#[test]
fn absolute_paths_are_used_when_the_file_exists() {
    let dir = tempdir().unwrap();
    let icon = dir.path().join("studio.png");
    touch(&icon);

    let found = resolve_icon(icon.to_str().unwrap(), &[], &[]);

    assert_eq!(found, Some(icon));
}

#[test]
fn missing_absolute_paths_resolve_to_nothing() {
    assert_eq!(resolve_icon("/no/such/icon.png", &[], &[]), None);
}

#[test]
fn scalable_svg_wins_over_bitmaps() {
    let root = tempdir().unwrap();
    let svg = root.path().join("hicolor/scalable/apps/firefox.svg");
    touch(&svg);
    touch(&root.path().join("hicolor/48x48/apps/firefox.png"));

    let found = resolve_icon("firefox", &[root.path().to_path_buf()], &[]);

    assert_eq!(found, Some(svg));
}

#[test]
fn the_largest_bitmap_is_preferred() {
    let root = tempdir().unwrap();
    touch(&root.path().join("hicolor/48x48/apps/brave.png"));
    let big = root.path().join("hicolor/256x256/apps/brave.png");
    touch(&big);

    let found = resolve_icon("brave", &[root.path().to_path_buf()], &[]);

    assert_eq!(found, Some(big));
}

#[test]
fn earlier_roots_win() {
    let user = tempdir().unwrap();
    let system = tempdir().unwrap();
    let mine = user.path().join("hicolor/48x48/apps/app.png");
    touch(&mine);
    touch(&system.path().join("hicolor/256x256/apps/app.png"));

    let roots = [user.path().to_path_buf(), system.path().to_path_buf()];

    assert_eq!(resolve_icon("app", &roots, &[]), Some(mine));
}

#[test]
fn other_themes_are_searched_after_hicolor() {
    let root = tempdir().unwrap();
    let themed = root.path().join("Adwaita/scalable/apps/calc.svg");
    touch(&themed);

    let found = resolve_icon("calc", &[root.path().to_path_buf()], &[]);

    assert_eq!(found, Some(themed));
}

#[test]
fn pixmaps_are_the_last_resort() {
    let pixmaps = tempdir().unwrap();
    let pixmap = pixmaps.path().join("old.png");
    touch(&pixmap);

    let found = resolve_icon("old", &[], &[pixmaps.path().to_path_buf()]);

    assert_eq!(found, Some(pixmap));
}

#[test]
fn names_with_an_extension_are_looked_up_without_it() {
    let pixmaps = tempdir().unwrap();
    let pixmap = pixmaps.path().join("tool.png");
    touch(&pixmap);

    let found = resolve_icon("tool.png", &[], &[pixmaps.path().to_path_buf()]);

    assert_eq!(found, Some(pixmap));
}

#[test]
fn formats_flutter_cannot_draw_are_ignored() {
    let pixmaps = tempdir().unwrap();
    touch(&pixmaps.path().join("legacy.xpm"));

    assert_eq!(
        resolve_icon("legacy", &[], &[pixmaps.path().to_path_buf()]),
        None
    );
    let absolute = pixmaps.path().join("legacy.xpm");
    assert_eq!(resolve_icon(absolute.to_str().unwrap(), &[], &[]), None);
}

#[test]
fn names_that_try_to_escape_the_icon_dirs_are_refused() {
    let root = tempdir().unwrap();
    touch(&root.path().join("secret.png"));

    let found = resolve_icon("../../secret", &[root.path().join("a/b")], &[]);

    assert_eq!(found, None);
    assert_eq!(resolve_icon("", &[root.path().to_path_buf()], &[]), None);
}

#[test]
fn icon_roots_follow_the_xdg_order_without_repeats() {
    let roots = icon_roots_from(
        Some(PathBuf::from("/home/b/.local/share")),
        Some(PathBuf::from("/home/b")),
        &[PathBuf::from("/usr/share"), PathBuf::from("/usr/share")],
    );

    let expected: Vec<PathBuf> = [
        "/home/b/.icons",
        "/home/b/.local/share/icons",
        "/home/b/.local/share/flatpak/exports/share/icons",
        "/usr/share/icons",
        "/var/lib/flatpak/exports/share/icons",
        "/var/lib/snapd/desktop/icons",
    ]
    .iter()
    .map(PathBuf::from)
    .collect();
    assert_eq!(roots, expected);
}

#[test]
fn pixmaps_come_from_the_system_data_dirs() {
    let dirs = pixmap_dirs_from(&[
        PathBuf::from("/usr/local/share"),
        PathBuf::from("/usr/share"),
    ]);

    assert_eq!(
        dirs,
        vec![
            PathBuf::from("/usr/local/share/pixmaps"),
            PathBuf::from("/usr/share/pixmaps")
        ]
    );
}
