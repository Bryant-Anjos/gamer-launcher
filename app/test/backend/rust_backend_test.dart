import 'package:flutter_test/flutter_test.dart';
import 'package:gamer_launcher/backend/launcher_backend.dart';
import 'package:gamer_launcher/backend/rust_backend.dart';
import 'package:gamer_launcher/src/rust/api/catalog.dart';
import 'package:gamer_launcher/src/rust/api/files.dart';
import 'package:gamer_launcher/src/rust/api/settings.dart';
import 'package:gamer_launcher/src/rust/api/system.dart';
import 'package:gamer_launcher/src/rust/frb_generated.dart';

import '../support/samples.dart';

/// Ponte falsa: cada função gerada registra a chamada e responde com um
/// valor fixo; um texto em [errors] é lançado como o Rust faria com
/// `Err(String)`.
class _MockApi implements RustLibApi {
  final calls = <String>[];
  final errors = <String, String>{};

  T _sync<T>(String name, T value) {
    calls.add(name);
    final error = errors[name];
    if (error != null) throw error;
    return value;
  }

  Future<T> _async<T>(String name, T value) async => _sync(name, value);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  @override
  LauncherSettings crateApiSettingsDefaultSettings() =>
      _sync('defaultSettings', sampleSettings());

  @override
  Future<LauncherSettings> crateApiSettingsLoadSettings() =>
      _async('loadSettings', sampleSettings());

  @override
  Future<void> crateApiSettingsSaveSettings({
    required LauncherSettings settings,
  }) => _async('saveSettings', null);

  @override
  ResolvedTheme crateApiSettingsResolveTheme({
    required LauncherSettings settings,
    required int minuteOfDay,
  }) => _sync('resolveTheme', ResolvedTheme.light);

  @override
  Future<AppCatalog> crateApiCatalogLoadCatalog() =>
      _async('loadCatalog', sampleCatalog());

  @override
  Future<String?> crateApiCatalogLaunchApp({required String id}) =>
      _async('launchApp', 'aviso');

  @override
  Future<List<RecentFile>> crateApiFilesListRecents({required int limit}) =>
      _async('listRecents', sampleRecents);

  @override
  Future<void> crateApiFilesOpenPath({required String path}) =>
      _async('openPath', null);

  @override
  Future<List<String>> crateApiFilesListWallpapers({required int limit}) =>
      _async('listWallpapers', ['/a.png']);

  @override
  Future<QuickControls> crateApiSystemReadQuickControls() =>
      _async('readQuickControls', sampleQuickControls);

  @override
  Future<void> crateApiSystemSetWifiEnabled({required bool enabled}) =>
      _async('setWifiEnabled', null);

  @override
  Future<void> crateApiSystemSetBluetoothEnabled({required bool enabled}) =>
      _async('setBluetoothEnabled', null);

  @override
  Future<void> crateApiSystemSetSystemDarkMode({required bool dark}) =>
      _async('setSystemDarkMode', null);

  @override
  Future<void> crateApiSystemSetVolumePercent({required int percent}) =>
      _async('setVolumePercent', null);

  @override
  Future<void> crateApiSystemSetBrightnessPercent({required int percent}) =>
      _async('setBrightnessPercent', null);

  @override
  Future<StatsSample> crateApiSystemSampleStats() =>
      _async('sampleStats', sampleStatsReading);

  @override
  Future<String?> crateApiMetaUserFirstName() =>
      _async('userFirstName', 'Bryant');

  @override
  bool crateApiInputGamepadConnected() => _sync('gamepadConnected', true);
}

void main() {
  final api = _MockApi();
  const backend = RustBackend();

  setUpAll(() => RustLib.initMock(api: api));
  setUp(() {
    api.calls.clear();
    api.errors.clear();
  });

  test('every call goes to its bridge function', () async {
    expect(backend.defaultSettings(), sampleSettings());
    expect(await backend.loadSettings(), sampleSettings());
    await backend.saveSettings(sampleSettings());
    expect(backend.resolveTheme(sampleSettings(), 60), ResolvedTheme.light);
    expect((await backend.loadCatalog()).apps, isNotEmpty);
    expect(await backend.launchApp('a'), 'aviso');
    expect(await backend.listRecents(3), sampleRecents);
    await backend.openPath('/x');
    expect(await backend.listWallpapers(5), ['/a.png']);
    expect(await backend.readQuickControls(), sampleQuickControls);
    await backend.setWifiEnabled(true);
    await backend.setBluetoothEnabled(false);
    await backend.setSystemDarkMode(true);
    await backend.setVolumePercent(10);
    await backend.setBrightnessPercent(20);
    expect(await backend.sampleStats(), sampleStatsReading);
    expect(await backend.userFirstName(), 'Bryant');
    expect(backend.gamepadConnected(), isTrue);

    expect(api.calls, hasLength(18));
    expect(api.calls.toSet(), hasLength(18), reason: 'uma função por método');
  });

  test('a Rust error string becomes a BackendException', () async {
    api.errors['launchApp'] = 'programa não encontrado';

    await expectLater(
      backend.launchApp('x'),
      throwsA(
        isA<BackendException>().having(
          (e) => e.message,
          'message',
          'programa não encontrado',
        ),
      ),
    );
  });

  test('sync calls translate errors too', () {
    api.errors['resolveTheme'] = 'horário inválido';

    expect(
      () => backend.resolveTheme(sampleSettings(), 9999),
      throwsA(isA<BackendException>()),
    );
  });

  test('the exception prints its message', () {
    expect(const BackendException('falhou').toString(), 'falhou');
  });
}
