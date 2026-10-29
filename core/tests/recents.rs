use launcher_core::recents::{RecentsError, load_recents, parse_recents};
use std::fs;
use std::path::PathBuf;
use tempfile::tempdir;

const XBEL: &str = r#"<?xml version="1.0" encoding="UTF-8"?>
<xbel version="1.0">
  <bookmark href="file:///home/b/old.txt" added="2026-01-01T10:00:00Z" modified="2026-01-01T10:00:00Z"/>
  <bookmark href="file:///home/b/My%20Project/notes.md" added="2026-10-01T09:00:00Z" modified="2026-10-18T09:00:00Z">
    <info><metadata owner="x"/></info>
  </bookmark>
  <bookmark href="https://example.com/page" added="2026-10-19T09:00:00Z" modified="2026-10-19T09:00:00Z"/>
  <bookmark href="file:///home/b/new.rs" added="2026-10-10T09:00:00Z" modified="2026-10-17T09:00:00Z"/>
</xbel>"#;

#[test]
fn lists_local_files_newest_first() {
    let items = parse_recents(XBEL, 10).unwrap();

    let paths: Vec<_> = items.iter().map(|item| item.path.clone()).collect();
    assert_eq!(
        paths,
        vec![
            PathBuf::from("/home/b/My Project/notes.md"),
            PathBuf::from("/home/b/new.rs"),
            PathBuf::from("/home/b/old.txt"),
        ]
    );
}

#[test]
fn skips_non_file_links() {
    let items = parse_recents(XBEL, 10).unwrap();

    assert!(items.iter().all(|item| !item.path.starts_with("https:")));
    assert_eq!(items.len(), 3);
}

#[test]
fn respects_the_limit() {
    let items = parse_recents(XBEL, 2).unwrap();

    assert_eq!(items.len(), 2);
    assert_eq!(items[0].modified, "2026-10-18T09:00:00Z");
}

#[test]
fn empty_documents_give_no_items() {
    let items = parse_recents(r#"<xbel version="1.0"></xbel>"#, 5).unwrap();

    assert!(items.is_empty());
}

#[test]
fn malformed_xml_is_an_error() {
    let result = parse_recents("<xbel><bookmark href=", 5);

    assert!(matches!(result, Err(RecentsError::Parse(_))));
}

fn xbel_for(files: &[(&std::path::Path, &str)]) -> String {
    let bookmarks: String = files
        .iter()
        .map(|(path, modified)| {
            format!(
                r#"<bookmark href="file://{}" modified="{modified}"/>"#,
                path.display()
            )
        })
        .collect();
    format!(r#"<xbel version="1.0">{bookmarks}</xbel>"#)
}

#[test]
fn loading_a_missing_file_gives_an_empty_list() {
    let dir = tempdir().unwrap();

    let items = load_recents(&dir.path().join("none.xbel"), 5).unwrap();

    assert!(items.is_empty());
}

#[cfg(unix)]
#[test]
fn loading_drops_files_that_no_longer_exist_before_applying_the_limit() {
    let dir = tempdir().unwrap();
    let old = dir.path().join("old.txt");
    let kept = dir.path().join("kept.txt");
    fs::write(&old, "x").unwrap();
    fs::write(&kept, "x").unwrap();
    let gone = dir.path().join("gone.txt");
    let xbel = dir.path().join("recent.xbel");
    fs::write(
        &xbel,
        xbel_for(&[
            (&gone, "2026-10-19T00:00:00Z"),
            (&kept, "2026-10-18T00:00:00Z"),
            (&old, "2026-01-01T00:00:00Z"),
        ]),
    )
    .unwrap();

    let items = load_recents(&xbel, 1).unwrap();

    assert_eq!(items.len(), 1);
    assert_eq!(items[0].path, kept);
}

fn single_href(href: &str) -> Vec<launcher_core::recents::RecentItem> {
    let xml = format!(
        r#"<xbel version="1.0"><bookmark href="{href}" modified="2026-10-18T09:00:00Z"/></xbel>"#
    );
    parse_recents(&xml, 5).unwrap()
}

#[test]
fn invalid_percent_sequences_stay_literal() {
    let items = single_href("file:///home/b/a%+fb%zz%4");

    assert_eq!(items[0].path, PathBuf::from("/home/b/a%+fb%zz%4"));
}

#[cfg(unix)]
#[test]
fn non_utf8_names_survive_decoding() {
    use std::ffi::OsString;
    use std::os::unix::ffi::OsStringExt;

    let items = single_href("file:///home/b/%FF.txt");

    assert_eq!(
        items[0].path.as_os_str(),
        OsString::from_vec(b"/home/b/\xff.txt".to_vec())
    );
}

#[test]
fn localhost_is_accepted_and_other_hosts_are_not() {
    assert_eq!(
        single_href("file://localhost/home/x")[0].path,
        PathBuf::from("/home/x")
    );
    assert!(single_href("file://otherhost/home/x").is_empty());
}

#[test]
fn relative_file_links_are_dropped() {
    assert!(single_href("file://relative/path").is_empty());
}

#[test]
fn fractional_seconds_order_chronologically() {
    let xml = r#"<xbel version="1.0">
        <bookmark href="file:///a" modified="2026-10-18T09:00:00Z"/>
        <bookmark href="file:///b" modified="2026-10-18T09:00:00.500000Z"/>
        <bookmark href="file:///c" modified="2026-10-18T09:00:01Z"/>
        <bookmark href="file:///d" modified="2026-10-18T09:00:00.900000Z"/>
    </xbel>"#;

    let paths: Vec<_> = parse_recents(xml, 10)
        .unwrap()
        .into_iter()
        .map(|item| item.path)
        .collect();

    assert_eq!(
        paths,
        vec![
            PathBuf::from("/c"),
            PathBuf::from("/d"),
            PathBuf::from("/b"),
            PathBuf::from("/a"),
        ]
    );
}
