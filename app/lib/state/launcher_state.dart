import 'package:gamer_launcher/src/rust/api/catalog.dart';
import 'package:gamer_launcher/src/rust/api/files.dart';
import 'package:gamer_launcher/src/rust/api/settings.dart';

/// Seções da navegação lateral, na ordem em que LB/RB as percorrem.
enum Section {
  home('Início'),
  apps('Aplicativos'),
  games('Jogos'),
  files('Arquivos'),
  settings('Configurações');

  const Section(this.label);

  final String label;
}

const emptyCatalog = AppCatalog(
  apps: [],
  gameLauncherIds: [],
  lastAppId: null,
  musicPlayerId: null,
  warnings: [],
);

/// Estado imutável da tela; o controlador troca por uma cópia a cada mudança.
class LauncherState {
  LauncherState({
    required this.settings,
    this.catalog = emptyCatalog,
    this.recents = const [],
    this.userName,
    this.section = Section.home,
    this.isReady = false,
    this.lastAppId,
  }) : _appsById = {for (final app in catalog.apps) app.id: app};

  final LauncherSettings settings;
  final AppCatalog catalog;
  final List<RecentFile> recents;
  final String? userName;
  final Section section;
  final bool isReady;

  /// Último app aberto; começa pelo histórico e muda a cada abertura.
  final String? lastAppId;
  final Map<String, AppInfo> _appsById;

  AppInfo? appById(String? id) => id == null ? null : _appsById[id];

  AppInfo? get lastApp => appById(lastAppId);

  AppInfo? get musicPlayer => appById(catalog.musicPlayerId);

  List<AppInfo> _existing(Iterable<String> ids) =>
      ids.map(appById).whereType<AppInfo>().toList(growable: false);

  List<AppInfo> get gameLaunchers => _existing(catalog.gameLauncherIds);

  /// Favoritos na ordem escolhida; apps desinstalados somem da tela.
  List<AppInfo> get favoriteApps => _existing(settings.favorites);

  LauncherState copyWith({
    LauncherSettings? settings,
    AppCatalog? catalog,
    List<RecentFile>? recents,
    String? userName,
    Section? section,
    bool? isReady,
    String? lastAppId,
  }) => LauncherState(
    settings: settings ?? this.settings,
    catalog: catalog ?? this.catalog,
    recents: recents ?? this.recents,
    userName: userName ?? this.userName,
    section: section ?? this.section,
    isReady: isReady ?? this.isReady,
    lastAppId: lastAppId ?? this.lastAppId,
  );
}
