//! `stats-cache.json`: totais e atividade por dia que o próprio Claude
//! calcula de tempos em tempos (pode estar dias atrasado: [`StatsCache::last_computed_date`]).

use super::fields::{count, int, text};
use serde_json::Value;
use std::fs;
use std::path::Path;

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct CachedDay {
    pub date: String,
    pub sessions: u64,
    pub messages: u64,
    pub tool_calls: u64,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct CachedModel {
    pub model: String,
    /// Entrada somada à lida e à criada no cache.
    pub input_tokens: u64,
    pub output_tokens: u64,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct StatsCache {
    pub last_computed_date: Option<String>,
    pub first_session_date: Option<String>,
    pub total_sessions: Option<i64>,
    pub total_messages: Option<i64>,
    pub daily: Vec<CachedDay>,
    pub models: Vec<CachedModel>,
}

fn day(value: &Value) -> Option<CachedDay> {
    Some(CachedDay {
        date: text(value, "date")?,
        sessions: count(value, "sessionCount"),
        messages: count(value, "messageCount"),
        tool_calls: count(value, "toolCallCount"),
    })
}

fn model(name: &str, value: &Value) -> CachedModel {
    CachedModel {
        model: name.to_string(),
        input_tokens: count(value, "inputTokens")
            + count(value, "cacheReadInputTokens")
            + count(value, "cacheCreationInputTokens"),
        output_tokens: count(value, "outputTokens"),
    }
}

/// `None` sem o arquivo ou com um que não é JSON; campos estranhos só faltam.
pub fn read_stats_cache(root: &Path) -> Option<StatsCache> {
    let raw = fs::read_to_string(root.join("stats-cache.json")).ok()?;
    let value: Value = serde_json::from_str(&raw).ok()?;
    let daily = value
        .get("dailyActivity")
        .and_then(Value::as_array)
        .map(|days| days.iter().filter_map(day).collect())
        .unwrap_or_default();
    let models = value
        .get("modelUsage")
        .and_then(Value::as_object)
        .map(|models| models.iter().map(|(name, v)| model(name, v)).collect())
        .unwrap_or_default();
    Some(StatsCache {
        last_computed_date: text(&value, "lastComputedDate"),
        first_session_date: text(&value, "firstSessionDate"),
        total_sessions: int(&value, "totalSessions"),
        total_messages: int(&value, "totalMessages"),
        daily,
        models,
    })
}
