use super::claude::*;
use crate::api::claude::ClaudeSessionStatus;
use launcher_core::claude::agents::Agent;
use launcher_core::claude::cache::{CachedDay, CachedModel, StatsCache};
use launcher_core::claude::sessions::{ActiveSession, SessionStatus};
use launcher_core::claude::usage::{DayPoint, ModelTokens, Totals, UsageSummary};

fn session(status: SessionStatus) -> ActiveSession {
    ActiveSession {
        session_id: "s1".into(),
        project: "gamer-launcher".into(),
        title: Some("Ajustar a tela".into()),
        status,
        started_ms: Some(1),
        updated_ms: Some(2),
        version: Some("2.1.304".into()),
        model: Some("claude-opus-5".into()),
        branch: Some("main".into()),
        agents: vec![Agent {
            agent_type: "Explore".into(),
            description: "Achar o leitor".into(),
            model: None,
            running: true,
            last_activity_ms: Some(3),
        }],
    }
}

#[test]
fn sessions_keep_metadata_and_agents() {
    let now = claude_now_dto(&[session(SessionStatus::Busy), session(SessionStatus::Other)]);

    assert_eq!(now.version.as_deref(), Some("2.1.304"));
    let first = &now.sessions[0];
    assert_eq!(first.project, "gamer-launcher");
    assert_eq!(first.status, ClaudeSessionStatus::Busy);
    assert_eq!(now.sessions[1].status, ClaudeSessionStatus::Other);
    assert_eq!(first.agents[0].agent_type, "Explore");
    assert!(first.agents[0].running);
}

#[test]
fn without_sessions_there_is_no_version() {
    assert_eq!(claude_now_dto(&[]).version, None);
}

#[test]
fn stats_join_the_scan_and_the_cache_history() {
    let usage = UsageSummary {
        today: Totals {
            replies: 3,
            tool_calls: 4,
            sessions: 1,
            input_tokens: 500,
            output_tokens: 60,
        },
        week: Totals::default(),
        today_models: vec![ModelTokens {
            model: "opus".into(),
            input_tokens: 500,
            output_tokens: 60,
        }],
        days: vec![DayPoint {
            date: "2026-10-19".into(),
            sessions: 1,
            replies: 3,
        }],
    };
    let cache = StatsCache {
        last_computed_date: Some("2026-10-13".into()),
        first_session_date: Some("2026-06-01T10:00:00Z".into()),
        total_sessions: Some(40),
        total_messages: Some(900),
        daily: vec![CachedDay {
            date: "2026-10-12".into(),
            sessions: 2,
            messages: 30,
            tool_calls: 9,
        }],
        models: vec![CachedModel {
            model: "opus".into(),
            input_tokens: 10,
            output_tokens: 20,
        }],
    };

    let stats = claude_stats_dto(&usage, Some(&cache));

    assert_eq!(stats.today.replies, 3.0);
    assert_eq!(stats.today.input_tokens, 500.0);
    assert_eq!(stats.today_models[0].model, "opus");
    assert_eq!(stats.days[0].date, "2026-10-19");
    let history = stats.history.unwrap();
    assert_eq!(history.since.as_deref(), Some("2026-06-01"));
    assert_eq!(history.until.as_deref(), Some("2026-10-13"));
    assert_eq!(history.sessions, Some(40.0));
    assert_eq!(history.models[0].output_tokens, 20.0);
    assert!(claude_stats_dto(&usage, None).history.is_none());
}
