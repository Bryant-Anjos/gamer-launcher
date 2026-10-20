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

/// Navegação lateral. Passar o foco por uma seção já a abre (sem A); A ou
/// a direita levam o foco ao primeiro item da página. O Energia só abre o
/// menu com A. LB/RB mudam a seção e levam o foco junto.
class SideNav extends StatelessWidget {
  const SideNav({
    super.key,
    required this.selected,
    required this.onSelect,
    required this.focusNodes,
    required this.onPower,
    required this.onEnterContent,
  });

  final Section selected;
  final ValueChanged<Section> onSelect;
  final List<FocusNode> focusNodes;
  final VoidCallback onPower;
  final VoidCallback onEnterContent;

  /// A direita sai do menu para o primeiro item da página (e não para o
  /// item mais perto na mesma altura, que na tela inicial é a pesquisa).
  Object? _move(DirectionalFocusIntent intent) {
    if (intent.direction == TraversalDirection.right) {
      onEnterContent();
    } else {
      FocusManager.instance.primaryFocus?.focusInDirection(intent.direction);
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Actions(
      actions: {
        DirectionalFocusIntent: CallbackAction<DirectionalFocusIntent>(
          onInvoke: _move,
        ),
      },
      child: _layout(),
    );
  }

  Widget _layout() {
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
                  onFocus: () => onSelect(section),
                  onTap: () {
                    onSelect(section);
                    onEnterContent();
                  },
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

/// Energia e saída, separada das seções por um fio: abre o menu em vez de
/// trocar de página, mas tem a mesma cara de um item da navegação.
class _PowerItem extends StatelessWidget {
  const _PowerItem({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = LauncherPalette.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Divider(
          height: Dimens.divider,
          thickness: Dimens.divider,
          indent: Dimens.focusBorder,
          endIndent: Dimens.focusBorder,
          color: palette.panelBorder,
        ),
        const SizedBox(height: Dimens.smallGap),
        FocusTile(
          onActivate: onTap,
          borderRadius: Dimens.smallRadius,
          semanticLabel: 'Energia',
          child: _NavRow(
            icon: Icons.power_settings_new_rounded,
            label: 'Energia',
            color: palette.textPrimary,
          ),
        ),
      ],
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.section,
    required this.isSelected,
    required this.focusNode,
    required this.onFocus,
    required this.onTap,
  });

  final Section section;
  final bool isSelected;
  final FocusNode focusNode;
  final VoidCallback onFocus;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = LauncherPalette.of(context);
    return FocusTile(
      focusNode: focusNode,
      onActivate: onTap,
      onFocusChange: (focused) {
        if (focused) onFocus();
      },
      borderRadius: Dimens.smallRadius,
      semanticLabel: section.label,
      child: _NavRow(
        icon: sectionIcon(section),
        label: section.label,
        color: isSelected ? palette.accent : palette.textPrimary,
        isSelected: isSelected,
      ),
    );
  }
}

/// Conteúdo de um item da navegação; o selecionado ganha fundo e negrito.
class _NavRow extends StatelessWidget {
  const _NavRow({
    required this.icon,
    required this.label,
    required this.color,
    this.isSelected = false,
  });

  final IconData icon;
  final String label;
  final Color color;
  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    final palette = LauncherPalette.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: Dimens.rowPaddingX,
        vertical: Dimens.rowPaddingY,
      ),
      color: isSelected
          ? palette.accent.withValues(alpha: Opacities.selected)
          : Colors.transparent,
      child: Row(
        children: [
          Icon(icon, color: color),
          const SizedBox(width: Dimens.iconGap),
          Expanded(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: color,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
