import 'package:gamer_launcher/src/rust/api/catalog.dart';
import 'package:gamer_launcher/src/rust/api/files.dart';
import 'package:gamer_launcher/src/rust/api/settings.dart';
import 'package:gamer_launcher/src/rust/api/system.dart';

/// Falha vinda do núcleo, já com mensagem em português para a tela.
class BackendException implements Exception {
  const BackendException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Tudo o que a UI pede ao núcleo. A UI só conhece esta interface; o app
/// usa a ponte Rust e os testes usam uma implementação falsa.
abstract interface class LauncherBackend {
  LauncherSettings defaultSettings();
  Future<LauncherSettings> loadSettings();
  Future<void> saveSettings(LauncherSettings settings);
  ResolvedTheme resolveTheme(LauncherSettings settings, int minuteOfDay);

  Future<AppCatalog> loadCatalog();

  /// Devolve um aviso quando o app abriu mas algo secundário falhou.
  Future<String?> launchApp(String id);

  Future<List<RecentFile>> listRecents(int limit);
  Future<void> openPath(String path);
  Future<List<String>> listWallpapers(int limit);

  Future<QuickControls> readQuickControls();
  Future<void> setWifiEnabled(bool enabled);
  Future<void> setBluetoothEnabled(bool enabled);
  Future<void> setSystemDarkMode(bool dark);
  Future<void> setVolumePercent(int percent);
  Future<void> setBrightnessPercent(int percent);

  Future<StatsSample> sampleStats();
  Future<String?> userFirstName();
  bool gamepadConnected();
}
