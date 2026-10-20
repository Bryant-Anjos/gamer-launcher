//! Do núcleo do Claude para os tipos da ponte.

use crate::api::claude::{
    ClaudeAgent, ClaudeDayPoint, ClaudeHistory, ClaudeModelTokens, ClaudeNow, ClaudeSession,
    ClaudeSessionStatus, ClaudeStats, ClaudeTotals,
};
use launcher_core::claude::agents::Agent;
use launcher_core::claude::cache::StatsCache;
use launcher_core::claude::sessions::{ActiveSession, SessionStatus};
use launcher_core::claude::usage::{Totals, UsageSummary};

/// Só a data de um horário ISO (`AAAA-MM-DD`).
const DATE_LEN: usize = 10;

fn status(status: SessionStatus) -> ClaudeSessionStatus {
    match status {
        SessionStatus::Busy => ClaudeSessionStatus::Busy,
        SessionStatus::Idle => ClaudeSessionStatus::Idle,
        SessionStatus::Other => ClaudeSessionStatus::Other,
    }
}

fn agent(agent: &Agent) -> ClaudeAgent {
    ClaudeAgent {
        agent_type: agent.agent_type.clone(),
        description: agent.description.clone(),
        model: agent.model.clone(),
        running: agent.running,
        last_activity_ms: agent.last_activity_ms,
    }
}

fn session(session: &ActiveSession) -> ClaudeSession {
    ClaudeSession {
        session_id: session.session_id.clone(),
        project: session.project.clone(),
        title: session.title.clone(),
        status: status(session.status),
        started_ms: session.started_ms,
        updated_ms: session.updated_ms,
        model: session.model.clone(),
        branch: session.branch.clone(),
        agents: session.agents.iter().map(agent).collect(),
    }
}

pub fn claude_now_dto(sessions: &[ActiveSession]) -> ClaudeNow {
    ClaudeNow {
        version: sessions.iter().find_map(|s| s.version.clone()),
        sessions: sessions.iter().map(session).collect(),
    }
}

fn totals(totals: &Totals) -> ClaudeTotals {
    ClaudeTotals {
        replies: totals.replies as f64,
        tool_calls: totals.tool_calls as f64,
        sessions: totals.sessions as f64,
        input_tokens: totals.input_tokens as f64,
        output_tokens: totals.output_tokens as f64,
    }
}

fn model(model: &str, input: u64, output: u64) -> ClaudeModelTokens {
    ClaudeModelTokens {
        model: model.to_string(),
        input_tokens: input as f64,
        output_tokens: output as f64,
    }
}

fn history(cache: &StatsCache) -> ClaudeHistory {
    ClaudeHistory {
        since: cache
            .first_session_date
            .as_ref()
            .map(|date| date.chars().take(DATE_LEN).collect()),
        until: cache.last_computed_date.clone(),
        sessions: cache.total_sessions.map(|n| n as f64),
        messages: cache.total_messages.map(|n| n as f64),
        models: cache
            .models
            .iter()
            .map(|m| model(&m.model, m.input_tokens, m.output_tokens))
            .collect(),
    }
}

pub fn claude_stats_dto(usage: &UsageSummary, cache: Option<&StatsCache>) -> ClaudeStats {
    ClaudeStats {
        today: totals(&usage.today),
        week: totals(&usage.week),
        today_models: usage
            .today_models
            .iter()
            .map(|m| model(&m.model, m.input_tokens, m.output_tokens))
            .collect(),
        days: usage
            .days
            .iter()
            .map(|day| ClaudeDayPoint {
                date: day.date.clone(),
                sessions: u32::try_from(day.sessions).unwrap_or(u32::MAX),
                replies: u32::try_from(day.replies).unwrap_or(u32::MAX),
            })
            .collect(),
        history: cache.map(history),
    }
}
