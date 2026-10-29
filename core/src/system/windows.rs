//! Controles do sistema no Windows, por programas que já vêm com ele
//! (PowerShell, `reg`, `netsh`, `shutdown`), sem bibliotecas extras.

use super::{
    AudioControl, Battery, BatteryControl, BluetoothControl, BluetoothDevice, BluetoothDevices,
    BrightnessControl, CommandRunner, DarkModeControl, PowerAction, PowerControl,
    QuickControlsSnapshot, SystemError, Volume, WifiControl, WifiState,
};
use std::time::Duration;
use windows_sys::Win32::System::Power::{GetSystemPowerStatus, SYSTEM_POWER_STATUS};

const POWERSHELL: &str = "powershell.exe";
const SCRIPT_TIMEOUT: Duration = Duration::from_secs(20);
const PERSONALIZE_KEY: &str = r"HKCU\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize";
const LIGHT_THEME_VALUE: &str = "AppsUseLightTheme";
const MAX_PERCENT: u8 = 100;

/// Volume mestre pela API de áudio do Windows (COM), carregada via PowerShell.
const AUDIO_PRELUDE: &str = r#"
Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
[Guid("5CDF2C82-841E-4546-9722-0CF74078229A"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
interface IAudioEndpointVolume {
  int RegisterControlChangeNotify(IntPtr p); int UnregisterControlChangeNotify(IntPtr p);
  int GetChannelCount(out uint c); int SetMasterVolumeLevel(float l, ref Guid g);
  int SetMasterVolumeLevelScalar(float l, ref Guid g); int GetMasterVolumeLevel(out float l);
  int GetMasterVolumeLevelScalar(out float l); int SetChannelVolumeLevel(uint c, float l, ref Guid g);
  int SetChannelVolumeLevelScalar(uint c, float l, ref Guid g); int GetChannelVolumeLevel(uint c, out float l);
  int GetChannelVolumeLevelScalar(uint c, out float l);
  int SetMute([MarshalAs(UnmanagedType.Bool)] bool m, ref Guid g);
  int GetMute([MarshalAs(UnmanagedType.Bool)] out bool m);
}
[Guid("D666063F-1587-4E43-81F1-B948E807363F"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
interface IMMDevice {
  int Activate(ref Guid iid, uint ctx, IntPtr p, [MarshalAs(UnmanagedType.IUnknown)] out object o);
}
[Guid("A95664D2-9614-4F35-A746-DE8DB63617E6"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
interface IMMDeviceEnumerator {
  int EnumAudioEndpoints(int f, int s, out IntPtr d);
  int GetDefaultAudioEndpoint(int f, int r, out IMMDevice d);
}
[ComImport, Guid("BCDE0395-E52F-467C-8E3D-C4579291692E")] class MMDeviceEnumeratorCom { }
public static class Audio {
  static IAudioEndpointVolume Endpoint() {
    var e = (IMMDeviceEnumerator)(new MMDeviceEnumeratorCom());
    IMMDevice d; Marshal.ThrowExceptionForHR(e.GetDefaultAudioEndpoint(0, 1, out d));
    var iid = typeof(IAudioEndpointVolume).GUID; object o;
    Marshal.ThrowExceptionForHR(d.Activate(ref iid, 23, IntPtr.Zero, out o));
    return (IAudioEndpointVolume)o;
  }
  public static string Get() { float v; bool m; var ep = Endpoint(); ep.GetMasterVolumeLevelScalar(out v); ep.GetMute(out m); return Math.Round(v * 100) + "|" + (m ? "1" : "0"); }
  public static void SetVolume(int p) { var g = Guid.Empty; Endpoint().SetMasterVolumeLevelScalar(p / 100f, ref g); }
  public static void SetMute(bool m) { var g = Guid.Empty; Endpoint().SetMute(m, ref g); }
}
'@
"#;

pub struct WindowsSystem<R: CommandRunner> {
    runner: R,
}

impl<R: CommandRunner> WindowsSystem<R> {
    pub fn new(runner: R) -> Self {
        Self { runner }
    }

    fn powershell(&self, script: &str) -> Result<String, SystemError> {
        self.runner.run_with_timeout(
            POWERSHELL,
            &[
                "-NoProfile",
                "-NonInteractive",
                "-ExecutionPolicy",
                "Bypass",
                "-Command",
                script,
            ],
            SCRIPT_TIMEOUT,
        )
    }

    fn audio(&self, call: &str) -> Result<String, SystemError> {
        self.powershell(&format!("{AUDIO_PRELUDE}\n[Audio]::{call}"))
    }

    /// Wi-Fi: placa ativa e nome da rede (o perfil de conexão), sem a
    /// permissão de localização que o `netsh wlan` exige.
    fn wifi_state(&self) -> Result<WifiState, SystemError> {
        self.powershell(&format!("{WIFI_SCRIPT}\n$wifi")).and_then(|out| parse_wifi(out.trim()))
    }

    /// Wi-Fi, volume e brilho numa única chamada: cada PowerShell custa vários
    /// segundos para abrir, então um só processo lê os três.
    #[allow(clippy::type_complexity)]
    fn slow_reads(
        &self,
    ) -> (
        Result<WifiState, SystemError>,
        Result<Volume, SystemError>,
        Result<u8, SystemError>,
    ) {
        let script = format!(
            "{AUDIO_PRELUDE}\n{WIFI_SCRIPT}\n[Audio]::Get()\ntry {{ (Get-CimInstance -Namespace root/WMI -ClassName WmiMonitorBrightness -ErrorAction Stop | Select-Object -First 1).CurrentBrightness }} catch {{ 'NA' }}\n$wifi"
        );
        let out = match self.powershell(&script) {
            Ok(out) => out,
            Err(error) => return (Err(error.clone()), Err(error.clone()), Err(error)),
        };
        let mut lines = out.lines().map(str::trim).filter(|line| !line.is_empty());
        let volume = lines
            .next()
            .ok_or_else(|| SystemError::Parse("volume: vazio".into()))
            .and_then(parse_volume);
        let brightness = lines
            .next()
            .and_then(|line| line.parse::<u8>().ok())
            .map(|value| value.min(MAX_PERCENT))
            .ok_or_else(no_brightness);
        let wifi = lines
            .next()
            .ok_or_else(|| SystemError::Parse("wifi: vazio".into()))
            .and_then(parse_wifi);
        (wifi, volume, brightness)
    }

    /// Lê todos os controles; uma falha não esconde os demais.
    pub fn snapshot(&self) -> QuickControlsSnapshot {
        let (wifi, volume, brightness) = self.slow_reads();
        QuickControlsSnapshot {
            wifi,
            bluetooth: self.bluetooth_enabled(),
            volume,
            brightness,
            dark_mode: self.dark_mode(),
        }
    }
}

/// Lê a placa Wi-Fi ativa e o perfil de rede dela. Sai `1|nome` ou `0|`.
const WIFI_SCRIPT: &str = r#"$adapter = Get-NetAdapter -Physical | Where-Object { $_.PhysicalMediaType -match '802.11|Native' -and $_.Status -ne 'Disabled' } | Select-Object -First 1
$wifi = '0|'
if ($adapter) {
  $conn = (Get-NetConnectionProfile -InterfaceAlias $adapter.Name -ErrorAction SilentlyContinue | Select-Object -First 1).Name
  $wifi = '1|' + $conn
}"#;

fn parse_wifi(line: &str) -> Result<WifiState, SystemError> {
    let (enabled, name) = line
        .split_once('|')
        .ok_or_else(|| SystemError::Parse(format!("wifi: {line:?}")))?;
    let name = name.trim();
    Ok(WifiState {
        enabled: enabled == "1",
        ssid: (enabled == "1" && !name.is_empty()).then(|| name.to_string()),
    })
}

fn parse_volume(line: &str) -> Result<Volume, SystemError> {
    let parse_error = || SystemError::Parse(format!("volume: {line:?}"));
    let (percent, muted) = line.split_once('|').ok_or_else(parse_error)?;
    let percent = percent.parse::<u8>().map_err(|_| parse_error())?;
    Ok(Volume {
        percent: percent.min(MAX_PERCENT),
        muted: muted == "1",
    })
}

fn unsupported(what: &str) -> SystemError {
    SystemError::Unavailable(format!("{what} ainda não é suportado no Windows"))
}

fn no_brightness() -> SystemError {
    SystemError::Unavailable("sem controle de brilho (monitor externo)".into())
}

impl<R: CommandRunner> WifiControl for WindowsSystem<R> {
    fn wifi_enabled(&self) -> Result<bool, SystemError> {
        self.wifi_state().map(|state| state.enabled)
    }

    fn set_wifi_enabled(&self, _enabled: bool) -> Result<(), SystemError> {
        Err(unsupported("ligar ou desligar o Wi-Fi"))
    }

    fn connected_ssid(&self) -> Result<Option<String>, SystemError> {
        self.wifi_state().map(|state| state.ssid)
    }
}

impl<R: CommandRunner> BluetoothControl for WindowsSystem<R> {
    fn bluetooth_enabled(&self) -> Result<bool, SystemError> {
        // estado do serviço de suporte a Bluetooth (rápido, sem PowerShell)
        let out = self.runner.run("sc", &["query", "bthserv"])?;
        Ok(out.contains("RUNNING"))
    }

    fn set_bluetooth_enabled(&self, _enabled: bool) -> Result<(), SystemError> {
        Err(unsupported("ligar ou desligar o Bluetooth"))
    }
}

impl<R: CommandRunner> BluetoothDevices for WindowsSystem<R> {
    fn paired_devices(&self) -> Result<Vec<BluetoothDevice>, SystemError> {
        Ok(Vec::new())
    }

    fn connect_device(&self, _address: &str) -> Result<(), SystemError> {
        Err(unsupported("conectar dispositivos Bluetooth"))
    }

    fn disconnect_device(&self, _address: &str) -> Result<(), SystemError> {
        Err(unsupported("desconectar dispositivos Bluetooth"))
    }
}

impl<R: CommandRunner> AudioControl for WindowsSystem<R> {
    fn volume(&self) -> Result<Volume, SystemError> {
        let out = self.audio("Get()")?;
        parse_volume(out.lines().last().unwrap_or_default().trim())
    }

    fn set_volume_percent(&self, percent: u8) -> Result<(), SystemError> {
        self.audio(&format!("SetVolume({})", percent.min(MAX_PERCENT)))
            .map(drop)
    }

    fn set_muted(&self, muted: bool) -> Result<(), SystemError> {
        self.audio(&format!("SetMute(${muted})")).map(drop)
    }
}

impl<R: CommandRunner> BrightnessControl for WindowsSystem<R> {
    fn brightness_percent(&self) -> Result<u8, SystemError> {
        let out = self
            .powershell(
                "(Get-CimInstance -Namespace root/WMI -ClassName WmiMonitorBrightness -ErrorAction Stop | Select-Object -First 1).CurrentBrightness",
            )
            .map_err(|_| no_brightness())?;
        out.trim()
            .parse::<u8>()
            .map(|value| value.min(MAX_PERCENT))
            .map_err(|_| no_brightness())
    }

    fn set_brightness_percent(&self, percent: u8) -> Result<(), SystemError> {
        let percent = percent.clamp(1, MAX_PERCENT);
        self.powershell(&format!(
            "Get-CimInstance -Namespace root/WMI -ClassName WmiMonitorBrightnessMethods -ErrorAction Stop | Invoke-CimMethod -MethodName WmiSetBrightness -Arguments @{{Timeout=0;Brightness={percent}}} | Out-Null"
        ))
        .map(drop)
    }
}

impl<R: CommandRunner> DarkModeControl for WindowsSystem<R> {
    fn dark_mode(&self) -> Result<bool, SystemError> {
        let out = self
            .runner
            .run("reg", &["query", PERSONALIZE_KEY, "/v", LIGHT_THEME_VALUE])?;
        let value = out
            .split_whitespace()
            .last()
            .ok_or_else(|| SystemError::Parse(format!("tema: {out:?}")))?;
        Ok(value == "0x0")
    }

    fn set_dark_mode(&self, dark: bool) -> Result<(), SystemError> {
        let value = if dark { "0" } else { "1" };
        for name in [LIGHT_THEME_VALUE, "SystemUsesLightTheme"] {
            self.runner.run(
                "reg",
                &[
                    "add",
                    PERSONALIZE_KEY,
                    "/v",
                    name,
                    "/t",
                    "REG_DWORD",
                    "/d",
                    value,
                    "/f",
                ],
            )?;
        }
        Ok(())
    }
}

impl<R: CommandRunner> BatteryControl for WindowsSystem<R> {
    fn battery(&self) -> Result<Option<Battery>, SystemError> {
        let mut status: SYSTEM_POWER_STATUS = unsafe { std::mem::zeroed() };
        // SAFETY: `status` é uma estrutura válida e exclusiva da chamada.
        if unsafe { GetSystemPowerStatus(&mut status) } == 0 {
            return Err(SystemError::Unavailable("estado da bateria".into()));
        }
        const NO_BATTERY: u8 = 128;
        const CHARGING: u8 = 8;
        const UNKNOWN: u8 = 255;
        if status.BatteryFlag & NO_BATTERY != 0 || status.BatteryLifePercent == UNKNOWN {
            return Ok(None);
        }
        Ok(Some(Battery {
            percent: status.BatteryLifePercent.min(MAX_PERCENT),
            charging: status.BatteryFlag & CHARGING != 0,
        }))
    }
}

impl<R: CommandRunner> PowerControl for WindowsSystem<R> {
    fn perform(&self, action: PowerAction) -> Result<(), SystemError> {
        match action {
            PowerAction::Shutdown => self.runner.run("shutdown", &["/s", "/t", "0"]),
            PowerAction::Reboot => self.runner.run("shutdown", &["/r", "/t", "0"]),
            PowerAction::Suspend => self
                .runner
                .run("rundll32.exe", &["powrprof.dll,SetSuspendState", "0,1,0"]),
            PowerAction::LogOut => self.runner.run("shutdown", &["/l"]),
        }
        .map(drop)
    }
}
