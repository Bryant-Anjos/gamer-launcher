import 'dart:async';

import 'package:gamer_launcher/backend/launcher_backend.dart';
import 'package:gamer_launcher/src/rust/api/catalog.dart';
import 'package:gamer_launcher/src/rust/api/files.dart';
import 'package:gamer_launcher/src/rust/api/settings.dart';
import 'package:gamer_launcher/src/rust/api/system.dart';

import 'samples.dart';

/// Backend falso: responde com dados combinados, registra as chamadas e
/// falha quando o teste pede ([failures] por nome do método).
class FakeBackend implements LauncherBackend {
  FakeBackend({
    LauncherSettings? settings,
    AppCatalog? catalog,
    List<RecentFile>? recents,
    this.quickControls = sampleQuickControls,
    this.stats = sampleStatsReading,
    this.userName = 'Bryant',
    this.wallpapers = const [],
    this.isGamepadConnected = true,
    this.theme = ResolvedTheme.dark,
    this.battery = const BatteryReading(percent: 80, charging: false),
    this.autostart = false,
    this.pairedDevices = const [],
  }) : settings = settings ?? sampleSettings(),
       catalog = catalog ?? sampleCatalog(),
       recents = recents ?? sampleRecents;

  LauncherSettings settings;
  AppCatalog catalog;
  List<RecentFile> recents;
  QuickControls quickControls;
  StatsSample stats;
  String? userName;
  List<String> wallpapers;
  bool isGamepadConnected;
  ResolvedTheme theme;
  String? launchWarning;
  BatteryReading? battery;
  bool autostart;
  List<PairedDevice> pairedDevices;

  /// Nome do método -> mensagem do erro que ele deve lançar.
  final failures = <String, String>{};
  final calls = <String>[];
  final saved = <LauncherSettings>[];

  /// Nome do método -> portão: a chamada espera até ele ser completado.
  final gates = <String, Completer<void>>{};

  Future<T> _answer<T>(String call, T Function() value) async {
    calls.add(call);
    final method = call.split('(').first;
    await gates[method]?.future;
    final failure = failures[method];
    if (failure != null) throw BackendException(failure);
    return value();
  }

  @override
  LauncherSettings defaultSettings() =>
      sampleSettings(themeMode: LauncherThemeMode.auto, favorites: const []);

  @override
  Future<LauncherSettings> loadSettings() =>
      _answer('loadSettings', () => settings);

  @override
  Future<void> saveSettings(LauncherSettings value) =>
      _answer('saveSettings', () {
        saved.add(value);
        settings = value;
      });

  @override
  ResolvedTheme resolveTheme(LauncherSettings value, int minuteOfDay) {
    calls.add('resolveTheme($minuteOfDay)');
    final failure = failures['resolveTheme'];
    if (failure != null) throw BackendException(failure);
    return switch (value.themeMode) {
      LauncherThemeMode.light => ResolvedTheme.light,
      LauncherThemeMode.dark => ResolvedTheme.dark,
      LauncherThemeMode.auto => theme,
    };
  }

  @override
  Future<AppCatalog> loadCatalog() => _answer('loadCatalog', () => catalog);

  @override
  Future<String?> launchApp(String id) =>
      _answer('launchApp($id)', () => launchWarning);

  @override
  Future<List<RecentFile>> listRecents(int limit) =>
      _answer('listRecents($limit)', () => recents.take(limit).toList());

  @override
  Future<void> openPath(String path) => _answer('openPath($path)', () {});

  @override
  Future<List<String>> listWallpapers(int limit) =>
      _answer('listWallpapers', () => wallpapers);

  @override
  Future<QuickControls> readQuickControls() =>
      _answer('readQuickControls', () => quickControls);

  @override
  Future<void> setWifiEnabled(bool enabled) =>
      _answer('setWifiEnabled($enabled)', () {});

  @override
  Future<void> setBluetoothEnabled(bool enabled) =>
      _answer('setBluetoothEnabled($enabled)', () {});

  @override
  Future<void> setSystemDarkMode(bool dark) =>
      _answer('setSystemDarkMode($dark)', () {});

  @override
  Future<void> setVolumePercent(int percent) =>
      _answer('setVolumePercent($percent)', () {});

  @override
  Future<void> setBrightnessPercent(int percent) =>
      _answer('setBrightnessPercent($percent)', () {});

  @override
  Future<BatteryReading?> readBattery() =>
      _answer('readBattery', () => battery);

  @override
  Future<void> performPowerAction(PowerAction action) =>
      _answer('performPowerAction(${action.name})', () {});

  @override
  Future<bool> autostartEnabled() =>
      _answer('autostartEnabled', () => autostart);

  @override
  Future<void> setAutostart(bool enabled) =>
      _answer('setAutostart($enabled)', () => autostart = enabled);

  @override
  Future<List<PairedDevice>> listPairedDevices() =>
      _answer('listPairedDevices', () => pairedDevices);

  @override
  Future<void> connectBluetoothDevice(String address) =>
      _answer('connectBluetoothDevice($address)', () {});

  @override
  Future<void> disconnectBluetoothDevice(String address) =>
      _answer('disconnectBluetoothDevice($address)', () {});

  @override
  Future<StatsSample> sampleStats() => _answer('sampleStats', () => stats);

  @override
  Future<String?> userFirstName() => _answer('userFirstName', () => userName);

  @override
  bool gamepadConnected() => isGamepadConnected;
}
