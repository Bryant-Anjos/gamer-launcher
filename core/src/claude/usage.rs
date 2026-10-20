//! Uso dos últimos dias (respostas, chamadas de ferramenta, tokens por
//! modelo, sessões), lido dos transcritos de forma **incremental**: cada
//! arquivo guarda até onde foi lido e só as linhas novas são processadas,
//! com um limite de bytes por leitura. Só as respostas do assistente são
//! abertas, e delas só os metadados (modelo, uso, tipos dos blocos).

use super::time::{day_of, day_to_date, parse_iso_ms};
use serde::Deserialize;
use std::collections::{BTreeMap, BTreeSet, HashMap};
use std::fs::{self, File};
use std::io::{Read, Seek, SeekFrom};
use std::path::{Path, PathBuf};
use std::time::{Duration, SystemTime};

/// Dias guardados (hoje e os seis anteriores).
pub const WEEK_DAYS: i64 = 7;
/// Transcritos parados há mais que isso não têm nada da semana.
const FILE_WINDOW: Duration = Duration::from_secs(8 * 24 * 3600);
const ASSISTANT_MARK: &str = "\"type\":\"assistant\"";

#[derive(Debug, Clone, Copy, Default, PartialEq, Eq)]
struct Tokens {
    input: u64,
    output: u64,
}

#[derive(Debug, Default)]
struct DayUsage {
    sessions: BTreeSet<String>,
    replies: u64,
    tool_calls: u64,
    models: BTreeMap<String, Tokens>,
}

#[derive(Debug, Clone, Default, PartialEq, Eq)]
pub struct Totals {
    pub replies: u64,
    pub tool_calls: u64,
    pub sessions: u64,
    /// Entrada somada à lida e à criada no cache.
    pub input_tokens: u64,
    pub output_tokens: u64,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct ModelTokens {
    pub model: String,
    pub input_tokens: u64,
    pub output_tokens: u64,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct DayPoint {
    pub date: String,
    pub sessions: u64,
    pub replies: u64,
}

#[derive(Debug, Clone, Default, PartialEq, Eq)]
pub struct UsageSummary {
    pub today: Totals,
    pub week: Totals,
    pub today_models: Vec<ModelTokens>,
    /// Um ponto por dia da semana, do mais antigo para hoje.
    pub days: Vec<DayPoint>,
}

#[derive(Deserialize, Default)]
#[serde(default)]
struct Usage {
    input_tokens: u64,
    output_tokens: u64,
    cache_read_input_tokens: u64,
    cache_creation_input_tokens: u64,
}

/// Só o tipo do bloco; o texto é pulado sem ser copiado.
#[derive(Deserialize)]
struct Block {
    #[serde(rename = "type")]
    kind: Option<String>,
}

#[derive(Deserialize, Default)]
#[serde(default)]
struct Message {
    id: Option<String>,
    model: Option<String>,
    usage: Option<Usage>,
    content: Option<Vec<Block>>,
}

#[derive(Deserialize, Default)]
#[serde(rename_all = "camelCase", default)]
struct AssistantLine {
    session_id: Option<String>,
    timestamp: Option<String>,
    message: Option<Message>,
}

/// Lê os transcritos aos poucos e guarda só os números por dia.
#[derive(Debug, Default)]
pub struct UsageScanner {
    cursors: HashMap<PathBuf, u64>,
    days: BTreeMap<i64, DayUsage>,
    /// Respostas já contadas (uma resposta vem dividida em várias linhas).
    seen: HashMap<String, i64>,
}

fn transcripts(root: &Path) -> Vec<(PathBuf, SystemTime)> {
    let Ok(projects) = fs::read_dir(root.join("projects")) else {
        return Vec::new();
    };
    let mut found = Vec::new();
    for project in projects.flatten().map(|entry| entry.path()) {
        collect_jsonl(&project, &mut found);
        let Ok(sessions) = fs::read_dir(&project) else {
            continue;
        };
        for session in sessions.flatten().map(|entry| entry.path()) {
            collect_jsonl(&session.join("subagents"), &mut found);
        }
    }
    found
}

fn collect_jsonl(dir: &Path, found: &mut Vec<(PathBuf, SystemTime)>) {
    let Ok(entries) = fs::read_dir(dir) else {
        return;
    };
    for path in entries.flatten().map(|entry| entry.path()) {
        if path.extension().is_none_or(|ext| ext != "jsonl") {
            continue;
        }
        if let Ok(modified) = fs::metadata(&path).and_then(|m| m.modified()) {
            found.push((path, modified));
        }
    }
}

fn read_chunk(path: &Path, from: u64, max: u64) -> Option<Vec<u8>> {
    let mut file = File::open(path).ok()?;
    file.seek(SeekFrom::Start(from)).ok()?;
    let mut bytes = Vec::new();
    file.take(max).read_to_end(&mut bytes).ok()?;
    Some(bytes)
}

impl UsageScanner {
    /// Lê o que há de novo, no máximo [budget] bytes; devolve quantos leu.
    pub fn scan(&mut self, root: &Path, now_ms: i64, offset_minutes: i32, budget: u64) -> u64 {
        let first_day = day_of(now_ms, offset_minutes) - (WEEK_DAYS - 1);
        self.forget_before(first_day);
        let mut files = transcripts(root);
        let oldest = SystemTime::now() - FILE_WINDOW;
        files.retain(|(_, modified)| *modified >= oldest);
        // os mexidos por último primeiro: hoje aparece antes
        files.sort_by_key(|(_, modified)| std::cmp::Reverse(*modified));
        let mut used = 0;
        for (path, _) in files {
            if used >= budget {
                break;
            }
            used += self.scan_file(&path, budget - used, first_day, offset_minutes);
        }
        used
    }

    fn scan_file(&mut self, path: &Path, budget: u64, first_day: i64, offset: i32) -> u64 {
        let len = fs::metadata(path).map(|m| m.len()).unwrap_or(0);
        let mut cursor = self.cursors.get(path).copied().unwrap_or(0);
        if len < cursor {
            // arquivo trocado ou encurtado: recomeça (as respostas repetidas
            // não contam de novo)
            cursor = 0;
        }
        if len == cursor {
            return 0;
        }
        let Some(chunk) = read_chunk(path, cursor, budget.min(len - cursor)) else {
            return 0;
        };
        let read = chunk.len() as u64;
        let reached_end = cursor + read >= len;
        let consumed = match chunk.iter().rposition(|&byte| byte == b'\n') {
            Some(last) => last + 1,
            // linha pela metade no fim do arquivo: espera ela terminar
            None if reached_end => 0,
            // uma linha enorme (maior que o limite): pula o pedaço
            None => chunk.len(),
        };
        for line in String::from_utf8_lossy(&chunk[..consumed]).lines() {
            self.take_line(line, first_day, offset);
        }
        self.cursors
            .insert(path.to_path_buf(), cursor + consumed as u64);
        read
    }

    fn take_line(&mut self, line: &str, first_day: i64, offset: i32) {
        if !line.contains(ASSISTANT_MARK) {
            return;
        }
        let Ok(parsed) = serde_json::from_str::<AssistantLine>(line) else {
            return;
        };
        let Some(day) = parsed
            .timestamp
            .as_deref()
            .and_then(parse_iso_ms)
            .map(|ms| day_of(ms, offset))
        else {
            return;
        };
        if day < first_day {
            return;
        }
        let message = parsed.message.unwrap_or_default();
        let is_new = message
            .id
            .as_ref()
            .is_none_or(|id| self.seen.insert(id.clone(), day).is_none());
        let usage = self.days.entry(day).or_default();
        if let Some(session) = parsed.session_id {
            usage.sessions.insert(session);
        }
        usage.tool_calls += message
            .content
            .iter()
            .flatten()
            .filter(|block| block.kind.as_deref() == Some("tool_use"))
            .count() as u64;
        if !is_new {
            return;
        }
        usage.replies += 1;
        if let (Some(model), Some(tokens)) = (message.model, message.usage) {
            let entry = usage.models.entry(model).or_default();
            entry.input += tokens.input_tokens
                + tokens.cache_read_input_tokens
                + tokens.cache_creation_input_tokens;
            entry.output += tokens.output_tokens;
        }
    }

    fn forget_before(&mut self, first_day: i64) {
        self.days.retain(|day, _| *day >= first_day);
        self.seen.retain(|_, day| *day >= first_day);
    }

    pub fn summary(&self, now_ms: i64, offset_minutes: i32) -> UsageSummary {
        let today = day_of(now_ms, offset_minutes);
        let first_day = today - (WEEK_DAYS - 1);
        let empty = DayUsage::default();
        let day = |d: i64| self.days.get(&d).unwrap_or(&empty);
        let week_days: Vec<&DayUsage> = (first_day..=today).map(day).collect();
        UsageSummary {
            today: totals(&[day(today)]),
            week: totals(&week_days),
            today_models: day(today)
                .models
                .iter()
                .map(|(model, tokens)| ModelTokens {
                    model: model.clone(),
                    input_tokens: tokens.input,
                    output_tokens: tokens.output,
                })
                .collect(),
            days: (first_day..=today)
                .map(|d| DayPoint {
                    date: day_to_date(d),
                    sessions: day(d).sessions.len() as u64,
                    replies: day(d).replies,
                })
                .collect(),
        }
    }
}

fn totals(days: &[&DayUsage]) -> Totals {
    let sessions: BTreeSet<&String> = days.iter().flat_map(|d| &d.sessions).collect();
    let tokens = days.iter().flat_map(|d| d.models.values());
    let (input, output) = tokens.fold((0, 0), |(i, o), t| (i + t.input, o + t.output));
    Totals {
        replies: days.iter().map(|d| d.replies).sum(),
        tool_calls: days.iter().map(|d| d.tool_calls).sum(),
        sessions: sessions.len() as u64,
        input_tokens: input,
        output_tokens: output,
    }
}
