use crate::convert::{battery_reading, paired_devices, quick_controls, stats_sample};
use flutter_rust_bridge::frb;
use launcher_core::autostart;
use launcher_core::stats::StatsSampler;
pub use launcher_core::system::PowerAction;
use launcher_core::system::{
    AudioControl, BatteryControl, BluetoothControl, BluetoothDevices, BrightnessControl,
    DarkModeControl, LinuxSystem, PowerControl, ProcessRunner, WifiControl,
};
use std::sync::{LazyLock, Mutex, PoisonError};

/// Um controle liga/desliga lido do sistema; `enabled` vazio quando a
/// leitura falhou (aí `error` explica).
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct ToggleReading {
    pub enabled: Option<bool>,
    pub error: Option<String>,
}

/// Um nível de 0 a 100 (volume, brilho); `percent` vazio quando falhou.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct LevelReading {
    pub percent: Option<u8>,
    pub muted: bool,
    pub error: Option<String>,
}

/// Leitura do painel de controle rápido. Cada item falha sozinho.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct QuickControls {
    pub wifi: ToggleReading,
    pub wifi_name: Option<String>,
    pub bluetooth: ToggleReading,
    pub dark_mode: ToggleReading,
    pub volume: LevelReading,
    pub brightness: LevelReading,
}

/// Uso do sistema; tamanhos em bytes (f64 cabe sem perda até 8 PB).
#[derive(Debug, Clone, PartialEq)]
pub struct StatsSample {
    pub cpu_percent: f32,
    pub ram_used_bytes: f64,
    pub ram_total_bytes: f64,
    pub disk_used_bytes: f64,
    pub disk_total_bytes: f64,
}

#[frb(mirror(PowerAction))]
pub enum _PowerAction {
    Shutdown,
    Reboot,
    Suspend,
    LogOut,
}

/// Bateria do computador.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct BatteryReading {
    pub percent: u8,
    pub charging: bool,
}

/// Dispositivo Bluetooth já pareado.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct PairedDevice {
    pub address: String,
    pub name: String,
    pub connected: bool,
}

static SYSTEM: LazyLock<LinuxSystem<ProcessRunner>> =
    LazyLock::new(|| LinuxSystem::new(ProcessRunner::default()));

/// O uso de CPU depende da leitura anterior, por isso o amostrador é único.
static SAMPLER: LazyLock<Mutex<StatsSampler>> = LazyLock::new(|| Mutex::new(StatsSampler::new()));

/// Roda vários programas do sistema; nunca chamar da thread da UI.
pub fn read_quick_controls() -> QuickControls {
    quick_controls(&SYSTEM.snapshot())
}

pub fn set_wifi_enabled(enabled: bool) -> Result<(), String> {
    SYSTEM
        .set_wifi_enabled(enabled)
        .map_err(|error| error.to_string())
}

pub fn set_bluetooth_enabled(enabled: bool) -> Result<(), String> {
    SYSTEM
        .set_bluetooth_enabled(enabled)
        .map_err(|error| error.to_string())
}

/// Tema escuro do sistema (COSMIC), não o do launcher.
pub fn set_system_dark_mode(dark: bool) -> Result<(), String> {
    SYSTEM
        .set_dark_mode(dark)
        .map_err(|error| error.to_string())
}

pub fn set_volume_percent(percent: u8) -> Result<(), String> {
    SYSTEM
        .set_volume_percent(percent)
        .map_err(|error| error.to_string())
}

pub fn set_brightness_percent(percent: u8) -> Result<(), String> {
    SYSTEM
        .set_brightness_percent(percent)
        .map_err(|error| error.to_string())
}

pub fn sample_stats() -> StatsSample {
    let stats = SAMPLER
        .lock()
        .unwrap_or_else(PoisonError::into_inner)
        .sample();
    stats_sample(&stats)
}

/// `None` quando o computador não tem bateria (um desktop, por exemplo).
pub fn read_battery() -> Result<Option<BatteryReading>, String> {
    SYSTEM
        .battery()
        .map(|battery| battery.map(battery_reading))
        .map_err(|error| error.to_string())
}

/// Desligar, reiniciar, suspender ou encerrar a sessão.
pub fn perform_power_action(action: PowerAction) -> Result<(), String> {
    SYSTEM.perform(action).map_err(|error| error.to_string())
}

pub fn list_paired_devices() -> Result<Vec<PairedDevice>, String> {
    SYSTEM
        .paired_devices()
        .map(|devices| paired_devices(&devices))
        .map_err(|error| error.to_string())
}

pub fn connect_bluetooth_device(address: String) -> Result<(), String> {
    SYSTEM
        .connect_device(&address)
        .map_err(|error| error.to_string())
}

pub fn disconnect_bluetooth_device(address: String) -> Result<(), String> {
    SYSTEM
        .disconnect_device(&address)
        .map_err(|error| error.to_string())
}

const NO_AUTOSTART_DIR: &str = "sem pasta de configuração (HOME ausente)";

/// A existência do arquivo em `~/.config/autostart` é a verdade.
pub fn autostart_enabled() -> bool {
    autostart::autostart_file().is_some_and(|file| autostart::is_enabled(&file))
}

pub fn set_autostart(enabled: bool) -> Result<(), String> {
    let file = autostart::autostart_file().ok_or_else(|| NO_AUTOSTART_DIR.to_string())?;
    let exec = if enabled {
        autostart::current_exec_line().map_err(|error| error.to_string())?
    } else {
        String::new()
    };
    autostart::set_enabled(&file, enabled, &exec).map_err(|error| error.to_string())
}
