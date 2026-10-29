use launcher_core::wallpapers::{find_images, pictures_dir_from};
use std::fs;
use std::path::{Path, PathBuf};
use tempfile::tempdir;

fn touch(path: &Path) {
    fs::create_dir_all(path.parent().unwrap()).unwrap();
    fs::write(path, b"x").unwrap();
}

#[test]
fn only_images_are_listed_in_name_order() {
    let dir = tempdir().unwrap();
    for name in ["b.jpg", "a.PNG", "notes.txt", "c.webp", "d.jpeg"] {
        touch(&dir.path().join(name));
    }

    let found = find_images(&[dir.path().to_path_buf()], 1, 10);

    let names: Vec<_> = found
        .iter()
        .map(|path| path.file_name().unwrap().to_string_lossy().into_owned())
        .collect();
    assert_eq!(names, vec!["a.PNG", "b.jpg", "c.webp", "d.jpeg"]);
}

#[test]
fn subfolders_are_searched_up_to_the_depth() {
    let dir = tempdir().unwrap();
    let shallow = dir.path().join("cosmic/one.png");
    touch(&shallow);
    touch(&dir.path().join("cosmic/deeper/two.png"));

    let found = find_images(&[dir.path().to_path_buf()], 2, 10);

    assert_eq!(found, vec![shallow]);
}

#[test]
fn hidden_files_and_folders_are_skipped() {
    let dir = tempdir().unwrap();
    touch(&dir.path().join(".hidden.png"));
    touch(&dir.path().join(".cache/thumb.png"));

    assert!(find_images(&[dir.path().to_path_buf()], 3, 10).is_empty());
}

#[test]
fn the_limit_is_respected_across_dirs() {
    let first = tempdir().unwrap();
    let second = tempdir().unwrap();
    touch(&first.path().join("1.png"));
    touch(&first.path().join("2.png"));
    touch(&second.path().join("3.png"));

    let found = find_images(
        &[first.path().to_path_buf(), second.path().to_path_buf()],
        1,
        2,
    );

    assert_eq!(found.len(), 2);
    assert!(found.iter().all(|path| path.starts_with(first.path())));
}

#[test]
fn missing_dirs_are_ignored() {
    assert!(find_images(&[PathBuf::from("/no/such/dir")], 2, 10).is_empty());
}

#[test]
fn pictures_dir_comes_from_user_dirs() {
    let text =
        "# comentário\nXDG_DESKTOP_DIR=\"$HOME/Desktop\"\nXDG_PICTURES_DIR=\"$HOME/Imagens\"\n";

    assert_eq!(
        pictures_dir_from(Some(text), Some(Path::new("/home/b"))),
        Some(PathBuf::from("/home/b/Imagens"))
    );
}

#[cfg(unix)]
#[test]
fn pictures_dir_accepts_absolute_values() {
    let text = "XDG_PICTURES_DIR=\"/data/fotos\"\n";

    assert_eq!(
        pictures_dir_from(Some(text), Some(Path::new("/home/b"))),
        Some(PathBuf::from("/data/fotos"))
    );
}

#[test]
fn pictures_dir_falls_back_to_home_pictures() {
    assert_eq!(
        pictures_dir_from(None, Some(Path::new("/home/b"))),
        Some(PathBuf::from("/home/b/Pictures"))
    );
    assert_eq!(
        pictures_dir_from(
            Some("XDG_PICTURES_DIR=\"relative\"\n"),
            Some(Path::new("/home/b"))
        ),
        Some(PathBuf::from("/home/b/Pictures"))
    );
    assert_eq!(pictures_dir_from(None, None), None);
}
