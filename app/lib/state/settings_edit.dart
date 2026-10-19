import 'package:gamer_launcher/src/rust/api/settings.dart';

/// Painéis da tela inicial que o usuário pode esconder.
enum PanelKind {
  search('Pesquisa'),
  featuredCards('Cartões de destaque'),
  quickControls('Controle rápido'),
  favorites('Aplicativos favoritos'),
  recents('Recentes'),
  system('Sistema');

  const PanelKind(this.label);

  final String label;

  bool isVisibleIn(LauncherSettings settings) {
    final panels = settings.panels;
    return switch (this) {
      PanelKind.search => panels.search,
      PanelKind.featuredCards => panels.featuredCards,
      PanelKind.quickControls => panels.quickControls,
      PanelKind.favorites => panels.favorites,
      PanelKind.recents => panels.recents,
      PanelKind.system => panels.system,
    };
  }
}

PanelVisibility _withPanel(
  PanelVisibility p,
  PanelKind kind,
  bool visible,
) => PanelVisibility(
  search: kind == PanelKind.search ? visible : p.search,
  quickControls: kind == PanelKind.quickControls ? visible : p.quickControls,
  system: kind == PanelKind.system ? visible : p.system,
  recents: kind == PanelKind.recents ? visible : p.recents,
  favorites: kind == PanelKind.favorites ? visible : p.favorites,
  featuredCards: kind == PanelKind.featuredCards ? visible : p.featuredCards,
);

/// Edição imutável das configurações: cada método devolve uma cópia.
/// A validação final fica no núcleo, ao gravar.
extension LauncherSettingsEdit on LauncherSettings {
  LauncherSettings copyWith({
    LauncherThemeMode? themeMode,
    int? darkStartsMinute,
    int? lightStartsMinute,
    List<String>? favorites,
    PanelVisibility? panels,
  }) => LauncherSettings(
    themeMode: themeMode ?? this.themeMode,
    darkStartsMinute: darkStartsMinute ?? this.darkStartsMinute,
    lightStartsMinute: lightStartsMinute ?? this.lightStartsMinute,
    wallpaper: wallpaper,
    favorites: favorites ?? this.favorites,
    panels: panels ?? this.panels,
  );

  /// `null` volta ao fundo liso do tema.
  LauncherSettings withWallpaper(String? path) => LauncherSettings(
    themeMode: themeMode,
    darkStartsMinute: darkStartsMinute,
    lightStartsMinute: lightStartsMinute,
    wallpaper: path,
    favorites: favorites,
    panels: panels,
  );

  LauncherSettings toggleFavorite(String appId) => copyWith(
    favorites: favorites.contains(appId)
        ? favorites.where((id) => id != appId).toList(growable: false)
        : [...favorites, appId],
  );

  LauncherSettings withPanel(PanelKind kind, bool visible) =>
      copyWith(panels: _withPanel(panels, kind, visible));

  LauncherSettings withSchedule({
    required int darkStartsMinute,
    required int lightStartsMinute,
  }) => copyWith(
    darkStartsMinute: darkStartsMinute,
    lightStartsMinute: lightStartsMinute,
  );
}
