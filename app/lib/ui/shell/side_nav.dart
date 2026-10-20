import 'package:flutter/material.dart';
import 'package:gamer_launcher/state/launcher_state.dart';
import 'package:gamer_launcher/theme/dimens.dart';
import 'package:gamer_launcher/theme/launcher_theme.dart';
import 'package:gamer_launcher/ui/widgets/focus_tile.dart';

IconData sectionIcon(Section section) => switch (section) {
  Section.home => Icons.home_rounded,
  Section.apps => Icons.grid_view_rounded,
  Section.games => Icons.sports_esports_rounded,
  Section.files => Icons.folder_rounded,
  Section.settings => Icons.settings_rounded,
};

/// Navegação lateral. A seção atual fica marcada; o foco é independente
/// (LB/RB mudam a seção e levam o foco junto).
class SideNav extends StatelessWidget {
  const SideNav({
    super.key,
    required this.selected,
    required this.onSelect,
    required this.focusNodes,
    required this.onPower,
  });

  final Section selected;
  final ValueChanged<Section> onSelect;
  final List<FocusNode> focusNodes;
  final VoidCallback onPower;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: Dimens.sideNavWidth,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          Dimens.gap,
          Dimens.topBarHeight + Dimens.gap,
          Dimens.gap,
          Dimens.gap,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final section in Section.values)
              Padding(
                padding: const EdgeInsets.only(bottom: Dimens.smallGap),
                child: _NavItem(
                  section: section,
                  isSelected: section == selected,
                  focusNode: focusNodes[section.index],
                  onTap: () => onSelect(section),
                ),
              ),
            const Spacer(),
            _PowerItem(onTap: onPower),
          ],
        ),
      ),
    );
  }
}

/// Energia e saída, separada das seções: abre o menu em vez de trocar de página.
class _PowerItem extends StatelessWidget {
  const _PowerItem({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = LauncherPalette.of(context);
    return FocusTile(
      onActivate: onTap,
      borderRadius: Dimens.smallRadius,
      semanticLabel: 'Energia',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        color: palette.panel,
        child: Row(
          children: [
            const Icon(Icons.power_settings_new_rounded),
            const SizedBox(width: 14),
            Text(
              'Energia',
              style: TextStyle(color: palette.textPrimary, fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.section,
    required this.isSelected,
    required this.focusNode,
    required this.onTap,
  });

  final Section section;
  final bool isSelected;
  final FocusNode focusNode;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = LauncherPalette.of(context);
    final color = isSelected ? palette.accent : palette.textPrimary;
    return FocusTile(
      focusNode: focusNode,
      onActivate: onTap,
      borderRadius: Dimens.smallRadius,
      semanticLabel: section.label,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        color: isSelected
            ? palette.accent.withValues(alpha: Opacities.selected)
            : Colors.transparent,
        child: Row(
          children: [
            Icon(sectionIcon(section), color: color),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                section.label,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: color,
                  fontSize: 16,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
