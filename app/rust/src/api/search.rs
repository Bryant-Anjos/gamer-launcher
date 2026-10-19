use crate::convert::{friendly_io_error, search_result};
use crate::store;
use launcher_core::catalog::build_catalog;
use launcher_core::open::{OpenTarget, Opener};
use launcher_core::paths::default_recents_path;
use launcher_core::recents::load_recents;
use launcher_core::search::{search, SearchItem};

/// Quantos recentes entram na pesquisa.
const SEARCH_RECENTS_LIMIT: usize = 200;

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum SearchKind {
    App,
    File,
    Setting,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct SearchResult {
    pub kind: SearchKind,
    pub id: String,
    pub title: String,
    pub subtitle: Option<String>,
    /// Id do app, quando o resultado é um app (para o ícone).
    pub app_id: Option<String>,
}

/// Lê os recentes uma vez, ao abrir a pesquisa (não a cada tecla).
pub fn prepare_search() -> Result<(), String> {
    let path =
        default_recents_path().ok_or_else(|| "sem pasta de dados (HOME ausente)".to_string())?;
    let recents = load_recents(&path, SEARCH_RECENTS_LIMIT).map_err(|error| error.to_string())?;
    *store::search_recents() = recents;
    Ok(())
}

fn items() -> Vec<SearchItem> {
    build_catalog(&store::apps(), &store::search_recents())
}

/// Apps (da última leitura do catálogo), recentes e páginas de configurações.
pub fn search_all(query: String, limit: u32) -> Vec<SearchResult> {
    search(&items(), &query, limit as usize)
        .iter()
        .map(search_result)
        .collect()
}

/// Abre um resultado pelo id; só ids produzidos pelo catálogo são aceitos.
pub fn open_search_result(id: String) -> Result<(), String> {
    let item = items()
        .into_iter()
        .find(|item| item.id == id)
        .ok_or_else(|| "esse resultado não existe mais".to_string())?;
    let target = OpenTarget::from_item(&item).map_err(|error| error.to_string())?;
    Opener::system()
        .open(&target, &store::apps())
        .map_err(|error| friendly_io_error(&std::io::Error::other(error.to_string())))
}
