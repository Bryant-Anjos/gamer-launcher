use crate::convert::{build_catalog, friendly_io_error};
use crate::store;
use launcher_core::apps::{default_app_dirs, discover_apps, find_app, launch};
use launcher_core::history::LaunchHistory;
use launcher_core::icons::default_icon_dirs;
use launcher_core::paths::default_history_path;

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct AppInfo {
    pub id: String,
    pub name: String,
    /// Arquivo de ícone já localizado (svg, png ou jpg), se houver.
    pub icon_path: Option<String>,
    pub categories: Vec<String>,
}

/// Tudo o que a UI precisa sobre apps, numa leitura só.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct AppCatalog {
    pub apps: Vec<AppInfo>,
    /// Steam, Heroic e Lutris instalados, nessa ordem.
    pub game_launcher_ids: Vec<String>,
    pub music_player_id: Option<String>,
    /// Último app aberto pelo launcher, se ainda estiver instalado.
    pub last_app_id: Option<String>,
    /// Problemas que não impedem o uso (ex.: histórico ilegível).
    pub warnings: Vec<String>,
}

fn history_path() -> Result<std::path::PathBuf, String> {
    default_history_path().ok_or_else(|| "sem pasta de estado (HOME ausente)".to_string())
}

/// Lê os `.desktop`, localiza os ícones e o histórico. Roda fora da thread
/// da UI (função assíncrona da ponte).
pub fn load_catalog() -> AppCatalog {
    let apps = discover_apps(&default_app_dirs());
    let (roots, pixmaps) = default_icon_dirs();
    let history = history_path()
        .and_then(|path| LaunchHistory::load(&path).map_err(|error| error.to_string()));
    let catalog = build_catalog(&apps, &roots, &pixmaps, history);
    *store::apps() = apps;
    catalog
}

/// Abre o app e registra no histórico. `Ok(Some(aviso))` quando o app
/// abriu mas o histórico não pôde ser gravado.
pub fn launch_app(id: String) -> Result<Option<String>, String> {
    let app = find_app(&store::apps(), &id)
        .cloned()
        .ok_or_else(|| format!("o app {id} não foi encontrado"))?;
    launch(&app).map_err(|error| friendly_io_error(&error))?;
    let recorded = history_path().and_then(|path| {
        // histórico ilegível é substituído: o app novo passa a ser o último
        let history = LaunchHistory::load(&path).unwrap_or_default();
        history
            .with_launch(&id)
            .save(&path)
            .map_err(|error| error.to_string())
    });
    Ok(recorded.err())
}
