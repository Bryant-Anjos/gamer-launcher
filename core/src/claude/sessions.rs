//! Sessões abertas agora: o registro `sessions/<pid>.json` que o Claude
//! mantém por processo, conferido contra os processos vivos.

use super::agents::{Agent, read_agents};
use super::fields::{int, text};
use super::shorten;
use serde::Deserialize;
use serde_json::Value;
use std::fs::{self, File};
use std::io::{Read, Seek, SeekFrom};
use std::path::{Path, PathBuf};
use std::time::{Duration, SystemTime};

/// Só o fim do transcrito é lido para achar modelo e branch.
const TAIL_BYTES: u64 = 256 * 1024;
const TITLE_LIMIT: usize = 80;
/// Subagente com o transcrito mexido há menos que isso está trabalhando.
pub const AGENT_ACTIVE_WINDOW: Duration = Duration::from_secs(90);

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum SessionStatus {
    Busy,
    Idle,
    /// Estado que esta versão não conhece.
    Other,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct ActiveSession {
    pub session_id: String,
    /// Só o nome da pasta do projeto, nunca o caminho inteiro.
    pub project: String,
    pub title: Option<String>,
    pub status: SessionStatus,
    pub started_ms: Option<i64>,
    pub updated_ms: Option<i64>,
    pub version: Option<String>,
    pub model: Option<String>,
    pub branch: Option<String>,
    pub agents: Vec<Agent>,
}

struct Registry {
    pid: Option<u32>,
    session_id: Option<String>,
    cwd: Option<String>,
    started_at: Option<i64>,
    updated_at: Option<i64>,
    status: Option<String>,
    name: Option<String>,
    version: Option<String>,
}

impl Registry {
    fn from_json(value: &Value) -> Self {
        Self {
            pid: int(value, "pid").and_then(|pid| u32::try_from(pid).ok()),
            session_id: text(value, "sessionId"),
            cwd: text(value, "cwd"),
            started_at: int(value, "startedAt"),
            updated_at: int(value, "updatedAt"),
            status: text(value, "status"),
            name: text(value, "name"),
            version: text(value, "version"),
        }
    }
}

fn status_of(raw: Option<&str>) -> SessionStatus {
    match raw {
        Some("busy") => SessionStatus::Busy,
        Some("idle") => SessionStatus::Idle,
        _ => SessionStatus::Other,
    }
}

fn project_of(cwd: Option<&str>) -> String {
    cwd.and_then(|path| Path::new(path).file_name())
        .map(|name| name.to_string_lossy().into_owned())
        .unwrap_or_default()
}

fn registries(root: &Path) -> Vec<Registry> {
    let Ok(entries) = fs::read_dir(root.join("sessions")) else {
        return Vec::new();
    };
    entries
        .flatten()
        .map(|entry| entry.path())
        .filter(|path| path.extension().is_some_and(|ext| ext == "json"))
        .filter_map(|path| fs::read_to_string(path).ok())
        .filter_map(|raw| serde_json::from_str::<Value>(&raw).ok())
        .map(|value| Registry::from_json(&value))
        .collect()
}

/// Pasta e transcrito da sessão (`projects/<projeto>/<id>.jsonl`).
fn transcript_of(root: &Path, session_id: &str) -> Option<PathBuf> {
    let file = format!("{session_id}.jsonl");
    fs::read_dir(root.join("projects"))
        .ok()?
        .flatten()
        .map(|entry| entry.path().join(&file))
        .find(|path| path.is_file())
}

fn read_tail(path: &Path) -> Option<String> {
    let mut file = File::open(path).ok()?;
    let len = file.metadata().ok()?.len();
    file.seek(SeekFrom::Start(len.saturating_sub(TAIL_BYTES)))
        .ok()?;
    let mut bytes = Vec::new();
    file.read_to_end(&mut bytes).ok()?;
    Some(String::from_utf8_lossy(&bytes).into_owned())
}

#[derive(Deserialize, Default)]
#[serde(default)]
struct TailMessage {
    model: Option<String>,
}

#[derive(Deserialize, Default)]
#[serde(rename_all = "camelCase", default)]
struct TailLine {
    git_branch: Option<String>,
    message: Option<TailMessage>,
}

/// Modelo e branch mais recentes (do fim para o começo do transcrito).
fn model_and_branch(path: &Path) -> (Option<String>, Option<String>) {
    let Some(tail) = read_tail(path) else {
        return (None, None);
    };
    let (mut model, mut branch) = (None, None);
    for line in tail.lines().rev() {
        if model.is_some() && branch.is_some() {
            break;
        }
        if !line.contains("\"gitBranch\"") && !line.contains("\"model\"") {
            continue;
        }
        let Ok(parsed) = serde_json::from_str::<TailLine>(line) else {
            continue;
        };
        branch = branch.or(parsed.git_branch.filter(|b| !b.is_empty()));
        model = model.or(parsed.message.and_then(|m| m.model));
    }
    (model, branch)
}

fn to_session(root: &Path, registry: Registry) -> ActiveSession {
    let session_id = registry.session_id.unwrap_or_default();
    let transcript = transcript_of(root, &session_id);
    let (model, branch) = transcript.as_deref().map_or((None, None), model_and_branch);
    let agents = transcript
        .as_deref()
        .map(|path| path.with_extension(""))
        .map(|dir| read_agents(&dir, SystemTime::now(), AGENT_ACTIVE_WINDOW))
        .unwrap_or_default();
    ActiveSession {
        project: project_of(registry.cwd.as_deref()),
        title: registry
            .name
            .filter(|name| !name.trim().is_empty())
            .map(|name| shorten(&name, TITLE_LIMIT)),
        status: status_of(registry.status.as_deref()),
        started_ms: registry.started_at,
        updated_ms: registry.updated_at,
        version: registry.version,
        model,
        branch,
        agents,
        session_id,
    }
}

/// Sessões com o processo vivo ([is_alive] recebe o pid), as mais recentes
/// primeiro. Sem a pasta, nenhuma.
pub fn read_active_sessions(root: &Path, is_alive: &dyn Fn(u32) -> bool) -> Vec<ActiveSession> {
    let mut sessions: Vec<ActiveSession> = registries(root)
        .into_iter()
        .filter(|registry| registry.pid.is_some_and(is_alive))
        .map(|registry| to_session(root, registry))
        .collect();
    sessions.sort_by_key(|session| std::cmp::Reverse(session.updated_ms));
    sessions
}

/// Processo vivo no Linux: existe `/proc/<pid>`.
pub fn pid_is_alive(pid: u32) -> bool {
    Path::new("/proc").join(pid.to_string()).exists()
}
