use launcher_core::search::{ItemKind, SearchItem, search};

fn item(kind: ItemKind, id: &str, title: &str) -> SearchItem {
    SearchItem {
        kind,
        id: id.into(),
        title: title.into(),
        subtitle: None,
    }
}

fn titles(results: &[SearchItem]) -> Vec<&str> {
    results.iter().map(|item| item.title.as_str()).collect()
}

fn catalog() -> Vec<SearchItem> {
    vec![
        item(ItemKind::App, "code", "Visual Studio Code"),
        item(ItemKind::App, "calc", "Calculadora"),
        item(ItemKind::File, "/n.md", "notas de código"),
        item(ItemKind::Setting, "wifi", "Wi-Fi"),
        item(ItemKind::App, "term", "Terminal"),
    ]
}

#[test]
fn empty_query_returns_nothing() {
    assert!(search(&catalog(), "", 10).is_empty());
    assert!(search(&catalog(), "   ", 10).is_empty());
}

#[test]
fn equally_good_matches_are_ordered_alphabetically() {
    let results = search(&catalog(), "cod", 10);

    assert_eq!(
        titles(&results),
        vec!["notas de código", "Visual Studio Code"]
    );
}

#[test]
fn word_prefix_comes_before_a_substring_inside_a_word() {
    let items = vec![
        item(ItemKind::App, "a", "Barcode Scanner"),
        item(ItemKind::App, "b", "Visual Studio Code"),
    ];

    assert_eq!(
        titles(&search(&items, "code", 10)),
        vec!["Visual Studio Code", "Barcode Scanner"]
    );
}

#[test]
fn word_prefix_beats_a_plain_substring() {
    let results = search(&catalog(), "stu", 10);

    assert_eq!(titles(&results), vec!["Visual Studio Code"]);
}

#[test]
fn ignores_case_and_accents() {
    let results = search(&catalog(), "CODIGO", 10);

    assert_eq!(titles(&results), vec!["notas de código"]);
}

#[test]
fn subsequence_matches_are_the_last_resort() {
    let results = search(&catalog(), "trm", 10);

    assert_eq!(titles(&results), vec!["Terminal"]);
}

#[test]
fn unrelated_queries_find_nothing() {
    assert!(search(&catalog(), "zzz", 10).is_empty());
}

#[test]
fn exact_match_wins() {
    let items = vec![
        item(ItemKind::App, "a", "Terminal Emulator"),
        item(ItemKind::App, "b", "Terminal"),
    ];

    assert_eq!(
        titles(&search(&items, "terminal", 10)),
        vec!["Terminal", "Terminal Emulator"]
    );
}

#[test]
fn respects_the_limit() {
    let results = search(&catalog(), "c", 2);

    assert_eq!(results.len(), 2);
}

#[test]
fn keeps_kind_and_id_of_the_original_item() {
    let results = search(&catalog(), "wifi", 10);

    assert_eq!(results[0].kind, ItemKind::Setting);
    assert_eq!(results[0].id, "wifi");
}
