//! Busca global tolerante: ignora maiúsculas e acentos e aceita letras
//! em sequência desde que próximas ("trm" encontra "Terminal") e siglas
//! ("vsc" encontra "Visual Studio Code").

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum ItemKind {
    App,
    File,
    Setting,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct SearchItem {
    pub kind: ItemKind,
    pub id: String,
    pub title: String,
    pub subtitle: Option<String>,
}

/// Quanto menor, melhor.
#[derive(Debug, Clone, Copy, PartialEq, Eq, PartialOrd, Ord)]
enum Rank {
    Exact,
    Prefix,
    WordPrefix,
    Acronym,
    Substring,
    Subsequence,
}

fn fold(text: &str) -> String {
    text.chars()
        .flat_map(char::to_lowercase)
        .map(|c| match c {
            'á' | 'à' | 'â' | 'ã' | 'ä' => 'a',
            'é' | 'è' | 'ê' | 'ë' => 'e',
            'í' | 'ì' | 'î' | 'ï' => 'i',
            'ó' | 'ò' | 'ô' | 'õ' | 'ö' => 'o',
            'ú' | 'ù' | 'û' | 'ü' => 'u',
            'ç' => 'c',
            other => other,
        })
        .collect()
}

/// Quantas vezes o tamanho da busca o trecho com as letras pode ocupar.
/// Mais que isso é coincidência (ex.: "code" em "Aplicativos de inicialização").
const MAX_SUBSEQUENCE_SPREAD: usize = 2;
const MIN_ACRONYM_LEN: usize = 2;

/// Menor trecho do texto que contém as letras da busca, em ordem.
fn tightest_subsequence_span(query: &[char], text: &[char]) -> Option<usize> {
    let first = *query.first()?;
    (0..text.len())
        .filter(|&start| text[start] == first)
        .filter_map(|start| {
            let mut wanted = query.iter().skip(1).peekable();
            let mut end = start;
            for (offset, c) in text[start + 1..].iter().enumerate() {
                if wanted.peek().is_none() {
                    break;
                }
                if wanted.peek() == Some(&c) {
                    wanted.next();
                    end = start + 1 + offset;
                }
            }
            wanted.peek().is_none().then_some(end - start + 1)
        })
        .min()
}

fn is_close_subsequence(query: &str, text: &str) -> bool {
    let (query, text): (Vec<char>, Vec<char>) = (query.chars().collect(), text.chars().collect());
    tightest_subsequence_span(&query, &text)
        .is_some_and(|span| span <= query.len() * MAX_SUBSEQUENCE_SPREAD)
}

fn is_acronym(query: &str, title: &str) -> bool {
    if query.chars().count() < MIN_ACRONYM_LEN {
        return false;
    }
    let initials: String = title
        .split(|c: char| !c.is_alphanumeric())
        .filter_map(|word| word.chars().next())
        .collect();
    initials.starts_with(query)
}

fn rank(query: &str, title: &str) -> Option<Rank> {
    if title == query {
        Some(Rank::Exact)
    } else if title.starts_with(query) {
        Some(Rank::Prefix)
    } else if title
        .split(|c: char| !c.is_alphanumeric())
        .any(|word| word.starts_with(query))
    {
        Some(Rank::WordPrefix)
    } else if is_acronym(query, title) {
        Some(Rank::Acronym)
    } else if title.contains(query) {
        Some(Rank::Substring)
    } else if is_close_subsequence(query, title) {
        Some(Rank::Subsequence)
    } else {
        None
    }
}

/// Melhores resultados primeiro; empates em ordem alfabética.
pub fn search(items: &[SearchItem], query: &str, limit: usize) -> Vec<SearchItem> {
    let query = fold(query.trim());
    if query.is_empty() {
        return Vec::new();
    }
    let mut ranked: Vec<(Rank, String, &SearchItem)> = items
        .iter()
        .filter_map(|item| {
            let title = fold(&item.title);
            rank(&query, &title).map(|rank| (rank, title, item))
        })
        .collect();
    ranked.sort_by(|a, b| (a.0, &a.1).cmp(&(b.0, &b.1)));
    ranked
        .into_iter()
        .take(limit)
        .map(|(_, _, item)| item.clone())
        .collect()
}
