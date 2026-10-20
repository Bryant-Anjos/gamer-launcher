import 'package:gamer_launcher/backend/launcher_backend.dart';
import 'package:gamer_launcher/src/rust/api/catalog.dart' as catalog;
import 'package:gamer_launcher/src/rust/api/files.dart' as files;
import 'package:gamer_launcher/src/rust/api/input.dart' as input;
import 'package:gamer_launcher/src/rust/api/meta.dart' as meta;
import 'package:gamer_launcher/src/rust/api/settings.dart' as settings;
import 'package:gamer_launcher/src/rust/api/sound.dart' as sound;
import 'package:gamer_launcher/src/rust/api/system.dart' as system;

/// A ponte devolve o erro do Rust como `String`; aqui ele vira
/// [BackendException] para a UI tratar de um jeito só.
T _translate<T>(T Function() call) {
  try {
    return call();
  } on String catch (message) {
    throw BackendException(message);
  }
}

Future<T> _guard<T>(Future<T> Function() call) async {
  try {
    return await call();
  } on String catch (message) {
    throw BackendException(message);
  }
}

/// Implementação real: chama o núcleo Rust pela ponte. As funções
/// assíncronas rodam fora da thread da UI.
class RustBackend implements LauncherBackend {
  const RustBackend();

  @override
  settings.LauncherSettings defaultSettings() => settings.defaultSettings();

  @override
  Future<settings.LauncherSettings> loadSettings() =>
      _guard(settings.loadSettings);

  @override
  Future<void> saveSettings(settings.LauncherSettings value) =>
      _guard(() => settings.saveSettings(settings: value));

  @override
  settings.ResolvedTheme resolveTheme(
    settings.LauncherSettings value,
    int minuteOfDay,
  ) => _translate(
    () => settings.resolveTheme(settings: value, minuteOfDay: minuteOfDay),
  );

  @override
  Future<catalog.AppCatalog> loadCatalog() => _guard(catalog.loadCatalog);

  @override
  Future<String?> launchApp(String id) =>
      _guard(() => catalog.launchApp(id: id));

  @override
  Future<List<files.RecentFile>> listRecents(int limit) =>
      _guard(() => files.listRecents(limit: limit));

  @override
  Future<void> openPath(String path) =>
      _guard(() => files.openPath(path: path));

  @override
  Future<List<String>> listWallpapers(int limit) =>
      _guard(() => files.listWallpapers(limit: limit));

  @override
  Future<system.QuickControls> readQuickControls() =>
      _guard(system.readQuickControls);

  @override
  Future<void> setWifiEnabled(bool enabled) =>
      _guard(() => system.setWifiEnabled(enabled: enabled));

  @override
  Future<void> setBluetoothEnabled(bool enabled) =>
      _guard(() => system.setBluetoothEnabled(enabled: enabled));

  @override
  Future<void> setSystemDarkMode(bool dark) =>
      _guard(() => system.setSystemDarkMode(dark: dark));

  @override
  Future<void> setVolumePercent(int percent) =>
      _guard(() => system.setVolumePercent(percent: percent));

  @override
  Future<void> setBrightnessPercent(int percent) =>
      _guard(() => system.setBrightnessPercent(percent: percent));

  @override
  Future<system.BatteryReading?> readBattery() => _guard(system.readBattery);

  @override
  Future<void> performPowerAction(system.PowerAction action) =>
      _guard(() => system.performPowerAction(action: action));

  @override
  Future<bool> autostartEnabled() => _guard(system.autostartEnabled);

  @override
  Future<void> setAutostart(bool enabled) =>
      _guard(() => system.setAutostart(enabled: enabled));

  @override
  Future<List<system.PairedDevice>> listPairedDevices() =>
      _guard(system.listPairedDevices);

  @override
  Future<void> connectBluetoothDevice(String address) =>
      _guard(() => system.connectBluetoothDevice(address: address));

  @override
  Future<void> disconnectBluetoothDevice(String address) =>
      _guard(() => system.disconnectBluetoothDevice(address: address));

  @override
  Future<system.StatsSample> sampleStats() => _guard(system.sampleStats);

  @override
  Future<String?> userFirstName() => _guard(meta.userFirstName);

  @override
  bool gamepadConnected() => _translate(input.gamepadConnected);

  @override
  settings.LauncherButtonLayout detectedButtonLayout() =>
      _translate(input.gamepadDetectedLayout);

  @override
  void setButtonLayout(settings.LauncherButtonLayout layout) =>
      _translate(() => input.gamepadSetLayout(layout: layout));

  @override
  void playUiSound(sound.LauncherSound value) =>
      _translate(() => sound.playUiSound(sound: value));
}
