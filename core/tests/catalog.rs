use launcher_core::apps::AppEntry;
use launcher_core::catalog::{SETTINGS_PAGES, build_catalog};
use launcher_core::recents::RecentItem;
use launcher_core::search::{ItemKind, search};
use std::collections::HashSet;
use std::path::PathBuf;

fn app(id: &str, name: &str) -> AppEntry {
    AppEntry {
        id: id.into(),
        name: name.into(),
        exec: "x".into(),
        icon: None,
        categories: Vec::new(),
        terminal: false,
        working_dir: None,
    }
}

fn recent(path: &str) -> RecentItem {
    RecentItem {
        path: PathBuf::from(path),
        modified: "2026-10-18T09:00:00Z".into(),
    }
}

#[test]
fn apps_become_items_keyed_by_their_desktop_id() {
    let catalog = build_catalog(&[app("code.desktop", "Visual Studio Code")], &[]);

    let item = catalog
        .iter()
        .find(|item| item.kind == ItemKind::App)
        .unwrap();
    assert_eq!(item.id, "app:code.desktop");
    assert_eq!(item.title, "Visual Studio Code");
    assert_eq!(item.subtitle, None);
}

#[test]
fn recent_files_show_their_name_and_folder() {
    let catalog = build_catalog(&[], &[recent("/home/b/projetos/notas.md")]);

    let item = catalog
        .iter()
        .find(|item| item.kind == ItemKind::File)
        .unwrap();
    assert_eq!(item.id, "file:/home/b/projetos/notas.md");
    assert_eq!(item.title, "notas.md");
    assert_eq!(item.subtitle.as_deref(), Some("/home/b/projetos"));
}

#[test]
fn files_without_a_name_are_skipped() {
    let catalog = build_catalog(&[], &[recent("/")]);

    assert!(catalog.iter().all(|item| item.kind != ItemKind::File));
}

#[test]
fn every_settings_page_is_listed_once() {
    let catalog = build_catalog(&[], &[]);

    let settings: Vec<_> = catalog
        .iter()
        .filter(|item| item.kind == ItemKind::Setting)
        .collect();
    assert_eq!(settings.len(), SETTINGS_PAGES.len());
    let ids: HashSet<_> = settings.iter().map(|item| &item.id).collect();
    assert_eq!(ids.len(), settings.len());
    assert!(ids.contains(&"setting:wireless".to_string()));
}

#[test]
fn settings_pages_have_names_and_unique_page_ids() {
    let pages: HashSet<_> = SETTINGS_PAGES.iter().map(|page| page.page).collect();

    assert_eq!(pages.len(), SETTINGS_PAGES.len());
    assert!(
        SETTINGS_PAGES
            .iter()
            .all(|page| !page.page.is_empty() && !page.title.is_empty())
    );
}

#[test]
fn the_catalog_lists_apps_then_files_then_settings() {
    let catalog = build_catalog(&[app("a.desktop", "A")], &[recent("/x/y.txt")]);

    let kinds: Vec<_> = catalog.iter().map(|item| item.kind).collect();
    assert_eq!(kinds.first(), Some(&ItemKind::App));
    assert_eq!(kinds.get(1), Some(&ItemKind::File));
    assert!(kinds[2..].iter().all(|kind| *kind == ItemKind::Setting));
}

#[test]
fn search_finds_each_kind_in_the_catalog() {
    let catalog = build_catalog(
        &[app("code.desktop", "Visual Studio Code")],
        &[recent("/home/b/notas.md")],
    );

    let titles = |query: &str| -> Vec<String> {
        search(&catalog, query, 5)
            .into_iter()
            .map(|item| item.title)
            .collect()
    };

    assert_eq!(titles("visual"), ["Visual Studio Code"]);
    assert_eq!(titles("notas"), ["notas.md"]);
    assert!(titles("bluet").contains(&"Bluetooth".to_string()));
    assert!(titles("papel de").contains(&"Papel de parede".to_string()));
    assert!(titles("wifi").contains(&"Wi-Fi".to_string()));
}
