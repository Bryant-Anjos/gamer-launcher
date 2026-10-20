import 'package:flutter/widgets.dart';

/// Medidas da tela (em pixels lógicos), num lugar só.
abstract final class Dimens {
  static const gutter = 24.0;
  static const gap = 16.0;
  static const smallGap = 8.0;
  static const sideNavWidth = 220.0;
  static const sidePanelWidth = 380.0;
  static const searchWidth = 440.0;
  static const searchPanelWidth = 760.0;
  static const radius = 18.0;
  static const smallRadius = 12.0;
  static const focusBorder = 3.0;
  static const focusScale = 1.04;
  static const focusGlow = 18.0;
  static const topBarHeight = 64.0;
  static const featuredCardHeight = 210.0;
  static const favoriteTile = 72.0;
  static const favoriteIcon = 44.0;
  static const appGridExtent = 160.0;
  static const appGridIcon = 64.0;
  static const wallpaperThumbWidth = 240.0;
  static const wallpaperThumbHeight = 135.0;
  static const toggleBox = 60.0;
  static const statusIcon = 22.0;
  static const panelPadding = 20.0;

  /// Linhas de lista (navegação, menus, dispositivos): recuo e o espaço
  /// entre o ícone e o texto.
  static const rowPaddingX = 14.0;
  static const rowPaddingY = 12.0;
  static const iconGap = 14.0;
  static const tinyGap = 4.0;

  /// Largura dos menus sobrepostos (Energia).
  static const menuWidth = 440.0;
  static const divider = 1.0;
}

/// Durações das animações. Com "Reduzir animações" (ou o pedido do sistema)
/// [of] devolve zero e tudo muda na hora.
abstract final class Motion {
  static const focus = Duration(milliseconds: 140);
  static const scroll = Duration(milliseconds: 160);
  static const overlay = Duration(milliseconds: 160);

  static Duration of(BuildContext context, Duration normal) =>
      MediaQuery.maybeDisableAnimationsOf(context) ?? false
      ? Duration.zero
      : normal;
}

/// Opacidades usadas em mais de um lugar.
abstract final class Opacities {
  static const disabled = 0.45;
  static const hover = 0.06;
  static const glow = 0.45;
  static const selected = 0.16;
}
