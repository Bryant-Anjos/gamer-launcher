import 'package:gamer_launcher/src/rust/api/catalog.dart';
import 'package:gamer_launcher/src/rust/api/files.dart';
import 'package:gamer_launcher/src/rust/api/search.dart';
import 'package:gamer_launcher/src/rust/api/settings.dart';
import 'package:gamer_launcher/src/rust/api/sound.dart';
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

  /// `null` quando o computador não tem bateria.
  Future<BatteryReading?> readBattery();
  Future<void> performPowerAction(PowerAction action);

  /// Iniciar com o sistema: o arquivo em `~/.config/autostart` é a verdade.
  Future<bool> autostartEnabled();
  Future<void> setAutostart(bool enabled);

  Future<List<PairedDevice>> listPairedDevices();
  Future<void> connectBluetoothDevice(String address);
  Future<void> disconnectBluetoothDevice(String address);

  /// Lê os recentes para a pesquisa (uma vez, ao abrir a tela de pesquisa).
  Future<void> prepareSearch();

  /// Apps, arquivos recentes e páginas de configurações que batem com
  /// [query], os melhores primeiro.
  Future<List<SearchResult>> search(String query, int limit);

  /// Abre um resultado pelo id devolvido em [search].
  Future<void> openSearchResult(String id);

  /// Abre uma página das configurações do sistema (`bluetooth`, `wireless`).
  Future<void> openSettingsPage(String page);

  Future<StatsSample> sampleStats();
  Future<String?> userFirstName();
  bool gamepadConnected();

  /// Layout que o modo automático escolheu para o último controle usado
  /// (`xbox` ou `nintendo`).
  LauncherButtonLayout detectedButtonLayout();

  /// Troca a disposição dos botões com a leitura do controle rodando.
  void setButtonLayout(LauncherButtonLayout layout);

  /// Toca um som curto da interface sem esperar.
  void playUiSound(LauncherSound sound);
}
