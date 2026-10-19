//! Conversões entre os tipos do núcleo e os tipos simples que a ponte
//! entrega ao Flutter. Fica fora de `api` para o gerador não expô-las.

use crate::api::catalog::{AppCatalog, AppInfo};
use crate::api::files::RecentFile;
use crate::api::search::{SearchKind, SearchResult};
use crate::api::settings::{
    LauncherButtonLayout, LauncherSettings, LauncherThemeMode, PanelVisibility, ResolvedTheme,
};
use crate::api::system::{
    BatteryReading, LevelReading, PairedDevice, QuickControls, StatsSample, ToggleReading,
};
use launcher_core::apps::{find_app, AppEntry};
use launcher_core::featured::{game_launchers, music_player};
use launcher_core::history::LaunchHistory;
use launcher_core::icons::resolve_icon;
use launcher_core::input::ButtonLayoutSetting;
use launcher_core::recents::RecentItem;
use launcher_core::search::{ItemKind, SearchItem};
use launcher_core::settings::{Panel, Settings, ThemeMode};
use launcher_core::stats::SystemStats;
use launcher_core::system::{Battery, BluetoothDevice, QuickControlsSnapshot, SystemError};
use launcher_core::theme::Theme;
use launcher_core::time_of_day::TimeOfDay;
use std::io;
use std::path::{Path, PathBuf};

#[cfg(test)]
mod tests;

const HOME_MARK: &str = "~";

fn theme_mode_to_dto(mode: ThemeMode) -> LauncherThemeMode {
    match mode {
        ThemeMode::Light => LauncherThemeMode::Light,
        ThemeMode::Dark => LauncherThemeMode::Dark,
        ThemeMode::Auto => LauncherThemeMode::Auto,
    }
}

fn theme_mode_from_dto(mode: LauncherThemeMode) -> ThemeMode {
    match mode {
        LauncherThemeMode::Light => ThemeMode::Light,
        LauncherThemeMode::Dark => ThemeMode::Dark,
        LauncherThemeMode::Auto => ThemeMode::Auto,
    }
}

pub fn button_layout_to_dto(setting: ButtonLayoutSetting) -> LauncherButtonLayout {
    match setting {
        ButtonLayoutSetting::Auto => LauncherButtonLayout::Auto,
        ButtonLayoutSetting::Xbox => LauncherButtonLayout::Xbox,
        ButtonLayoutSetting::Nintendo => LauncherButtonLayout::Nintendo,
    }
}

pub fn button_layout_from_dto(layout: LauncherButtonLayout) -> ButtonLayoutSetting {
    match layout {
        LauncherButtonLayout::Auto => ButtonLayoutSetting::Auto,
        LauncherButtonLayout::Xbox => ButtonLayoutSetting::Xbox,
        LauncherButtonLayout::Nintendo => ButtonLayoutSetting::Nintendo,
    }
}

pub fn resolved_theme(theme: Theme) -> ResolvedTheme {
    match theme {
        Theme::Light => ResolvedTheme::Light,
        Theme::Dark => ResolvedTheme::Dark,
    }
}

pub fn settings_to_dto(settings: &Settings) -> LauncherSettings {
    let visible = |panel| settings.is_panel_visible(panel);
    LauncherSettings {
        theme_mode: theme_mode_to_dto(settings.theme_mode),
        dark_starts_minute: settings.dark_starts_at.minutes(),
        light_starts_minute: settings.light_starts_at.minutes(),
        wallpaper: settings
            .wallpaper
            .as_ref()
            .map(|path| path.to_string_lossy().into_owned()),
        favorites: settings.favorites.clone(),
        panels: PanelVisibility {
            search: visible(Panel::Search),
            quick_controls: visible(Panel::QuickControls),
            system: visible(Panel::System),
            recents: visible(Panel::Recents),
            favorites: visible(Panel::Favorites),
            featured_cards: visible(Panel::FeaturedCards),
        },
        button_layout: button_layout_to_dto(settings.button_layout),
        sounds: settings.sounds,
        reduce_animations: settings.reduce_animations,
    }
}

fn panel_flags(panels: &PanelVisibility) -> [(Panel, bool); 6] {
    [
        (Panel::Search, panels.search),
        (Panel::QuickControls, panels.quick_controls),
        (Panel::System, panels.system),
        (Panel::Recents, panels.recents),
        (Panel::Favorites, panels.favorites),
        (Panel::FeaturedCards, panels.featured_cards),
    ]
}

fn time_of_day(minutes: u16) -> Result<TimeOfDay, String> {
    TimeOfDay::from_minutes(minutes).map_err(|error| error.to_string())
}

/// Monta as configurações do núcleo pelos construtores, que validam tudo.
pub fn settings_from_dto(dto: &LauncherSettings) -> Result<Settings, String> {
    let dark_starts_at = time_of_day(dto.dark_starts_minute)?;
    let light_starts_at = time_of_day(dto.light_starts_minute)?;
    let base = Settings::default()
        .with_theme_mode(theme_mode_from_dto(dto.theme_mode))
        .with_wallpaper(dto.wallpaper.as_ref().map(PathBuf::from))
        .with_button_layout(button_layout_from_dto(dto.button_layout))
        .with_sounds(dto.sounds)
        .with_reduce_animations(dto.reduce_animations)
        .with_favorites(dto.favorites.clone())
        .and_then(|settings| settings.with_auto_schedule(dark_starts_at, light_starts_at))
        .map_err(|error| error.to_string())?;
    Ok(panel_flags(&dto.panels)
        .into_iter()
        .fold(base, |settings, (panel, visible)| {
            settings.with_panel_visible(panel, visible)
        }))
}

fn app_info(app: &AppEntry, roots: &[PathBuf], pixmaps: &[PathBuf]) -> AppInfo {
    AppInfo {
        id: app.id.clone(),
        name: app.name.clone(),
        icon_path: app
            .icon
            .as_deref()
            .and_then(|icon| resolve_icon(icon, roots, pixmaps))
            .map(|path| path.to_string_lossy().into_owned()),
        categories: app.categories.clone(),
    }
}

pub fn build_catalog(
    apps: &[AppEntry],
    roots: &[PathBuf],
    pixmaps: &[PathBuf],
    history: Result<LaunchHistory, String>,
) -> AppCatalog {
    let (last_app_id, warnings) = match history {
        Ok(history) => (
            history.last_app.filter(|id| find_app(apps, id).is_some()),
            Vec::new(),
        ),
        Err(message) => (None, vec![message]),
    };
    AppCatalog {
        apps: apps
            .iter()
            .map(|app| app_info(app, roots, pixmaps))
            .collect(),
        game_launcher_ids: game_launchers(apps)
            .iter()
            .map(|app| app.id.clone())
            .collect(),
        music_player_id: music_player(apps).map(|app| app.id.clone()),
        last_app_id,
        warnings,
    }
}

fn display_folder(folder: &Path, home: Option<&Path>) -> String {
    match home.and_then(|home| folder.strip_prefix(home).ok()) {
        Some(rest) if rest.as_os_str().is_empty() => HOME_MARK.to_string(),
        Some(rest) => format!("{HOME_MARK}/{}", rest.display()),
        None => folder.display().to_string(),
    }
}

pub fn recent_file(item: &RecentItem, home: Option<&Path>) -> RecentFile {
    let name = item
        .path
        .file_name()
        .map(|name| name.to_string_lossy().into_owned())
        .unwrap_or_else(|| item.path.display().to_string());
    let location = item
        .path
        .parent()
        .map(|folder| display_folder(folder, home))
        .unwrap_or_default();
    RecentFile {
        path: item.path.to_string_lossy().into_owned(),
        name,
        location,
        modified: item.modified.clone(),
        is_dir: item.path.is_dir(),
    }
}

fn toggle(reading: Result<bool, &SystemError>) -> ToggleReading {
    ToggleReading {
        enabled: reading.ok(),
        error: reading.err().map(ToString::to_string),
    }
}

fn level(percent: Result<u8, &SystemError>, muted: bool) -> LevelReading {
    LevelReading {
        percent: percent.ok(),
        muted,
        error: percent.err().map(ToString::to_string),
    }
}

pub fn quick_controls(snapshot: &QuickControlsSnapshot) -> QuickControls {
    let wifi = snapshot.wifi.as_ref();
    QuickControls {
        wifi: toggle(wifi.map(|state| state.enabled)),
        wifi_name: wifi.ok().and_then(|state| state.ssid.clone()),
        bluetooth: toggle(snapshot.bluetooth.as_ref().copied()),
        dark_mode: toggle(snapshot.dark_mode.as_ref().copied()),
        volume: level(
            snapshot.volume.as_ref().map(|volume| volume.percent),
            snapshot.volume.as_ref().is_ok_and(|volume| volume.muted),
        ),
        brightness: level(snapshot.brightness.as_ref().copied(), false),
    }
}

pub fn stats_sample(stats: &SystemStats) -> StatsSample {
    StatsSample {
        cpu_percent: stats.cpu_percent,
        ram_used_bytes: stats.ram_used as f64,
        ram_total_bytes: stats.ram_total as f64,
        disk_used_bytes: stats.disk_used as f64,
        disk_total_bytes: stats.disk_total as f64,
    }
}

/// Mensagem curta para o aviso na tela.
pub fn friendly_io_error(error: &io::Error) -> String {
    match error.kind() {
        io::ErrorKind::NotFound => "programa ou arquivo não encontrado".to_string(),
        io::ErrorKind::PermissionDenied => "sem permissão para abrir".to_string(),
        _ => error
            .get_ref()
            .map_or_else(|| error.to_string(), ToString::to_string),
    }
}

const APP_ID_PREFIX: &str = "app:";

fn search_kind(kind: ItemKind) -> SearchKind {
    match kind {
        ItemKind::App => SearchKind::App,
        ItemKind::File => SearchKind::File,
        ItemKind::Setting => SearchKind::Setting,
    }
}

/// Resultado de pesquisa para a UI; arquivos mostram a pasta com `~`.
pub fn search_result_in(item: &SearchItem, home: Option<&Path>) -> SearchResult {
    let subtitle = match item.kind {
        ItemKind::File => item
            .subtitle
            .as_deref()
            .map(|folder| display_folder(Path::new(folder), home)),
        _ => item.subtitle.clone(),
    };
    SearchResult {
        kind: search_kind(item.kind),
        id: item.id.clone(),
        title: item.title.clone(),
        subtitle,
        app_id: item.id.strip_prefix(APP_ID_PREFIX).map(str::to_string),
    }
}

pub fn search_result(item: &SearchItem) -> SearchResult {
    search_result_in(item, launcher_core::paths::home_dir().as_deref())
}

pub fn paired_devices(devices: &[BluetoothDevice]) -> Vec<PairedDevice> {
    devices
        .iter()
        .map(|device| PairedDevice {
            address: device.address.clone(),
            name: device.name.clone(),
            connected: device.connected,
        })
        .collect()
}

pub fn battery_reading(battery: Battery) -> BatteryReading {
    BatteryReading {
        percent: battery.percent,
        charging: battery.charging,
    }
}
