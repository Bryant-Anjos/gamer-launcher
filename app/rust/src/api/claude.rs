//! Acompanhamento do Claude Code, **só leitura**: sessões abertas, agentes e
//! uso. Nada aqui falha: o formato do Claude muda sem aviso, então o que não
//! dá para ler simplesmente não aparece.

use crate::convert::claude::{claude_now_dto, claude_stats_dto};
use crate::store;
use flutter_rust_bridge::frb;
use launcher_core::claude::cache::read_stats_cache;
use launcher_core::claude::sessions::{pid_is_alive, read_active_sessions};
use launcher_core::claude::{default_root, is_installed};
use launcher_core::paths::home_dir;
use std::path::PathBuf;

/// Bytes lidos dos transcritos por chamada; o resto fica para a próxima.
const SCAN_BUDGET: u64 = 32 * 1024 * 1024;

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum ClaudeSessionStatus {
    Busy,
    Idle,
    Other,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct ClaudeAgent {
    pub agent_type: String,
    pub description: String,
    pub model: Option<String>,
    pub running: bool,
    pub last_activity_ms: Option<i64>,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct ClaudeSession {
    pub session_id: String,
    /// Só o nome da pasta do projeto.
    pub project: String,
    pub title: Option<String>,
    pub status: ClaudeSessionStatus,
    pub started_ms: Option<i64>,
    pub updated_ms: Option<i64>,
    pub model: Option<String>,
    pub branch: Option<String>,
    pub agents: Vec<ClaudeAgent>,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct ClaudeNow {
    pub sessions: Vec<ClaudeSession>,
    pub version: Option<String>,
}

/// Contagens como `f64` (o `u64` viraria `BigInt` no Dart).
#[derive(Debug, Clone, PartialEq)]
pub struct ClaudeTotals {
    pub replies: f64,
    pub tool_calls: f64,
    pub sessions: f64,
    pub input_tokens: f64,
    pub output_tokens: f64,
}

#[derive(Debug, Clone, PartialEq)]
pub struct ClaudeModelTokens {
    pub model: String,
    pub input_tokens: f64,
    pub output_tokens: f64,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct ClaudeDayPoint {
    pub date: String,
    pub sessions: u32,
    pub replies: u32,
}

/// Totais do cache do próprio Claude (de [since] até [until]).
#[derive(Debug, Clone, PartialEq)]
pub struct ClaudeHistory {
    pub since: Option<String>,
    pub until: Option<String>,
    pub sessions: Option<f64>,
    pub messages: Option<f64>,
    pub models: Vec<ClaudeModelTokens>,
}

#[derive(Debug, Clone, PartialEq)]
pub struct ClaudeStats {
    pub today: ClaudeTotals,
    pub week: ClaudeTotals,
    pub today_models: Vec<ClaudeModelTokens>,
    /// Um ponto por dia dos últimos 7, do mais antigo para hoje.
    pub days: Vec<ClaudeDayPoint>,
    pub history: Option<ClaudeHistory>,
}

fn root() -> Option<PathBuf> {
    home_dir().map(|home| default_root(&home))
}

/// Há Claude Code nesta máquina? Só confere se a pasta ou o programa existem.
#[frb(sync)]
pub fn claude_installed() -> bool {
    root().is_some_and(|root| is_installed(&root, std::env::var_os("PATH").as_deref()))
}

/// Sessões abertas agora, com modelo, branch e subagentes.
pub fn claude_now() -> ClaudeNow {
    let sessions = root()
        .map(|root| read_active_sessions(&root, &pid_is_alive))
        .unwrap_or_default();
    claude_now_dto(&sessions)
}

/// Uso de hoje e da semana (lido aos poucos) e o histórico do cache.
pub fn claude_stats(now_ms: i64, utc_offset_minutes: i32) -> ClaudeStats {
    let Some(root) = root() else {
        return claude_stats_dto(&Default::default(), None);
    };
    let mut scanner = store::claude_usage();
    scanner.scan(&root, now_ms, utc_offset_minutes, SCAN_BUDGET);
    let summary = scanner.summary(now_ms, utc_offset_minutes);
    drop(scanner);
    claude_stats_dto(&summary, read_stats_cache(&root).as_ref())
}
