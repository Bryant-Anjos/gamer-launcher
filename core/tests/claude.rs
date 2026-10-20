//! Integração com o Claude Code: só leitura, com dados sintéticos (nenhuma
//! conversa real). Todo campo é opcional; linha inválida é ignorada.

use launcher_core::claude::{
    agents::read_agents,
    cache::read_stats_cache,
    is_installed,
    sessions::SessionStatus,
    sessions::read_active_sessions,
    time::{day_of, day_to_date, parse_iso_ms},
    usage::UsageScanner,
};
use std::fs;
use std::path::Path;
use std::time::{Duration, SystemTime};
use tempfile::TempDir;

const DAY_MS: i64 = 86_400_000;
/// 2026-10-19T12:00:00Z
const NOON_19: i64 = 1_792_411_200_000;
const BRT: i32 = -180;

fn write(path: &Path, text: &str) {
    fs::create_dir_all(path.parent().unwrap()).unwrap();
    fs::write(path, text).unwrap();
}

fn assistant(session: &str, ts: &str, id: &str, model: &str, tools: usize) -> String {
    let blocks: Vec<String> = (0..tools)
        .map(|i| format!(r#"{{"type":"tool_use","id":"t{i}","name":"Bash","input":{{}}}}"#))
        .chain([r#"{"type":"text","text":"conteúdo que não deve ser lido"}"#.to_string()])
        .collect();
    format!(
        r#"{{"type":"assistant","sessionId":"{session}","timestamp":"{ts}","gitBranch":"main","message":{{"id":"{id}","model":"{model}","content":[{}],"usage":{{"input_tokens":10,"output_tokens":5,"cache_read_input_tokens":100,"cache_creation_input_tokens":1}}}}}}"#,
        blocks.join(",")
    )
}

mod time {
    use super::*;

    #[test]
    fn iso_timestamps_parse_to_epoch_millis() {
        assert_eq!(parse_iso_ms("2026-10-19T12:00:00Z"), Some(NOON_19));
        assert_eq!(
            parse_iso_ms("2026-10-19T12:00:00.250Z"),
            Some(NOON_19 + 250)
        );
        assert_eq!(parse_iso_ms("1970-01-01T00:00:00Z"), Some(0));
        assert_eq!(parse_iso_ms("ontem"), None);
        assert_eq!(parse_iso_ms("2026-13-40T99:00:00Z"), None);
    }

    #[test]
    fn days_follow_the_local_offset() {
        // 01:00 UTC do dia 20 ainda é dia 19 em Brasília
        let late = NOON_19 + 13 * 3_600_000;
        assert_eq!(day_of(late, BRT), day_of(NOON_19, BRT));
        assert_eq!(day_of(late, 0), day_of(NOON_19, 0) + 1);
        assert_eq!(day_to_date(day_of(NOON_19, BRT)), "2026-10-19");
    }
}

mod install {
    use super::*;

    #[test]
    fn installed_with_the_data_folder_or_the_program() {
        let dir = TempDir::new().unwrap();
        let root = dir.path().join(".claude");
        let bin = dir.path().join("bin");
        fs::create_dir_all(&bin).unwrap();

        assert!(!is_installed(&root, Some(bin.as_os_str())));
        write(&bin.join("claude"), "#!/bin/sh\n");
        assert!(is_installed(&root, Some(bin.as_os_str())));
        fs::remove_file(bin.join("claude")).unwrap();
        fs::create_dir_all(&root).unwrap();
        assert!(is_installed(&root, None));
    }
}

mod sessions {
    use super::*;

    fn registry(root: &Path, pid: u32, status: &str, name: &str) {
        write(
            &root.join(format!("sessions/{pid}.json")),
            &format!(
                r#"{{"pid":{pid},"sessionId":"s{pid}","cwd":"/home/u/dev/projeto-{pid}","startedAt":{start},"updatedAt":{upd},"status":"{status}","name":"{name}","version":"2.1.304","kind":"interactive"}}"#,
                start = NOON_19 - 3_600_000,
                upd = NOON_19 - 1_000,
            ),
        );
    }

    #[test]
    fn only_sessions_with_a_live_process_are_listed() {
        let dir = TempDir::new().unwrap();
        let root = dir.path();
        registry(root, 10, "busy", "Ajustar a tela");
        registry(root, 11, "idle", "Outra");
        write(&root.join("sessions/12.key"), "ignorar");

        let found = read_active_sessions(root, &|pid| pid == 10);

        assert_eq!(found.len(), 1);
        let s = &found[0];
        assert_eq!(s.session_id, "s10");
        assert_eq!(s.project, "projeto-10");
        assert_eq!(s.title.as_deref(), Some("Ajustar a tela"));
        assert_eq!(s.status, SessionStatus::Busy);
        assert_eq!(s.started_ms, Some(NOON_19 - 3_600_000));
        assert_eq!(s.version.as_deref(), Some("2.1.304"));
    }

    #[test]
    fn model_and_branch_come_from_the_end_of_the_transcript() {
        let dir = TempDir::new().unwrap();
        let root = dir.path();
        registry(root, 10, "idle", "x");
        let lines = [
            assistant("s10", "2026-10-19T11:00:00Z", "m1", "claude-old", 0),
            "linha quebrada {".to_string(),
            assistant("s10", "2026-10-19T11:59:00Z", "m2", "claude-opus-5", 1),
        ];
        write(
            &root.join("projects/-home-u-dev-projeto-10/s10.jsonl"),
            &(lines.join("\n") + "\n"),
        );

        let found = read_active_sessions(root, &|_| true);

        assert_eq!(found[0].model.as_deref(), Some("claude-opus-5"));
        assert_eq!(found[0].branch.as_deref(), Some("main"));
        assert_eq!(found[0].status, SessionStatus::Idle);
    }

    #[test]
    fn broken_or_unknown_registries_degrade_without_failing() {
        let dir = TempDir::new().unwrap();
        let root = dir.path();
        write(&root.join("sessions/1.json"), "não é json");
        write(
            &root.join("sessions/2.json"),
            r#"{"pid":2,"status":"novo-estado"}"#,
        );

        let found = read_active_sessions(root, &|_| true);

        assert_eq!(found.len(), 1);
        assert_eq!(found[0].status, SessionStatus::Other);
        assert_eq!(found[0].project, "");
        assert!(read_active_sessions(&root.join("nada"), &|_| true).is_empty());
    }

    #[test]
    fn long_titles_are_cut_short() {
        let dir = TempDir::new().unwrap();
        registry(dir.path(), 10, "busy", &"a".repeat(300));

        let found = read_active_sessions(dir.path(), &|_| true);

        assert!(found[0].title.as_ref().unwrap().chars().count() <= 81);
    }
}

mod agents {
    use super::*;

    fn agent(dir: &Path, id: &str, kind: &str, description: &str, age: Duration) {
        write(
            &dir.join(format!("agent-{id}.meta.json")),
            &format!(r#"{{"agentType":"{kind}","description":"{description}","model":"sonnet"}}"#),
        );
        let log = dir.join(format!("agent-{id}.jsonl"));
        write(&log, "{}\n");
        let when = SystemTime::now() - age;
        fs::File::options()
            .write(true)
            .open(&log)
            .unwrap()
            .set_modified(when)
            .unwrap();
    }

    #[test]
    fn running_agents_come_first_with_type_and_description() {
        let dir = TempDir::new().unwrap();
        let subagents = dir.path().join("subagents");
        agent(
            &subagents,
            "a1",
            "Explore",
            "Achar o leitor",
            Duration::from_secs(3600),
        );
        agent(
            &subagents,
            "a2",
            "general-purpose",
            "Revisar a tela",
            Duration::from_secs(5),
        );
        write(&subagents.join("agent-a3.meta.json"), "quebrado");

        let found = read_agents(dir.path(), SystemTime::now(), Duration::from_secs(90));

        assert_eq!(found.len(), 2);
        assert_eq!(found[0].description, "Revisar a tela");
        assert!(found[0].running);
        assert_eq!(found[0].agent_type, "general-purpose");
        assert!(!found[1].running);
        assert_eq!(found[1].model.as_deref(), Some("sonnet"));
    }

    #[test]
    fn a_session_without_agents_has_none() {
        let dir = TempDir::new().unwrap();
        assert!(read_agents(dir.path(), SystemTime::now(), Duration::from_secs(90)).is_empty());
    }
}

mod usage {
    use super::*;

    fn transcript(root: &Path, name: &str, lines: &[String]) -> std::path::PathBuf {
        let path = root.join(format!("projects/-p/{name}.jsonl"));
        write(&path, &(lines.join("\n") + "\n"));
        path
    }

    #[test]
    fn today_counts_replies_tools_tokens_and_sessions() {
        let dir = TempDir::new().unwrap();
        let root = dir.path();
        transcript(
            root,
            "s1",
            &[
                assistant("s1", "2026-10-19T11:00:00Z", "m1", "opus", 2),
                // a mesma resposta dividida em duas linhas: conta uma vez
                assistant("s1", "2026-10-19T11:00:01Z", "m1", "opus", 1),
                assistant("s2", "2026-10-19T11:30:00Z", "m2", "sonnet", 0),
                r#"{"type":"user","sessionId":"s1","timestamp":"2026-10-19T11:00:00Z","message":{"content":"segredo"}}"#.to_string(),
                "{lixo".to_string(),
                assistant("s1", "2026-10-17T11:00:00Z", "m0", "opus", 4),
            ],
        );
        let mut scanner = UsageScanner::default();

        scanner.scan(root, NOON_19, BRT, u64::MAX);
        let summary = scanner.summary(NOON_19, BRT);

        assert_eq!(summary.today.replies, 2);
        assert_eq!(summary.today.tool_calls, 3);
        assert_eq!(summary.today.sessions, 2);
        assert_eq!(summary.today.output_tokens, 10);
        assert_eq!(summary.today.input_tokens, 2 * (10 + 100 + 1));
        assert_eq!(summary.week.replies, 3);
        assert_eq!(summary.week.tool_calls, 7);
        let models: Vec<_> = summary
            .today_models
            .iter()
            .map(|m| m.model.as_str())
            .collect();
        assert_eq!(models, ["opus", "sonnet"]);
        assert_eq!(summary.days.len(), 7);
        assert_eq!(summary.days.last().unwrap().date, "2026-10-19");
        assert_eq!(summary.days.last().unwrap().sessions, 2);
    }

    #[test]
    fn only_new_lines_are_read_on_the_next_scan() {
        let dir = TempDir::new().unwrap();
        let root = dir.path();
        let path = transcript(
            root,
            "s1",
            &[assistant("s1", "2026-10-19T11:00:00Z", "m1", "opus", 1)],
        );
        let mut scanner = UsageScanner::default();
        let first = scanner.scan(root, NOON_19, BRT, u64::MAX);

        let mut text = fs::read_to_string(&path).unwrap();
        text.push_str(&assistant("s1", "2026-10-19T11:05:00Z", "m2", "opus", 1));
        text.push('\n');
        // linha pela metade (ainda sendo escrita) espera o próximo ciclo
        text.push_str(r#"{"type":"assistant","sessionId":"s1""#);
        fs::write(&path, text).unwrap();
        let second = scanner.scan(root, NOON_19, BRT, u64::MAX);

        assert!(second < first * 3, "releu tudo: {first} e depois {second}");
        assert_eq!(scanner.summary(NOON_19, BRT).today.replies, 2);
    }

    #[test]
    fn the_byte_budget_spreads_a_big_file_over_several_scans() {
        let dir = TempDir::new().unwrap();
        let root = dir.path();
        let lines: Vec<String> = (0..50)
            .map(|i| assistant("s1", "2026-10-19T11:00:00Z", &format!("m{i}"), "opus", 0))
            .collect();
        transcript(root, "s1", &lines);
        let mut scanner = UsageScanner::default();

        scanner.scan(root, NOON_19, BRT, 2_000);
        let partial = scanner.summary(NOON_19, BRT).today.replies;
        for _ in 0..50 {
            scanner.scan(root, NOON_19, BRT, 2_000);
        }

        assert!(partial > 0 && partial < 50, "parcial: {partial}");
        assert_eq!(scanner.summary(NOON_19, BRT).today.replies, 50);
    }

    #[test]
    fn subagent_transcripts_count_too() {
        let dir = TempDir::new().unwrap();
        let root = dir.path();
        write(
            &root.join("projects/-p/s1/subagents/agent-a.jsonl"),
            &(assistant("s1", "2026-10-19T11:00:00Z", "sub1", "haiku", 1) + "\n"),
        );
        let mut scanner = UsageScanner::default();

        scanner.scan(root, NOON_19, BRT, u64::MAX);

        assert_eq!(scanner.summary(NOON_19, BRT).today.replies, 1);
    }

    #[test]
    fn old_days_fall_out_of_the_week() {
        let dir = TempDir::new().unwrap();
        let root = dir.path();
        transcript(
            root,
            "s1",
            &[assistant("s1", "2026-10-01T11:00:00Z", "m1", "opus", 1)],
        );
        let mut scanner = UsageScanner::default();

        scanner.scan(root, NOON_19, BRT, u64::MAX);
        let summary = scanner.summary(NOON_19 + DAY_MS, BRT);

        assert_eq!(summary.week.replies, 0);
    }
}

mod cache {
    use super::*;

    #[test]
    fn totals_and_daily_activity_come_from_the_stats_cache() {
        let dir = TempDir::new().unwrap();
        write(
            &dir.path().join("stats-cache.json"),
            r#"{"version":5,"lastComputedDate":"2026-10-13","totalSessions":40,"totalMessages":900,"firstSessionDate":"2026-06-01T10:00:00Z",
               "dailyActivity":[{"date":"2026-10-12","messageCount":30,"sessionCount":2,"toolCallCount":9}],
               "modelUsage":{"claude-opus-5":{"inputTokens":5,"outputTokens":7,"cacheReadInputTokens":11,"cacheCreationInputTokens":13,"costUSD":1.5}}}"#,
        );

        let cache = read_stats_cache(dir.path()).unwrap();

        assert_eq!(cache.total_sessions, Some(40));
        assert_eq!(cache.total_messages, Some(900));
        assert_eq!(cache.last_computed_date.as_deref(), Some("2026-10-13"));
        assert_eq!(cache.daily[0].sessions, 2);
        assert_eq!(cache.models[0].model, "claude-opus-5");
        assert_eq!(cache.models[0].output_tokens, 7);
        assert_eq!(cache.models[0].input_tokens, 5 + 11 + 13);
    }

    #[test]
    fn a_missing_or_strange_cache_gives_nothing() {
        let dir = TempDir::new().unwrap();
        assert!(read_stats_cache(dir.path()).is_none());
        write(
            &dir.path().join("stats-cache.json"),
            r#"{"version":99,"totalSessions":"muitas"}"#,
        );
        let cache = read_stats_cache(dir.path()).unwrap();
        assert_eq!(cache.total_sessions, None);
    }
}
