import 'package:gamer_launcher/src/rust/api/catalog.dart';
import 'package:gamer_launcher/src/rust/api/claude.dart';
import 'package:gamer_launcher/src/rust/api/files.dart';
import 'package:gamer_launcher/src/rust/api/settings.dart';
import 'package:gamer_launcher/src/rust/api/system.dart';

/// Dados de exemplo parecidos com os da arte de conceito.

const allPanelsVisible = PanelVisibility(
  search: true,
  quickControls: true,
  system: true,
  recents: true,
  favorites: true,
  featuredCards: true,
  claude: true,
);

LauncherSettings sampleSettings({
  LauncherThemeMode themeMode = LauncherThemeMode.dark,
  List<String>? favorites,
  PanelVisibility panels = allPanelsVisible,
  String? wallpaper,
  LauncherButtonLayout buttonLayout = LauncherButtonLayout.auto,
  bool sounds = false,
  bool reduceAnimations = false,
}) => LauncherSettings(
  themeMode: themeMode,
  darkStartsMinute: 19 * 60,
  lightStartsMinute: 6 * 60,
  wallpaper: wallpaper,
  favorites:
      favorites ??
      const [
        'code.desktop',
        'chrome.desktop',
        'files.desktop',
        'spotify.desktop',
        'discord.desktop',
      ],
  panels: panels,
  buttonLayout: buttonLayout,
  sounds: sounds,
  reduceAnimations: reduceAnimations,
);

AppInfo sampleApp(
  String id,
  String name, {
  List<String> categories = const [],
}) => AppInfo(id: id, name: name, categories: categories);

final sampleApps = [
  sampleApp('chrome.desktop', 'Chrome'),
  sampleApp('discord.desktop', 'Discord'),
  sampleApp('files.desktop', 'Arquivos'),
  sampleApp(
    'spotify.desktop',
    'Spotify',
    categories: ['Audio', 'Music', 'Player'],
  ),
  sampleApp('steam.desktop', 'Steam', categories: ['Game']),
  sampleApp('code.desktop', 'VS Code'),
];

AppCatalog sampleCatalog({
  List<AppInfo>? apps,
  List<String> gameLauncherIds = const ['steam.desktop'],
  String? musicPlayerId = 'spotify.desktop',
  String? lastAppId = 'code.desktop',
  List<String> warnings = const [],
}) => AppCatalog(
  apps: apps ?? sampleApps,
  gameLauncherIds: gameLauncherIds,
  musicPlayerId: musicPlayerId,
  lastAppId: lastAppId,
  warnings: warnings,
);

final sampleRecents = [
  const RecentFile(
    path: '/home/b/Projetos/granspace',
    name: 'granspace',
    location: '~/Projetos',
    modified: '2026-10-16T20:42:00Z',
    isDir: true,
  ),
  const RecentFile(
    path: '/home/b/Projetos/eisaqui',
    name: 'eisaqui',
    location: '~/Projetos',
    modified: '2026-10-16T17:42:00Z',
    isDir: true,
  ),
  const RecentFile(
    path: '/home/b/Documentos/Documentação.docx',
    name: 'Documentação.docx',
    location: '~/Documentos',
    modified: '2026-10-15T22:42:00Z',
    isDir: false,
  ),
];

const sampleQuickControls = QuickControls(
  wifi: ToggleReading(enabled: true),
  wifiName: 'Casa_5G',
  bluetooth: ToggleReading(enabled: true),
  darkMode: ToggleReading(enabled: true),
  volume: LevelReading(percent: 80, muted: false),
  brightness: LevelReading(percent: 60, muted: false),
);

const sampleStatsReading = StatsSample(
  cpuPercent: 12,
  ramUsedBytes: 4.2e9,
  ramTotalBytes: 16e9,
  diskUsedBytes: 120e9,
  diskTotalBytes: 500e9,
);

/// Nada pôde ser lido: tudo indisponível.
const offlineQuickControls = QuickControls(
  wifi: ToggleReading(error: 'nmcli falhou'),
  bluetooth: ToggleReading(error: 'indisponível: sem adaptador bluetooth'),
  darkMode: ToggleReading(error: 'o COSMIC ainda não gravou o tema'),
  volume: LevelReading(muted: false, error: 'wpctl falhou'),
  brightness: LevelReading(muted: false, error: 'sem controle de brilho'),
);

const _noTotals = ClaudeTotals(
  replies: 0,
  toolCalls: 0,
  sessions: 0,
  inputTokens: 0,
  outputTokens: 0,
);

const emptyClaudeStats = ClaudeStats(
  today: _noTotals,
  week: _noTotals,
  todayModels: [],
  days: [],
);

const sampleClaudeNow = ClaudeNow(
  version: '2.1.304',
  sessions: [
    ClaudeSession(
      sessionId: 's1',
      project: 'gamer-launcher',
      title: 'Painel do Claude',
      status: ClaudeSessionStatus.busy,
      model: 'claude-opus-5',
      branch: 'main',
      agents: [
        ClaudeAgent(
          agentType: 'Explore',
          description: 'Achar o leitor de sessões',
          running: true,
        ),
        ClaudeAgent(
          agentType: 'general-purpose',
          description: 'Revisar o código',
          running: false,
        ),
      ],
    ),
    ClaudeSession(
      sessionId: 's2',
      project: 'homeflix',
      status: ClaudeSessionStatus.idle,
      agents: [],
    ),
  ],
);

const sampleClaudeStats = ClaudeStats(
  today: ClaudeTotals(
    replies: 298,
    toolCalls: 311,
    sessions: 2,
    inputTokens: 1200000,
    outputTokens: 34000,
  ),
  week: ClaudeTotals(
    replies: 601,
    toolCalls: 700,
    sessions: 5,
    inputTokens: 5600000,
    outputTokens: 90000,
  ),
  todayModels: [
    ClaudeModelTokens(
      model: 'claude-opus-5',
      inputTokens: 1200000,
      outputTokens: 34000,
    ),
  ],
  days: [
    ClaudeDayPoint(date: '2026-10-13', sessions: 1, replies: 10),
    ClaudeDayPoint(date: '2026-10-14', sessions: 0, replies: 0),
    ClaudeDayPoint(date: '2026-10-15', sessions: 2, replies: 80),
    ClaudeDayPoint(date: '2026-10-16', sessions: 1, replies: 40),
    ClaudeDayPoint(date: '2026-10-17', sessions: 3, replies: 120),
    ClaudeDayPoint(date: '2026-10-18', sessions: 1, replies: 53),
    ClaudeDayPoint(date: '2026-10-19', sessions: 2, replies: 298),
  ],
  history: ClaudeHistory(
    since: '2026-06-01',
    until: '2026-10-13',
    sessions: 40,
    messages: 900,
    models: [],
  ),
);
