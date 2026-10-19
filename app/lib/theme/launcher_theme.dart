import 'package:flutter/material.dart';

/// Cores do launcher além das do Material (painéis translúcidos, anel de
/// foco). Os valores seguem a arte de conceito, nos dois temas.
@immutable
class LauncherPalette extends ThemeExtension<LauncherPalette> {
  const LauncherPalette({
    required this.background,
    required this.panel,
    required this.panelBorder,
    required this.tile,
    required this.accent,
    required this.onAccent,
    required this.focusRing,
    required this.textPrimary,
    required this.textMuted,
    required this.scrim,
  });

  final Color background;
  final Color panel;
  final Color panelBorder;
  final Color tile;
  final Color accent;
  final Color onAccent;
  final Color focusRing;
  final Color textPrimary;
  final Color textMuted;

  /// Véu sobre o wallpaper para o texto continuar legível.
  final Color scrim;

  static const dark = LauncherPalette(
    background: Color(0xFF0B1020),
    panel: Color(0xC7121A2C),
    panelBorder: Color(0x1FFFFFFF),
    tile: Color(0xFF1B2438),
    accent: Color(0xFF2F7BFF),
    onAccent: Color(0xFFFFFFFF),
    focusRing: Color(0xFF7FB2FF),
    textPrimary: Color(0xFFF4F6FB),
    textMuted: Color(0xFF9AA5BA),
    scrim: Color(0x8C05080F),
  );

  static const light = LauncherPalette(
    background: Color(0xFFEEF3FA),
    panel: Color(0xD9FFFFFF),
    panelBorder: Color(0x140F172A),
    tile: Color(0xFFFFFFFF),
    accent: Color(0xFF1F6BFF),
    onAccent: Color(0xFFFFFFFF),
    focusRing: Color(0xFF1F6BFF),
    textPrimary: Color(0xFF111827),
    textMuted: Color(0xFF5B6478),
    scrim: Color(0x73FFFFFF),
  );

  static LauncherPalette of(BuildContext context) =>
      Theme.of(context).extension<LauncherPalette>() ?? dark;

  @override
  LauncherPalette copyWith({Color? accent}) => LauncherPalette(
    background: background,
    panel: panel,
    panelBorder: panelBorder,
    tile: tile,
    accent: accent ?? this.accent,
    onAccent: onAccent,
    focusRing: focusRing,
    textPrimary: textPrimary,
    textMuted: textMuted,
    scrim: scrim,
  );

  @override
  LauncherPalette lerp(LauncherPalette? other, double t) {
    if (other == null) return this;
    Color mix(Color a, Color b) => Color.lerp(a, b, t)!;
    return LauncherPalette(
      background: mix(background, other.background),
      panel: mix(panel, other.panel),
      panelBorder: mix(panelBorder, other.panelBorder),
      tile: mix(tile, other.tile),
      accent: mix(accent, other.accent),
      onAccent: mix(onAccent, other.onAccent),
      focusRing: mix(focusRing, other.focusRing),
      textPrimary: mix(textPrimary, other.textPrimary),
      textMuted: mix(textMuted, other.textMuted),
      scrim: mix(scrim, other.scrim),
    );
  }
}

/// Degradês dos cartões de destaque (no lugar das ilustrações da arte).
abstract final class CardGradients {
  static const resume = [Color(0xFF3A2A78), Color(0xFFE9806A)];
  static const projects = [Color(0xFF0E4D3A), Color(0xFF6CCB5F)];
  static const games = [Color(0xFF1A1B2E), Color(0xFFB0283A)];
  static const music = [Color(0xFF4B1F7A), Color(0xFFF2557E)];
}

ThemeData buildLauncherTheme(Brightness brightness) {
  final palette = brightness == Brightness.dark
      ? LauncherPalette.dark
      : LauncherPalette.light;
  final scheme = ColorScheme.fromSeed(
    seedColor: palette.accent,
    brightness: brightness,
    primary: palette.accent,
    surface: palette.background,
  );
  final base = ThemeData(
    colorScheme: scheme,
    brightness: brightness,
    scaffoldBackgroundColor: palette.background,
    extensions: [palette],
  );
  return base.copyWith(
    textTheme: base.textTheme.apply(
      bodyColor: palette.textPrimary,
      displayColor: palette.textPrimary,
    ),
    iconTheme: IconThemeData(color: palette.textPrimary),
    snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
  );
}
