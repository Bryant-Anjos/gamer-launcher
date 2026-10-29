//! Descoberta e abertura de aplicativos pelos arquivos `.desktop` (freedesktop).

use crate::paths;
use std::collections::{HashMap, HashSet};
use std::path::{Path, PathBuf};
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
    #[cfg(windows)]
    return discover_start_menu(dirs);
    #[cfg(not(windows))]
    discover_desktop_files(dirs)
}

/// Atalhos `.lnk` do Menu Iniciar (usuário e todos os usuários), sem os
/// desinstaladores. O `exec` guarda o caminho do atalho, aberto pelo Explorer.
#[cfg(windows)]
fn discover_start_menu(dirs: &[PathBuf]) -> Vec<AppEntry> {
    fn walk(dir: &Path, out: &mut Vec<PathBuf>) {
        let Ok(read_dir) = fs::read_dir(dir) else {
            return;
        };
        for entry in read_dir.filter_map(Result::ok) {
            let path = entry.path();
            if path.is_dir() {
                walk(&path, out);
            } else if path.extension().is_some_and(|ext| ext.eq_ignore_ascii_case("lnk")) {
                out.push(path);
            }
        }
    }
    let mut files = Vec::new();
    for dir in dirs {
        walk(dir, &mut files);
    }
    let mut seen = HashSet::new();
    let mut apps: Vec<AppEntry> = files
        .into_iter()
        .filter_map(|path| {
            let name = path.file_stem()?.to_string_lossy().into_owned();
            let lower = name.to_lowercase();
            let hidden = ["uninstall", "desinstal", "readme", "license"]
                .iter()
                .any(|word| lower.contains(word));
            (!hidden && seen.insert(lower)).then(|| AppEntry {
                id: format!("{name}.lnk"),
                name,
                exec: path.to_string_lossy().into_owned(),
                icon: None,
                categories: Vec::new(),
                terminal: false,
                working_dir: None,
            })
        })
        .collect();
    attach_windows_icons(&mut apps);
    apps.sort_by_key(|app| app.name.to_lowercase());
    apps
}

/// Script que extrai o ícone de cada atalho (uma linha `atalho|saida.png`)
/// num único processo do PowerShell. Lê o atalho para achar o ícone dele (ou
/// o do programa de destino) e extrai em 128 px, nítido para cartões grandes.
#[cfg(windows)]
const ICON_SCRIPT: &str = r#"Add-Type -AssemblyName System.Drawing
Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public static class IconApi {
  [DllImport("user32.dll", CharSet = CharSet.Unicode)]
  public static extern uint PrivateExtractIcons(string file, int index, int cx, int cy, IntPtr[] icons, uint[] ids, uint count, uint flags);
  [DllImport("user32.dll")]
  public static extern bool DestroyIcon(IntPtr icon);
}
'@
$shell = New-Object -ComObject WScript.Shell
function Save-IconFrom($file, $index, $out) {
  if (-not $file -or -not (Test-Path -LiteralPath $file)) { return $false }
  $handles = New-Object IntPtr[] 1
  $ids = New-Object uint32[] 1
  $count = [IconApi]::PrivateExtractIcons($file, $index, 128, 128, $handles, $ids, 1, 0)
  if ($count -lt 1 -or $handles[0] -eq [IntPtr]::Zero) { return $false }
  $bitmap = [System.Drawing.Icon]::FromHandle($handles[0]).ToBitmap()
  $bitmap.Save($out, [System.Drawing.Imaging.ImageFormat]::Png)
  $bitmap.Dispose()
  [IconApi]::DestroyIcon($handles[0]) | Out-Null
  return $true
}
Get-Content -LiteralPath $args[0] -Encoding UTF8 | ForEach-Object {
  $p = $_ -split '\|', 2
  try {
    $link = $shell.CreateShortcut($p[0])
    $location = [Environment]::ExpandEnvironmentVariables($link.IconLocation)
    $done = $false
    if ($location) {
      $cut = $location.LastIndexOf(',')
      $file = if ($cut -ge 0) { $location.Substring(0, $cut) } else { $location }
      $index = 0
      if ($cut -ge 0) { [int]::TryParse($location.Substring($cut + 1), [ref]$index) | Out-Null }
      $done = Save-IconFrom $file $index $p[1]
    }
    if (-not $done) { Save-IconFrom ([Environment]::ExpandEnvironmentVariables($link.TargetPath)) 0 $p[1] | Out-Null }
  } catch {}
}
"#;

/// Extrai os ícones que faltam sem travar a abertura: o PowerShell leva
/// vários segundos para iniciar. Os apps aparecem já, com a inicial colorida,
/// e os ícones novos entram na próxima leitura do catálogo.
#[cfg(windows)]
fn extract_icons_in_background(dir: PathBuf, missing: Vec<(String, PathBuf)>) {
    use std::sync::atomic::{AtomicBool, Ordering};
    static RUNNING: AtomicBool = AtomicBool::new(false);
    if RUNNING.swap(true, Ordering::SeqCst) {
        return;
    }
    thread::spawn(move || {
        let list = dir.join("pending.txt");
        let script = dir.join("extract.ps1");
        let lines: Vec<String> = missing
            .iter()
            .map(|(exec, out)| format!("{exec}|{}", out.display()))
            .collect();
        if fs::write(&list, lines.join("\n")).is_ok() && fs::write(&script, ICON_SCRIPT).is_ok() {
            let mut command = Command::new("powershell.exe");
            command
                .args(["-NoProfile", "-NonInteractive", "-ExecutionPolicy", "Bypass", "-File"])
                .arg(&script)
                .arg(&list)
                .stdin(Stdio::null())
                .stdout(Stdio::null())
                .stderr(Stdio::null());
            std::os::windows::process::CommandExt::creation_flags(&mut command, 0x0800_0000);
            if command.status().is_ok() {
                for (_, out) in missing.iter().filter(|(_, out)| !out.is_file()) {
                    let _ = fs::write(out.with_extension("none"), b"");
                }
            }
        }
        RUNNING.store(false, Ordering::SeqCst);
    });
}

/// Ícones dos atalhos, guardados em `%LOCALAPPDATA%\gamer-launcher\icons`.
/// Só os que faltam no cache são extraídos, em segundo plano.
#[cfg(windows)]
fn attach_windows_icons(apps: &mut [AppEntry]) {
    let Some(dir) = paths::data_home().map(|dir| dir.join("gamer-launcher").join("icons")) else {
        return;
    };
    if fs::create_dir_all(&dir).is_err() {
        return;
    }
    let file_name = |app: &AppEntry| {
        let safe: String = app
            .name
            .chars()
            .map(|c| if c.is_alphanumeric() || c == ' ' { c } else { '_' })
            .collect();
        dir.join(format!("{safe}.png"))
    };
    // atalho sem ícone extraível ganha um marcador `.none`: não é tentado de novo
    let missing: Vec<(String, PathBuf)> = apps
        .iter()
        .filter(|app| !file_name(app).is_file() && !file_name(app).with_extension("none").is_file())
        .map(|app| (app.exec.clone(), file_name(app)))
        .collect();
    if !missing.is_empty() {
        extract_icons_in_background(dir.clone(), missing);
    }
    for app in apps {
        let file = file_name(app);
        if file.is_file() {
            app.icon = Some(file.to_string_lossy().into_owned());
        }
    }
}

#[cfg(not(windows))]
#[allow(dead_code)]
fn attach_windows_icons(_apps: &mut [AppEntry]) {}

#[cfg_attr(windows, allow(dead_code))]
fn discover_desktop_files(dirs: &[PathBuf]) -> Vec<AppEntry> {
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

#[cfg(windows)]
pub fn default_app_dirs() -> Vec<PathBuf> {
    let start_menu = |root: Option<String>| {
        root.map(|root| PathBuf::from(root).join("Microsoft/Windows/Start Menu/Programs"))
    };
    [
        start_menu(std::env::var("APPDATA").ok()),
        start_menu(std::env::var("ProgramData").ok()),
    ]
    .into_iter()
    .flatten()
    .collect()
}

#[cfg(not(windows))]
pub fn default_app_dirs() -> Vec<PathBuf> {
    app_dirs_from(paths::data_home(), paths::home_dir(), &paths::data_dirs())
}

#[cfg(not(windows))]
const DEFAULT_OPENER: &str = "xdg-open";
#[cfg(windows)]
const DEFAULT_OPENER: &str = "explorer.exe";

pub fn find_app<'a>(apps: &'a [AppEntry], id: &str) -> Option<&'a AppEntry> {
    apps.iter().find(|app| app.id == id)
}

/// Inicia um programa sem esperar por ele, sem shell e sem terminal; o
/// processo filho é recolhido em segundo plano para não virar zumbi.
pub(crate) fn spawn_detached(
    program: &str,
    args: &[String],
    working_dir: Option<&Path>,
) -> io::Result<()> {
    let mut command = Command::new(program);
    command
        .args(args)
        .stdin(Stdio::null())
        .stdout(Stdio::null())
        .stderr(Stdio::null());
    if let Some(dir) = working_dir {
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

/// Abre um atalho `.lnk` como o Menu Iniciar faz (`start`). Passar o atalho
/// ao `explorer.exe` só abre a pasta padrão em vez de iniciar o programa.
#[cfg(windows)]
fn launch_windows_shortcut(shortcut: &str) -> io::Result<()> {
    let mut command = Command::new("cmd.exe");
    command
        .args(["/C", "start", ""])
        .arg(shortcut)
        .stdin(Stdio::null())
        .stdout(Stdio::null())
        .stderr(Stdio::null());
    // sem janela de console piscando
    std::os::windows::process::CommandExt::creation_flags(&mut command, 0x0800_0000);
    let mut child = command.spawn()?;
    thread::spawn(move || {
        let _ = child.wait();
    });
    Ok(())
}

/// Abre o app sem esperar por ele.
pub fn launch(app: &AppEntry) -> io::Result<()> {
    if app.terminal {
        return Err(io::Error::new(
            io::ErrorKind::Unsupported,
            "apps de terminal ainda não são suportados",
        ));
    }
    #[cfg(windows)]
    {
        if app.exec.to_lowercase().ends_with(".lnk") {
            return launch_windows_shortcut(&app.exec);
        }
    }
    let args = exec_args(&app.exec);
    let (program, rest) = args
        .split_first()
        .ok_or_else(|| io::Error::new(io::ErrorKind::InvalidInput, "comando de execução vazio"))?;
    spawn_detached(program, rest, app.working_dir.as_deref())
}

/// Abre um arquivo ou pasta com `opener` (o programa padrão do sistema em
/// [`open_path`]). Caminho inexistente falha antes de rodar qualquer coisa.
pub fn open_path_with(opener: &str, path: &Path) -> io::Result<()> {
    // só absolutos: um nome como "-v" nunca vira opção do programa
    if !path.is_absolute() {
        return Err(io::Error::new(
            io::ErrorKind::InvalidInput,
            "o caminho precisa ser absoluto",
        ));
    }
    if !path.exists() {
        return Err(io::Error::new(
            io::ErrorKind::NotFound,
            format!("{} não existe mais", path.display()),
        ));
    }
    spawn_detached(opener, &[path.to_string_lossy().into_owned()], None)
}

pub fn open_path(path: &Path) -> io::Result<()> {
    open_path_with(DEFAULT_OPENER, path)
}
