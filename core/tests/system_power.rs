mod common;

use common::FakeRunner;
use launcher_core::system::{
    Battery, BatteryControl, LinuxSystem, PowerAction, PowerControl, SystemError,
};
use std::fs;
use std::path::Path;
use std::sync::Arc;
use tempfile::tempdir;

fn system(
    runner: FakeRunner,
    power_supply: &Path,
    session: Option<&str>,
) -> (LinuxSystem<Arc<FakeRunner>>, Arc<FakeRunner>) {
    let runner = Arc::new(runner);
    let system = LinuxSystem::with_paths(runner.clone(), "/nada".into(), "/nada".into())
        .with_power_supply_root(power_supply.to_path_buf())
        .with_session_id(session.map(String::from));
    (system, runner)
}

fn supply(root: &Path, name: &str, files: &[(&str, &str)]) {
    let dir = root.join(name);
    fs::create_dir_all(&dir).unwrap();
    for (file, content) in files {
        fs::write(dir.join(file), content).unwrap();
    }
}

fn battery_files<'a>(capacity: &'a str, status: &'a str) -> Vec<(&'a str, &'a str)> {
    vec![
        ("type", "Battery\n"),
        ("capacity", capacity),
        ("status", status),
    ]
}

#[test]
fn the_battery_reports_its_percentage_and_whether_it_is_charging() {
    let root = tempdir().unwrap();
    supply(root.path(), "BAT0", &battery_files("73\n", "Charging\n"));
    let (system, _) = system(FakeRunner::new(), root.path(), None);

    assert_eq!(
        system.battery().unwrap(),
        Some(Battery {
            percent: 73,
            charging: true
        })
    );
}

#[test]
fn a_discharging_or_full_battery_is_not_charging() {
    for status in ["Discharging\n", "Full\n", "Not charging\n", "Unknown\n"] {
        let root = tempdir().unwrap();
        supply(root.path(), "BAT0", &battery_files("50\n", status));
        let (system, _) = system(FakeRunner::new(), root.path(), None);

        let battery = system.battery().unwrap().unwrap();

        assert!(!battery.charging, "{status:?}");
    }
}

#[test]
fn a_desktop_without_battery_gives_none_not_an_error() {
    let root = tempdir().unwrap();
    supply(root.path(), "AC", &[("type", "Mains\n"), ("online", "1\n")]);
    let (system, _) = system(FakeRunner::new(), root.path(), None);

    assert_eq!(system.battery().unwrap(), None);
}

#[test]
fn a_missing_power_supply_folder_means_no_battery() {
    let root = tempdir().unwrap();
    let (system, _) = system(FakeRunner::new(), &root.path().join("nao-existe"), None);

    assert_eq!(system.battery().unwrap(), None);
}

#[test]
fn a_controller_battery_is_not_the_computer_battery() {
    let root = tempdir().unwrap();
    let mut pad = battery_files("90\n", "Discharging\n");
    pad.push(("scope", "Device\n"));
    supply(root.path(), "nintendo_switch_controller_battery_1", &pad);
    let (system, _) = system(FakeRunner::new(), root.path(), None);

    assert_eq!(system.battery().unwrap(), None);
}

#[test]
fn with_several_batteries_the_first_by_name_is_used() {
    let root = tempdir().unwrap();
    supply(root.path(), "BAT1", &battery_files("10\n", "Discharging\n"));
    supply(root.path(), "BAT0", &battery_files("80\n", "Discharging\n"));
    let (system, _) = system(FakeRunner::new(), root.path(), None);

    assert_eq!(system.battery().unwrap().unwrap().percent, 80);
}

#[test]
fn a_percentage_above_100_is_capped() {
    let root = tempdir().unwrap();
    supply(root.path(), "BAT0", &battery_files("104\n", "Full\n"));
    let (system, _) = system(FakeRunner::new(), root.path(), None);

    assert_eq!(system.battery().unwrap().unwrap().percent, 100);
}

#[test]
fn a_garbled_capacity_is_a_parse_error() {
    let root = tempdir().unwrap();
    supply(
        root.path(),
        "BAT0",
        &battery_files("abc\n", "Discharging\n"),
    );
    let (system, _) = system(FakeRunner::new(), root.path(), None);

    assert!(matches!(system.battery(), Err(SystemError::Parse(_))));
}

#[test]
fn power_actions_call_systemctl_and_loginctl() {
    let cases = [
        (PowerAction::Shutdown, "systemctl poweroff"),
        (PowerAction::Reboot, "systemctl reboot"),
        (PowerAction::Suspend, "systemctl suspend"),
        (PowerAction::LogOut, "loginctl terminate-session 3"),
    ];
    for (action, command) in cases {
        let root = tempdir().unwrap();
        let (system, runner) = system(FakeRunner::new().reply(command, ""), root.path(), Some("3"));

        system.perform(action).unwrap();

        assert_eq!(runner.calls(), [command], "{action:?}");
    }
}

#[test]
fn logging_out_without_a_session_id_is_unavailable_and_runs_nothing() {
    let root = tempdir().unwrap();
    let (system, runner) = system(FakeRunner::new(), root.path(), None);

    let result = system.perform(PowerAction::LogOut);

    assert!(matches!(result, Err(SystemError::Unavailable(_))));
    assert!(runner.calls().is_empty());
}

#[test]
fn a_session_id_with_odd_characters_is_refused_before_reaching_loginctl() {
    let root = tempdir().unwrap();
    let (system, runner) = system(FakeRunner::new(), root.path(), Some("--help"));

    assert!(system.perform(PowerAction::LogOut).is_err());
    assert!(runner.calls().is_empty());
}

#[test]
fn a_refused_power_action_is_an_error_with_the_reason() {
    let root = tempdir().unwrap();
    let denied = SystemError::CommandFailed {
        program: "systemctl".into(),
        message: "Interactive authentication required.".into(),
    };
    let (system, _) = system(
        FakeRunner::new().fail("systemctl poweroff", denied.clone()),
        root.path(),
        None,
    );

    assert_eq!(system.perform(PowerAction::Shutdown), Err(denied));
}
