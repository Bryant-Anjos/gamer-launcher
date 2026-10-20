//! Mede a leitura do Claude Code numa pasta real, mostrando só números:
//! `cargo run --release --example claude_scan [pasta]`.

use launcher_core::claude::sessions::{pid_is_alive, read_active_sessions};
use launcher_core::claude::usage::UsageScanner;
use std::path::PathBuf;
use std::time::{Instant, SystemTime, UNIX_EPOCH};

/// Orçamento por ciclo usado pela ponte.
const BUDGET: u64 = 32 * 1024 * 1024;

fn main() {
    let root = std::env::args()
        .nth(1)
        .map(PathBuf::from)
        .unwrap_or_else(|| PathBuf::from(std::env::var("HOME").expect("HOME")).join(".claude"));
    let now = SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .unwrap()
        .as_millis() as i64;
    let started = Instant::now();
    let sessions = read_active_sessions(&root, &pid_is_alive);
    println!(
        "sessões ativas: {} em {:?}",
        sessions.len(),
        started.elapsed()
    );
    let mut scanner = UsageScanner::default();
    for cycle in 1..=10 {
        let started = Instant::now();
        let read = scanner.scan(&root, now, -180, BUDGET);
        println!(
            "ciclo {cycle}: {:.1} MB em {:?}",
            read as f64 / 1e6,
            started.elapsed()
        );
        if read == 0 {
            break;
        }
    }
    let summary = scanner.summary(now, -180);
    println!(
        "hoje: {} respostas, {} ferramentas, {} sessões; semana: {} respostas",
        summary.today.replies,
        summary.today.tool_calls,
        summary.today.sessions,
        summary.week.replies
    );
}
