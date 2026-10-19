mod common;

use common::FakeRunner;
use launcher_core::system::{
    BluetoothDevice, BluetoothDevices, CommandRunner, LinuxSystem, ProcessRunner, SystemError,
};
use std::sync::Arc;
use std::time::Duration;

const PAD: &str = "AA:BB:CC:DD:EE:9D";
const SPEAKER: &str = "11:22:33:44:55:75";

fn system(runner: FakeRunner) -> (LinuxSystem<Arc<FakeRunner>>, Arc<FakeRunner>) {
    let runner = Arc::new(runner);
    let system = LinuxSystem::with_paths(runner.clone(), "/nada".into(), "/nada".into());
    (system, runner)
}

fn listing(paired: &str, connected: &str) -> FakeRunner {
    FakeRunner::new()
        .reply("bluetoothctl devices Paired", paired)
        .reply("bluetoothctl devices Connected", connected)
}

fn device(address: &str, name: &str, connected: bool) -> BluetoothDevice {
    BluetoothDevice {
        address: address.into(),
        name: name.into(),
        connected,
    }
}

#[test]
fn paired_devices_come_with_their_connection_state_connected_first() {
    let (system, _) = system(listing(
        &format!("Device {SPEAKER} i12\nDevice {PAD} Pro Controller\n"),
        &format!("Device {PAD} Pro Controller\n"),
    ));

    let devices = system.paired_devices().unwrap();

    assert_eq!(
        devices,
        vec![
            device(PAD, "Pro Controller", true),
            device(SPEAKER, "i12", false),
        ]
    );
}

#[test]
fn devices_with_the_same_state_are_sorted_by_name() {
    let (system, _) = system(listing(
        &format!("Device {SPEAKER} zeta\nDevice {PAD} Alfa\n"),
        "",
    ));

    let names: Vec<_> = system
        .paired_devices()
        .unwrap()
        .into_iter()
        .map(|d| d.name)
        .collect();

    assert_eq!(names, ["Alfa", "zeta"]);
}

#[test]
fn names_may_contain_spaces_and_unicode() {
    let (system, _) = system(listing(
        &format!("Device {PAD} Caixa de Som da Sala ♪\n"),
        "",
    ));

    assert_eq!(
        system.paired_devices().unwrap()[0].name,
        "Caixa de Som da Sala ♪"
    );
}

#[test]
fn no_paired_devices_is_an_empty_list() {
    let (system, _) = system(listing("", ""));

    assert!(system.paired_devices().unwrap().is_empty());
}

#[test]
fn unrelated_lines_are_ignored() {
    let (system, _) = system(listing(
        &format!("[CHG] Controller X\nDevice {PAD} Pro Controller\nDevice nao-e-endereco Nome\n"),
        "",
    ));

    assert_eq!(
        system.paired_devices().unwrap(),
        vec![device(PAD, "Pro Controller", false)]
    );
}

#[test]
fn a_missing_adapter_is_unavailable() {
    let (system, _) = system(listing("No default controller available\n", ""));

    assert!(matches!(
        system.paired_devices(),
        Err(SystemError::Unavailable(_))
    ));
}

#[test]
fn connecting_runs_bluetoothctl_with_the_address() {
    let (system, runner) = system(FakeRunner::new().reply(
        &format!("bluetoothctl connect {PAD}"),
        "Attempting to connect to AA:BB:CC:DD:EE:9D\nConnection successful\n",
    ));

    system.connect_device(PAD).unwrap();

    assert_eq!(runner.calls(), [format!("bluetoothctl connect {PAD}")]);
}

#[test]
fn a_failure_printed_in_the_output_is_an_error() {
    let (system, _) = system(FakeRunner::new().reply(
        &format!("bluetoothctl connect {PAD}"),
        "Attempting to connect to AA:BB:CC:DD:EE:9D\nFailed to connect: org.bluez.Error.Failed\n",
    ));

    let error = system.connect_device(PAD).unwrap_err();

    assert!(matches!(error, SystemError::CommandFailed { .. }));
    assert!(error.to_string().contains("Failed to connect"));
}

#[test]
fn a_command_failure_is_passed_on() {
    let failure = SystemError::Timeout {
        program: "bluetoothctl".into(),
        seconds: 15,
    };
    let (system, _) =
        system(FakeRunner::new().fail(&format!("bluetoothctl connect {PAD}"), failure.clone()));

    assert_eq!(system.connect_device(PAD).unwrap_err(), failure);
}

#[test]
fn disconnecting_runs_bluetoothctl_with_the_address() {
    let (system, runner) = system(FakeRunner::new().reply(
        &format!("bluetoothctl disconnect {PAD}"),
        "Successful disconnected\n",
    ));

    system.disconnect_device(PAD).unwrap();

    assert_eq!(runner.calls(), [format!("bluetoothctl disconnect {PAD}")]);
}

#[test]
fn a_failed_disconnect_in_the_output_is_an_error() {
    let (system, _) = system(FakeRunner::new().reply(
        &format!("bluetoothctl disconnect {PAD}"),
        "Failed to disconnect: org.bluez.Error.NotConnected\n",
    ));

    assert!(system.disconnect_device(PAD).is_err());
}

#[test]
fn addresses_are_validated_before_anything_runs() {
    for bad in [
        "--help",
        "AA:BB",
        "AA:BB:CC:DD:EE:9D; rm -rf /",
        "",
        "-c",
        "AA:BB:CC:DD:EE:ZZ",
    ] {
        let (system, runner) = system(FakeRunner::new());

        assert!(
            matches!(system.connect_device(bad), Err(SystemError::Parse(_))),
            "{bad:?}"
        );
        assert!(
            matches!(system.disconnect_device(bad), Err(SystemError::Parse(_))),
            "{bad:?}"
        );
        assert!(runner.calls().is_empty(), "{bad:?} chegou a rodar algo");
    }
}

#[test]
fn lowercase_addresses_are_accepted_and_normalized() {
    let (system, runner) = system(FakeRunner::new().reply(
        &format!("bluetoothctl connect {PAD}"),
        "Connection successful\n",
    ));

    system.connect_device(&PAD.to_lowercase()).unwrap();

    assert_eq!(runner.calls(), [format!("bluetoothctl connect {PAD}")]);
}

#[test]
fn a_custom_timeout_is_honored_by_the_real_runner() {
    let runner = ProcessRunner::default();

    let error = runner
        .run_with_timeout("sleep", &["5"], Duration::from_millis(200))
        .unwrap_err();

    assert!(matches!(error, SystemError::Timeout { .. }));
}

#[test]
fn the_custom_timeout_does_not_cut_a_command_that_finishes_in_time() {
    let output = ProcessRunner::with_timeout(Duration::from_millis(50))
        .run_with_timeout("echo", &["ok"], Duration::from_secs(5))
        .unwrap();

    assert_eq!(output, "ok\n");
}
