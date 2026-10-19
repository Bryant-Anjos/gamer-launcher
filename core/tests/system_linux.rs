mod common;

use common::FakeRunner;
use launcher_core::system::{
    AudioControl, BluetoothControl, BrightnessControl, DarkModeControl, LinuxSystem, SystemError,
    WifiControl,
};
use std::fs;
use std::path::Path;
use std::sync::Arc;
use tempfile::tempdir;

fn system_with(runner: FakeRunner) -> (LinuxSystem<Arc<FakeRunner>>, Arc<FakeRunner>) {
    let runner = Arc::new(runner);
    let dir = tempdir().unwrap().keep();
    let system =
        LinuxSystem::with_paths(runner.clone(), dir.join("backlight"), dir.join("is_dark"));
    (system, runner)
}

fn backlight(root: &Path, name: &str, current: &str, max: &str) {
    let device = root.join(name);
    fs::create_dir_all(&device).unwrap();
    fs::write(device.join("brightness"), format!("{current}\n")).unwrap();
    fs::write(device.join("max_brightness"), format!("{max}\n")).unwrap();
}

// ---------- Wi-Fi ----------

#[test]
fn wifi_radio_state_is_parsed() {
    for (text, expected) in [("enabled\n", true), ("disabled\n", false)] {
        let (system, _) = system_with(FakeRunner::new().reply("nmcli radio wifi", text));

        assert_eq!(system.wifi_enabled().unwrap(), expected);
    }
}

#[test]
fn unexpected_wifi_output_is_a_parse_error() {
    let (system, _) = system_with(FakeRunner::new().reply("nmcli radio wifi", "???"));

    assert!(matches!(system.wifi_enabled(), Err(SystemError::Parse(_))));
}

#[test]
fn wifi_is_switched_with_nmcli() {
    let (system, runner) = system_with(
        FakeRunner::new()
            .reply("nmcli radio wifi on", "")
            .reply("nmcli radio wifi off", ""),
    );

    system.set_wifi_enabled(true).unwrap();
    system.set_wifi_enabled(false).unwrap();

    assert_eq!(
        runner.calls(),
        ["nmcli radio wifi on", "nmcli radio wifi off"]
    );
}

#[test]
fn connected_ssid_picks_the_active_network() {
    let (system, _) = system_with(FakeRunner::new().reply(
        "nmcli -t -f ACTIVE,SSID dev wifi",
        "no:Vizinho\nyes:Casa_5G\n",
    ));

    assert_eq!(system.connected_ssid().unwrap().as_deref(), Some("Casa_5G"));
}

#[test]
fn connected_ssid_unescapes_colons() {
    let (system, _) = system_with(
        FakeRunner::new().reply("nmcli -t -f ACTIVE,SSID dev wifi", "yes:Meu\\:Wifi\n"),
    );

    assert_eq!(
        system.connected_ssid().unwrap().as_deref(),
        Some("Meu:Wifi")
    );
}

#[test]
fn no_active_network_gives_none() {
    let (system, _) = system_with(
        FakeRunner::new().reply("nmcli -t -f ACTIVE,SSID dev wifi", "no:Vizinho\nyes:\n"),
    );

    assert_eq!(system.connected_ssid().unwrap(), None);
}

// ---------- Bluetooth ----------

#[test]
fn bluetooth_state_comes_from_the_powered_line() {
    for (text, expected) in [
        ("Controller AA:BB\n\tPowered: yes\n\tPairable: yes\n", true),
        ("Controller AA:BB\n\tPowered: no\n", false),
    ] {
        let (system, _) = system_with(FakeRunner::new().reply("bluetoothctl show", text));

        assert_eq!(system.bluetooth_enabled().unwrap(), expected);
    }
}

#[test]
fn missing_bluetooth_adapter_is_unavailable() {
    let (system, _) = system_with(
        FakeRunner::new().reply("bluetoothctl show", "No default controller available\n"),
    );

    assert!(matches!(
        system.bluetooth_enabled(),
        Err(SystemError::Unavailable(_))
    ));
}

#[test]
fn turning_bluetooth_on_unblocks_the_radio_first() {
    let (system, runner) = system_with(
        FakeRunner::new()
            .reply("rfkill unblock bluetooth", "")
            .reply("bluetoothctl power on", "Changing power on succeeded\n"),
    );

    system.set_bluetooth_enabled(true).unwrap();

    assert_eq!(
        runner.calls(),
        ["rfkill unblock bluetooth", "bluetoothctl power on"]
    );
}

#[test]
fn turning_bluetooth_off_only_powers_it_down() {
    let (system, runner) = system_with(
        FakeRunner::new().reply("bluetoothctl power off", "Changing power off succeeded\n"),
    );

    system.set_bluetooth_enabled(false).unwrap();

    assert_eq!(runner.calls(), ["bluetoothctl power off"]);
}

// ---------- Áudio ----------

const GET_VOLUME: &str = "wpctl get-volume @DEFAULT_AUDIO_SINK@";

#[test]
fn volume_is_read_as_a_percentage() {
    let (system, _) = system_with(FakeRunner::new().reply(GET_VOLUME, "Volume: 0.37\n"));

    let volume = system.volume().unwrap();

    assert_eq!(volume.percent, 37);
    assert!(!volume.muted);
}

#[test]
fn muted_volume_is_flagged() {
    let (system, _) = system_with(FakeRunner::new().reply(GET_VOLUME, "Volume: 1.00 [MUTED]\n"));

    let volume = system.volume().unwrap();

    assert_eq!(volume.percent, 100);
    assert!(volume.muted);
}

#[test]
fn boosted_volume_is_capped_at_one_hundred() {
    let (system, _) = system_with(FakeRunner::new().reply(GET_VOLUME, "Volume: 1.20\n"));

    assert_eq!(system.volume().unwrap().percent, 100);
}

#[test]
fn garbage_volume_output_is_a_parse_error() {
    let (system, _) = system_with(FakeRunner::new().reply(GET_VOLUME, "nada\n"));

    assert!(matches!(system.volume(), Err(SystemError::Parse(_))));
}

#[test]
fn volume_is_set_as_a_fraction_and_never_above_one() {
    let (system, runner) = system_with(
        FakeRunner::new()
            .reply("wpctl set-volume @DEFAULT_AUDIO_SINK@ 0.45", "")
            .reply("wpctl set-volume @DEFAULT_AUDIO_SINK@ 1.00", ""),
    );

    system.set_volume_percent(45).unwrap();
    system.set_volume_percent(250).unwrap();

    assert_eq!(
        runner.calls(),
        [
            "wpctl set-volume @DEFAULT_AUDIO_SINK@ 0.45",
            "wpctl set-volume @DEFAULT_AUDIO_SINK@ 1.00"
        ]
    );
}

#[test]
fn mute_is_toggled_explicitly() {
    let (system, runner) = system_with(
        FakeRunner::new()
            .reply("wpctl set-mute @DEFAULT_AUDIO_SINK@ 1", "")
            .reply("wpctl set-mute @DEFAULT_AUDIO_SINK@ 0", ""),
    );

    system.set_muted(true).unwrap();
    system.set_muted(false).unwrap();

    assert_eq!(
        runner.calls(),
        [
            "wpctl set-mute @DEFAULT_AUDIO_SINK@ 1",
            "wpctl set-mute @DEFAULT_AUDIO_SINK@ 0"
        ]
    );
}

// ---------- Brilho ----------

#[test]
fn brightness_is_a_percentage_of_the_maximum() {
    let dir = tempdir().unwrap();
    backlight(dir.path(), "intel_backlight", "400", "1000");
    let system = LinuxSystem::with_paths(
        Arc::new(FakeRunner::new()),
        dir.path().to_path_buf(),
        dir.path().join("is_dark"),
    );

    assert_eq!(system.brightness_percent().unwrap(), 40);
}

#[test]
fn brightness_is_written_through_logind() {
    let dir = tempdir().unwrap();
    backlight(dir.path(), "intel_backlight", "400", "1000");
    let call = "busctl call org.freedesktop.login1 /org/freedesktop/login1/session/auto \
org.freedesktop.login1.Session SetBrightness ssu backlight intel_backlight 500";
    let runner = Arc::new(FakeRunner::new().reply(call, ""));
    let system = LinuxSystem::with_paths(
        runner.clone(),
        dir.path().to_path_buf(),
        dir.path().join("is_dark"),
    );

    system.set_brightness_percent(50).unwrap();

    assert_eq!(runner.calls(), [call]);
}

#[test]
fn brightness_never_goes_fully_dark() {
    let dir = tempdir().unwrap();
    backlight(dir.path(), "intel_backlight", "400", "1000");
    let call = "busctl call org.freedesktop.login1 /org/freedesktop/login1/session/auto \
org.freedesktop.login1.Session SetBrightness ssu backlight intel_backlight 10";
    let runner = Arc::new(FakeRunner::new().reply(call, ""));
    let system = LinuxSystem::with_paths(
        runner.clone(),
        dir.path().to_path_buf(),
        dir.path().join("is_dark"),
    );

    system.set_brightness_percent(0).unwrap();

    assert_eq!(runner.calls(), [call]);
}

#[test]
fn machines_without_a_backlight_report_unavailable() {
    let dir = tempdir().unwrap();
    let system = LinuxSystem::with_paths(
        Arc::new(FakeRunner::new()),
        dir.path().join("missing"),
        dir.path().join("is_dark"),
    );

    assert!(matches!(
        system.brightness_percent(),
        Err(SystemError::Unavailable(_))
    ));
    assert!(matches!(
        system.set_brightness_percent(50),
        Err(SystemError::Unavailable(_))
    ));
}

// ---------- Modo escuro ----------

#[test]
fn dark_mode_is_read_from_the_cosmic_file() {
    for (text, expected) in [("true\n", true), ("false", false)] {
        let dir = tempdir().unwrap();
        let file = dir.path().join("is_dark");
        fs::write(&file, text).unwrap();
        let system = LinuxSystem::with_paths(Arc::new(FakeRunner::new()), dir.path().into(), file);

        assert_eq!(system.dark_mode().unwrap(), expected);
    }
}

#[test]
fn missing_or_odd_dark_mode_file_is_reported() {
    let dir = tempdir().unwrap();
    let file = dir.path().join("is_dark");
    let system =
        LinuxSystem::with_paths(Arc::new(FakeRunner::new()), dir.path().into(), file.clone());
    assert!(matches!(
        system.dark_mode(),
        Err(SystemError::Unavailable(_))
    ));

    fs::write(&file, "talvez").unwrap();
    assert!(matches!(system.dark_mode(), Err(SystemError::Parse(_))));
}

#[test]
fn dark_mode_is_written_and_directories_are_created() {
    let dir = tempdir().unwrap();
    let file = dir.path().join("deep/er/is_dark");
    let system =
        LinuxSystem::with_paths(Arc::new(FakeRunner::new()), dir.path().into(), file.clone());

    system.set_dark_mode(false).unwrap();
    assert_eq!(fs::read_to_string(&file).unwrap(), "false");
    assert!(!system.dark_mode().unwrap());

    system.set_dark_mode(true).unwrap();
    assert_eq!(fs::read_to_string(&file).unwrap(), "true");
}

// ---------- Resumo ----------

#[test]
fn one_failing_control_does_not_hide_the_others() {
    let dir = tempdir().unwrap();
    backlight(dir.path(), "intel_backlight", "500", "1000");
    let dark = dir.path().join("is_dark");
    fs::write(&dark, "true").unwrap();
    let runner = Arc::new(
        FakeRunner::new()
            .reply("nmcli radio wifi", "enabled\n")
            .reply("nmcli -t -f ACTIVE,SSID dev wifi", "yes:Casa\n")
            .fail(
                "bluetoothctl show",
                SystemError::Unavailable("sem adaptador".into()),
            )
            .reply(GET_VOLUME, "Volume: 0.80\n"),
    );
    let system = LinuxSystem::with_paths(runner, dir.path().to_path_buf(), dark);

    let snapshot = system.snapshot();

    assert!(snapshot.wifi.as_ref().unwrap().enabled);
    assert_eq!(
        snapshot.wifi.as_ref().unwrap().ssid.as_deref(),
        Some("Casa")
    );
    assert!(snapshot.bluetooth.is_err());
    assert_eq!(snapshot.volume.as_ref().unwrap().percent, 80);
    assert_eq!(*snapshot.brightness.as_ref().unwrap(), 50);
    assert!(*snapshot.dark_mode.as_ref().unwrap());
}
