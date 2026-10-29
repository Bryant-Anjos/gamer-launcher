//! Controles do sistema usados no painel de controle rápido.
//!
//! Cada capacidade é um trait; cada sistema operacional implementa os seus.
//! A UI só conhece os traits.

mod error;
mod linux;
mod parse;
mod power;
mod runner;
#[cfg(windows)]
mod windows;

pub use error::SystemError;
pub use linux::LinuxSystem;
pub use runner::{CommandRunner, ProcessRunner};
#[cfg(windows)]
pub use windows::WindowsSystem;

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct Volume {
    pub percent: u8,
    pub muted: bool,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct WifiState {
    pub enabled: bool,
    pub ssid: Option<String>,
}

/// Leitura de todos os controles de uma vez. Cada campo falha sozinho.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct QuickControlsSnapshot {
    pub wifi: Result<WifiState, SystemError>,
    pub bluetooth: Result<bool, SystemError>,
    pub volume: Result<Volume, SystemError>,
    pub brightness: Result<u8, SystemError>,
    pub dark_mode: Result<bool, SystemError>,
}

pub trait WifiControl {
    fn wifi_enabled(&self) -> Result<bool, SystemError>;
    fn set_wifi_enabled(&self, enabled: bool) -> Result<(), SystemError>;
    fn connected_ssid(&self) -> Result<Option<String>, SystemError>;
}

pub trait BluetoothControl {
    fn bluetooth_enabled(&self) -> Result<bool, SystemError>;
    fn set_bluetooth_enabled(&self, enabled: bool) -> Result<(), SystemError>;
}

/// Dispositivo Bluetooth já pareado.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct BluetoothDevice {
    pub address: String,
    pub name: String,
    pub connected: bool,
}

/// Dispositivos pareados: listar, conectar e desconectar. Parear dispositivos
/// novos fica para depois (pode exigir confirmação de PIN).
pub trait BluetoothDevices {
    /// Conectados primeiro; dentro de cada grupo, por nome.
    fn paired_devices(&self) -> Result<Vec<BluetoothDevice>, SystemError>;
    fn connect_device(&self, address: &str) -> Result<(), SystemError>;
    fn disconnect_device(&self, address: &str) -> Result<(), SystemError>;
}

pub trait AudioControl {
    fn volume(&self) -> Result<Volume, SystemError>;
    /// Acima de 100 vale 100.
    fn set_volume_percent(&self, percent: u8) -> Result<(), SystemError>;
    fn set_muted(&self, muted: bool) -> Result<(), SystemError>;
}

pub trait BrightnessControl {
    fn brightness_percent(&self) -> Result<u8, SystemError>;
    /// Nunca apaga a tela: o mínimo aplicado é 1%.
    fn set_brightness_percent(&self, percent: u8) -> Result<(), SystemError>;
}

/// Tema escuro do sistema (não o do launcher).
pub trait DarkModeControl {
    fn dark_mode(&self) -> Result<bool, SystemError>;
    fn set_dark_mode(&self, dark: bool) -> Result<(), SystemError>;
}

/// Bateria do computador. Computador de mesa não tem: `None`, não erro.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct Battery {
    pub percent: u8,
    pub charging: bool,
}

pub trait BatteryControl {
    fn battery(&self) -> Result<Option<Battery>, SystemError>;
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum PowerAction {
    Shutdown,
    Reboot,
    Suspend,
    LogOut,
}

pub trait PowerControl {
    fn perform(&self, action: PowerAction) -> Result<(), SystemError>;
}
