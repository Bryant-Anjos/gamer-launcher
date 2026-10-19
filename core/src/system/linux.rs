use super::{
    AudioControl, BluetoothControl, BluetoothDevice, BluetoothDevices, BrightnessControl,
    CommandRunner, DarkModeControl, QuickControlsSnapshot, SystemError, Volume, WifiControl,
    WifiState, parse,
};
use crate::fs_util::write_atomic;
use crate::paths;
use std::path::{Path, PathBuf};
use std::time::Duration;
use std::{fs, io};

const BACKLIGHT_ROOT: &str = "/sys/class/backlight";
const DEFAULT_SINK: &str = "@DEFAULT_AUDIO_SINK@";
const MIN_BRIGHTNESS_PERCENT: u64 = 1;
const MAX_PERCENT: u8 = 100;
/// Conectar um dispositivo pode levar vários segundos.
const BLUETOOTH_CONNECT_TIMEOUT: Duration = Duration::from_secs(15);

/// Controles do sistema no Linux (NetworkManager, BlueZ, PipeWire, logind
/// e o tema do COSMIC), todos por programas de linha de comando e arquivos.
pub struct LinuxSystem<R: CommandRunner> {
    runner: R,
    backlight_root: PathBuf,
    dark_mode_file: Option<PathBuf>,
}

impl<R: CommandRunner> LinuxSystem<R> {
    pub fn new(runner: R) -> Self {
        Self {
            runner,
            backlight_root: PathBuf::from(BACKLIGHT_ROOT),
            dark_mode_file: paths::cosmic_dark_mode_path(),
        }
    }

    pub fn with_paths(runner: R, backlight_root: PathBuf, dark_mode_file: PathBuf) -> Self {
        Self {
            runner,
            backlight_root,
            dark_mode_file: Some(dark_mode_file),
        }
    }

    /// Lê todos os controles; uma falha não esconde os demais.
    pub fn snapshot(&self) -> QuickControlsSnapshot {
        QuickControlsSnapshot {
            wifi: self.wifi_enabled().map(|enabled| WifiState {
                enabled,
                ssid: if enabled {
                    self.connected_ssid().unwrap_or(None)
                } else {
                    None
                },
            }),
            bluetooth: self.bluetooth_enabled(),
            volume: self.volume(),
            brightness: self.brightness_percent(),
            dark_mode: self.dark_mode(),
        }
    }

    fn backlight_device(&self) -> Result<PathBuf, SystemError> {
        let unavailable = || SystemError::Unavailable("sem controle de brilho".into());
        let mut devices: Vec<PathBuf> = fs::read_dir(&self.backlight_root)
            .map_err(|_| unavailable())?
            .filter_map(Result::ok)
            .map(|entry| entry.path())
            .collect();
        devices.sort();
        devices.into_iter().next().ok_or_else(unavailable)
    }

    fn dark_mode_path(&self) -> Result<&Path, SystemError> {
        self.dark_mode_file
            .as_deref()
            .ok_or_else(|| SystemError::Unavailable("sem pasta de configuração do COSMIC".into()))
    }
}

fn read_number(path: &Path) -> Result<u64, SystemError> {
    let text = fs::read_to_string(path).map_err(|error| SystemError::Io(error.to_string()))?;
    text.trim()
        .parse()
        .map_err(|_| SystemError::Parse(format!("{}: {:?}", path.display(), text.trim())))
}

impl<R: CommandRunner> WifiControl for LinuxSystem<R> {
    fn wifi_enabled(&self) -> Result<bool, SystemError> {
        parse::wifi_radio(&self.runner.run("nmcli", &["radio", "wifi"])?)
    }

    fn set_wifi_enabled(&self, enabled: bool) -> Result<(), SystemError> {
        let state = if enabled { "on" } else { "off" };
        self.runner
            .run("nmcli", &["radio", "wifi", state])
            .map(drop)
    }

    fn connected_ssid(&self) -> Result<Option<String>, SystemError> {
        let output = self
            .runner
            .run("nmcli", &["-t", "-f", "ACTIVE,SSID", "dev", "wifi"])?;
        Ok(parse::active_ssid(&output))
    }
}

impl<R: CommandRunner> BluetoothControl for LinuxSystem<R> {
    fn bluetooth_enabled(&self) -> Result<bool, SystemError> {
        parse::bluetooth_powered(&self.runner.run("bluetoothctl", &["show"])?)
    }

    fn set_bluetooth_enabled(&self, enabled: bool) -> Result<(), SystemError> {
        if enabled {
            self.runner.run("rfkill", &["unblock", "bluetooth"])?;
        }
        let state = if enabled { "on" } else { "off" };
        self.runner.run("bluetoothctl", &["power", state]).map(drop)
    }
}

impl<R: CommandRunner> BluetoothDevices for LinuxSystem<R> {
    fn paired_devices(&self) -> Result<Vec<BluetoothDevice>, SystemError> {
        let paired = parse::bluetooth_device_lines(
            &self.runner.run("bluetoothctl", &["devices", "Paired"])?,
        )?;
        // versões antigas do BlueZ não têm "devices Connected"; sem ele,
        // os dispositivos aparecem como desconectados em vez de a lista falhar
        let connected = self
            .runner
            .run("bluetoothctl", &["devices", "Connected"])
            .ok()
            .and_then(|output| parse::bluetooth_device_lines(&output).ok())
            .unwrap_or_default();

        let mut devices: Vec<BluetoothDevice> = paired
            .into_iter()
            .map(|(address, name)| BluetoothDevice {
                connected: connected.iter().any(|(other, _)| *other == address),
                address,
                name,
            })
            .collect();
        devices.sort_by(|a, b| {
            b.connected
                .cmp(&a.connected)
                .then_with(|| a.name.to_lowercase().cmp(&b.name.to_lowercase()))
        });
        Ok(devices)
    }

    fn connect_device(&self, address: &str) -> Result<(), SystemError> {
        let address = parse::bluetooth_address(address)?;
        let output = self.runner.run_with_timeout(
            "bluetoothctl",
            &["connect", &address],
            BLUETOOTH_CONNECT_TIMEOUT,
        )?;
        bluetooth_outcome(&output)
    }

    fn disconnect_device(&self, address: &str) -> Result<(), SystemError> {
        let address = parse::bluetooth_address(address)?;
        let output = self.runner.run("bluetoothctl", &["disconnect", &address])?;
        bluetooth_outcome(&output)
    }
}

fn bluetooth_outcome(output: &str) -> Result<(), SystemError> {
    match parse::bluetooth_failure(output) {
        Some(message) => Err(SystemError::CommandFailed {
            program: "bluetoothctl".into(),
            message,
        }),
        None => Ok(()),
    }
}

impl<R: CommandRunner> AudioControl for LinuxSystem<R> {
    fn volume(&self) -> Result<Volume, SystemError> {
        let (percent, muted) =
            parse::volume(&self.runner.run("wpctl", &["get-volume", DEFAULT_SINK])?)?;
        Ok(Volume { percent, muted })
    }

    fn set_volume_percent(&self, percent: u8) -> Result<(), SystemError> {
        let fraction = f64::from(percent.min(MAX_PERCENT)) / 100.0;
        self.runner
            .run(
                "wpctl",
                &["set-volume", DEFAULT_SINK, &format!("{fraction:.2}")],
            )
            .map(drop)
    }

    fn set_muted(&self, muted: bool) -> Result<(), SystemError> {
        let flag = if muted { "1" } else { "0" };
        self.runner
            .run("wpctl", &["set-mute", DEFAULT_SINK, flag])
            .map(drop)
    }
}

impl<R: CommandRunner> BrightnessControl for LinuxSystem<R> {
    fn brightness_percent(&self) -> Result<u8, SystemError> {
        let device = self.backlight_device()?;
        let current = read_number(&device.join("brightness"))?;
        let max = read_number(&device.join("max_brightness"))?;
        if max == 0 {
            return Err(SystemError::Parse("brilho máximo igual a zero".into()));
        }
        let percent = (current * 100 + max / 2) / max;
        Ok(percent.min(u64::from(MAX_PERCENT)) as u8)
    }

    /// Escreve pelo logind, que dispensa permissão de administrador.
    /// Nunca zera o brilho, para não deixar a tela preta.
    fn set_brightness_percent(&self, percent: u8) -> Result<(), SystemError> {
        let device = self.backlight_device()?;
        let name = device
            .file_name()
            .map(|name| name.to_string_lossy().into_owned())
            .ok_or_else(|| SystemError::Unavailable("sem controle de brilho".into()))?;
        let max = read_number(&device.join("max_brightness"))?;
        let percent = u64::from(percent).clamp(MIN_BRIGHTNESS_PERCENT, u64::from(MAX_PERCENT));
        let value = (max * percent / 100).max(1);
        self.runner
            .run(
                "busctl",
                &[
                    "call",
                    "org.freedesktop.login1",
                    "/org/freedesktop/login1/session/auto",
                    "org.freedesktop.login1.Session",
                    "SetBrightness",
                    "ssu",
                    "backlight",
                    &name,
                    &value.to_string(),
                ],
            )
            .map(drop)
    }
}

impl<R: CommandRunner> DarkModeControl for LinuxSystem<R> {
    fn dark_mode(&self) -> Result<bool, SystemError> {
        let path = self.dark_mode_path()?;
        match fs::read_to_string(path) {
            Ok(text) => parse::flag(&text),
            Err(error) if error.kind() == io::ErrorKind::NotFound => Err(SystemError::Unavailable(
                "o COSMIC ainda não gravou o tema".into(),
            )),
            Err(error) => Err(SystemError::Io(error.to_string())),
        }
    }

    fn set_dark_mode(&self, dark: bool) -> Result<(), SystemError> {
        let path = self.dark_mode_path()?;
        write_atomic(path, if dark { b"true" } else { b"false" })
            .map_err(|error| SystemError::Io(error.to_string()))
    }
}
