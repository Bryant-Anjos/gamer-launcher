//! Bateria (`/sys/class/power_supply`) e ações de energia (systemd/logind).

use super::{Battery, BatteryControl, CommandRunner, LinuxSystem, PowerAction, PowerControl};
use super::{SystemError, parse};
use std::fs;
use std::io;
use std::path::Path;

const MAX_PERCENT: u8 = 100;

fn read_text(path: &Path) -> io::Result<String> {
    fs::read_to_string(path).map(|text| text.trim().to_string())
}

/// Bateria do próprio computador; as de periféricos (controles, fones)
/// também aparecem em `power_supply`, mas com `scope` igual a `Device`.
fn is_system_battery(dir: &Path) -> bool {
    read_text(&dir.join("type")).is_ok_and(|kind| kind == "Battery")
        && read_text(&dir.join("scope")).map_or(true, |scope| scope != "Device")
}

impl<R: CommandRunner> BatteryControl for LinuxSystem<R> {
    fn battery(&self) -> Result<Option<Battery>, SystemError> {
        let Ok(entries) = fs::read_dir(self.power_supply_root()) else {
            return Ok(None);
        };
        let mut dirs: Vec<_> = entries
            .filter_map(Result::ok)
            .map(|entry| entry.path())
            .filter(|dir| is_system_battery(dir))
            .collect();
        dirs.sort();
        let Some(dir) = dirs.first() else {
            return Ok(None);
        };

        let capacity = read_text(&dir.join("capacity"))
            .map_err(|error| SystemError::Io(format!("{}: {error}", dir.display())))?;
        let percent = capacity
            .parse::<u8>()
            .map_err(|_| SystemError::Parse(format!("capacidade da bateria: {capacity:?}")))?;
        let charging = read_text(&dir.join("status")).is_ok_and(|status| status == "Charging");
        Ok(Some(Battery {
            percent: percent.min(MAX_PERCENT),
            charging,
        }))
    }
}

impl<R: CommandRunner> PowerControl for LinuxSystem<R> {
    fn perform(&self, action: PowerAction) -> Result<(), SystemError> {
        match action {
            PowerAction::Shutdown => self.runner().run("systemctl", &["poweroff"]),
            PowerAction::Reboot => self.runner().run("systemctl", &["reboot"]),
            PowerAction::Suspend => self.runner().run("systemctl", &["suspend"]),
            PowerAction::LogOut => {
                let session = parse::session_id(self.session_id())?;
                self.runner()
                    .run("loginctl", &["terminate-session", &session])
            }
        }
        .map(drop)
    }
}
