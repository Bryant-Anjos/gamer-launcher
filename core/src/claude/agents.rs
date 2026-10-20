//! Subagentes de uma sessão: `<sessão>/subagents/agent-*.meta.json` (tipo,
//! descrição curta e modelo) e o transcrito de cada um, cuja última mudança
//! diz se ainda trabalha.

use super::shorten;
use serde::Deserialize;
use std::fs;
use std::path::Path;
use std::time::{Duration, SystemTime};

const DESCRIPTION_LIMIT: usize = 120;
/// Os mais recentes bastam para a tela.
const MAX_AGENTS: usize = 20;
const META_SUFFIX: &str = ".meta.json";

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct Agent {
    pub agent_type: String,
    pub description: String,
    pub model: Option<String>,
    pub running: bool,
    /// Última atividade, em ms desde 1970 (para ordenar e mostrar "há x").
    pub last_activity_ms: Option<i64>,
}

#[derive(Deserialize, Default)]
#[serde(rename_all = "camelCase", default)]
struct Meta {
    agent_type: Option<String>,
    description: Option<String>,
    model: Option<String>,
}

fn millis(time: SystemTime) -> Option<i64> {
    let since = time.duration_since(SystemTime::UNIX_EPOCH).ok()?;
    i64::try_from(since.as_millis()).ok()
}

fn read_agent(meta_path: &Path, now: SystemTime, window: Duration) -> Option<Agent> {
    let meta: Meta = serde_json::from_str(&fs::read_to_string(meta_path).ok()?).ok()?;
    let name = meta_path.file_name()?.to_str()?.strip_suffix(META_SUFFIX)?;
    let log = meta_path.with_file_name(format!("{name}.jsonl"));
    let modified = fs::metadata(log).and_then(|m| m.modified()).ok();
    let running = modified
        .and_then(|time| now.duration_since(time).ok())
        .is_some_and(|age| age <= window);
    Some(Agent {
        agent_type: meta.agent_type.unwrap_or_default(),
        description: shorten(&meta.description.unwrap_or_default(), DESCRIPTION_LIMIT),
        model: meta.model,
        running,
        last_activity_ms: modified.and_then(millis),
    })
}

/// Trabalhando primeiro, depois os mais recentes. Sem a pasta, nenhum.
pub fn read_agents(session_dir: &Path, now: SystemTime, window: Duration) -> Vec<Agent> {
    let Ok(entries) = fs::read_dir(session_dir.join("subagents")) else {
        return Vec::new();
    };
    let mut agents: Vec<Agent> = entries
        .flatten()
        .map(|entry| entry.path())
        .filter(|path| path.to_string_lossy().ends_with(META_SUFFIX))
        .filter_map(|path| read_agent(&path, now, window))
        .collect();
    agents.sort_by(|a, b| {
        b.running
            .cmp(&a.running)
            .then(b.last_activity_ms.cmp(&a.last_activity_ms))
    });
    agents.truncate(MAX_AGENTS);
    agents
}
