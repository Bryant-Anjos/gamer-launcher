//! Busca global tolerante: ignora maiúsculas e acentos e aceita letras
//! em sequência (ex.: "trm" encontra "Terminal").

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

fn is_subsequence(query: &str, text: &str) -> bool {
    let mut wanted = query.chars();
    let mut next = wanted.next();
    for c in text.chars() {
        if Some(c) == next {
            next = wanted.next();
        }
    }
    next.is_none()
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
    } else if title.contains(query) {
        Some(Rank::Substring)
    } else if is_subsequence(query, title) {
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
