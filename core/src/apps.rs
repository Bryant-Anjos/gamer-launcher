//! Descoberta e abertura de aplicativos pelos arquivos `.desktop` (freedesktop).

use crate::paths;
use std::collections::{HashMap, HashSet};
use std::path::PathBuf;
use std::process::{Command, Stdio};
use std::{fs, io, thread};

const MAIN_GROUP: &str = "[Desktop Entry]";
const EXTRA_DATA_DIRS: [&str; 2] = ["/var/lib/flatpak/exports/share", "/var/lib/snapd/desktop"];
const USER_FLATPAK_EXPORTS: &str = ".local/share/flatpak/exports/share";

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct AppEntry {
    pub id: String,
    pub name: String,
    pub exec: String,
    pub icon: Option<String>,
    pub categories: Vec<String>,
    pub terminal: bool,
    pub working_dir: Option<PathBuf>,
}

fn main_group_keys(content: &str) -> HashMap<&str, &str> {
    let mut keys = HashMap::new();
    let mut in_main_group = false;
    for line in content.lines().map(str::trim) {
        if line.is_empty() || line.starts_with('#') {
            continue;
        }
        if line.starts_with('[') {
            in_main_group = line == MAIN_GROUP;
            continue;
        }
        if !in_main_group {
            continue;
        }
        if let Some((key, value)) = line.split_once('=') {
            keys.entry(key.trim()).or_insert_with(|| value.trim());
        }
    }
    keys
}

/// `None` para o que não deve aparecer no launcher (não é aplicativo,
/// escondido, ou sem nome/comando).
pub fn parse_desktop_entry(id: &str, content: &str) -> Option<AppEntry> {
    let keys = main_group_keys(content);
    if keys.get("Type") != Some(&"Application") {
        return None;
    }
    if keys.get("NoDisplay") == Some(&"true") || keys.get("Hidden") == Some(&"true") {
        return None;
    }
    let name = keys.get("Name").filter(|name| !name.is_empty())?;
    let exec = keys.get("Exec").filter(|exec| !exec.is_empty())?;
    Some(AppEntry {
        id: id.to_string(),
        name: name.to_string(),
        exec: exec.to_string(),
        icon: keys.get("Icon").map(|icon| icon.to_string()),
        categories: keys
            .get("Categories")
            .map(|list| {
                list.split(';')
                    .filter(|category| !category.is_empty())
                    .map(str::to_string)
                    .collect()
            })
            .unwrap_or_default(),
        terminal: keys.get("Terminal") == Some(&"true"),
        working_dir: keys
            .get("Path")
            .filter(|path| !path.is_empty())
            .map(PathBuf::from),
    })
}

fn split_quoted(exec: &str) -> Vec<String> {
    let mut args = Vec::new();
    let mut current = String::new();
    let mut has_token = false;
    let mut in_quotes = false;
    let mut chars = exec.chars();
    while let Some(c) = chars.next() {
        match c {
            '"' => {
                in_quotes = !in_quotes;
                has_token = true;
            }
            '\\' if in_quotes => {
                if let Some(escaped) = chars.next() {
                    current.push(escaped);
                }
            }
            c if c.is_whitespace() && !in_quotes => {
                if has_token {
                    args.push(std::mem::take(&mut current));
                    has_token = false;
                }
            }
            c => {
                current.push(c);
                has_token = true;
            }
        }
    }
    if has_token {
        args.push(current);
    }
    args
}

fn strip_field_codes(arg: &str) -> String {
    let mut result = String::with_capacity(arg.len());
    let mut chars = arg.chars();
    while let Some(c) = chars.next() {
        if c != '%' {
            result.push(c);
            continue;
        }
        if chars.next() == Some('%') {
            result.push('%');
        }
    }
    result
}

/// Quebra o campo `Exec` em argumentos, removendo os códigos de campo
/// (`%f`, `%U`...) que só fazem sentido quando há arquivos para abrir.
pub fn exec_args(exec: &str) -> Vec<String> {
    split_quoted(exec)
        .into_iter()
        .filter_map(|raw| {
            let stripped = strip_field_codes(&raw);
            // some só o argumento que era apenas um código de campo; "" explícito fica
            (!stripped.is_empty() || raw.is_empty()).then_some(stripped)
        })
        .collect()
}

/// Lê os `.desktop` dos diretórios na ordem dada: o primeiro com um certo
/// id vence, mesmo que esconda o app (é assim que o usuário oculta um app
/// do sistema). Resultado ordenado por nome, sem diferenciar maiúsculas.
pub fn discover_apps(dirs: &[PathBuf]) -> Vec<AppEntry> {
    let mut seen = HashSet::new();
    let mut apps = Vec::new();
    for dir in dirs {
        let Ok(read_dir) = fs::read_dir(dir) else {
            continue;
        };
        let mut files: Vec<_> = read_dir
            .filter_map(Result::ok)
            .filter(|entry| entry.path().extension().is_some_and(|ext| ext == "desktop"))
            .collect();
        files.sort_by_key(|entry| entry.file_name());
        for file in files {
            let id = file.file_name().to_string_lossy().into_owned();
            if !seen.insert(id.clone()) {
                continue;
            }
            if let Some(app) = fs::read_to_string(file.path())
                .ok()
                .and_then(|content| parse_desktop_entry(&id, &content))
            {
                apps.push(app);
            }
        }
    }
    apps.sort_by_key(|app| app.name.to_lowercase());
    apps
}

/// Diretórios `applications` na ordem de prioridade: usuário (dados e
/// Flatpak), depois sistema, Flatpak e Snap. Repetidos aparecem uma vez só.
pub fn app_dirs_from(
    data_home: Option<PathBuf>,
    home: Option<PathBuf>,
    system_data_dirs: &[PathBuf],
) -> Vec<PathBuf> {
    let user_flatpak = home.map(|home| home.join(USER_FLATPAK_EXPORTS));
    let user_dirs = data_home.into_iter().chain(user_flatpak);
    let system_dirs = system_data_dirs
        .iter()
        .cloned()
        .chain(EXTRA_DATA_DIRS.iter().map(PathBuf::from));
    let mut seen = HashSet::new();
    user_dirs
        .chain(system_dirs)
        .map(|dir| dir.join("applications"))
        .filter(|dir| seen.insert(dir.clone()))
        .collect()
}

pub fn default_app_dirs() -> Vec<PathBuf> {
    app_dirs_from(paths::data_home(), paths::home_dir(), &paths::data_dirs())
}

/// Abre o app sem esperar por ele; o processo filho é recolhido em segundo
/// plano para não virar zumbi.
pub fn launch(app: &AppEntry) -> io::Result<()> {
    if app.terminal {
        return Err(io::Error::new(
            io::ErrorKind::Unsupported,
            "apps de terminal ainda não são suportados",
        ));
    }
    let args = exec_args(&app.exec);
    let (program, rest) = args
        .split_first()
        .ok_or_else(|| io::Error::new(io::ErrorKind::InvalidInput, "comando de execução vazio"))?;
    let mut command = Command::new(program);
    command
        .args(rest)
        .stdin(Stdio::null())
        .stdout(Stdio::null())
        .stderr(Stdio::null());
    if let Some(dir) = &app.working_dir {
        command.current_dir(dir);
    }
    #[cfg(unix)]
    std::os::unix::process::CommandExt::process_group(&mut command, 0);
    let mut child = command.spawn()?;
    thread::spawn(move || {
        let _ = child.wait();
    });
    Ok(())
}
