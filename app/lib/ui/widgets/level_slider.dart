import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gamer_launcher/input/adjust_intent.dart';
import 'package:gamer_launcher/theme/dimens.dart';
import 'package:gamer_launcher/theme/launcher_theme.dart';
import 'package:gamer_launcher/ui/widgets/focus_tile.dart';
import 'package:gamer_launcher/ui/widgets/panel_card.dart';

const _maxPercent = 100;
const _defaultStep = 5;
const _trackHeight = 8.0;
const _knobSize = 18.0;
const _percentLabelWidth = 48.0;

/// Barra de 0 a 100 (volume, brilho). Com foco, esquerda/direita (controle
/// ou setas) ajustam em passos; com o mouse, clique ou arraste. `value`
/// vazio mostra o item como indisponível e fora da navegação.
class LevelSlider extends StatelessWidget {
  const LevelSlider({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    required this.onChanged,
    this.step = _defaultStep,
  });

  final IconData icon;
  final String label;
  final int? value;
  final ValueChanged<int> onChanged;
  final int step;

  void _set(int next) {
    final clamped = next.clamp(0, _maxPercent);
    if (clamped != value) onChanged(clamped);
  }

  void _setFromPosition(double dx, double width) {
    if (width <= 0) return;
    final raw = (dx / width * _maxPercent).round();
    _set((raw / step).round() * step);
  }

  @override
  Widget build(BuildContext context) {
    final current = value;
    if (current == null) {
      return Opacity(
        opacity: Opacities.disabled,
        child: _row(context, null, const MutedText('Indisponível')),
      );
    }
    return Shortcuts(
      shortcuts: const {
        SingleActivator(LogicalKeyboardKey.arrowLeft): AdjustIntent(-1),
        SingleActivator(LogicalKeyboardKey.arrowRight): AdjustIntent(1),
      },
      child: Actions(
        actions: {
          AdjustIntent: CallbackAction<AdjustIntent>(
            onInvoke: (intent) {
              _set(current + intent.step * step);
              return null;
            },
          ),
        },
        child: FocusTile(
          focusable: true,
          borderRadius: Dimens.smallRadius,
          semanticLabel: '$label $current%',
          child: _row(context, current, _track(context, current)),
        ),
      ),
    );
  }

  Widget _row(BuildContext context, int? current, Widget middle) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
    child: Row(
      children: [
        Icon(icon, size: Dimens.statusIcon),
        const SizedBox(width: Dimens.gap),
        Expanded(child: middle),
        SizedBox(
          width: _percentLabelWidth,
          child: Text(
            current == null ? '' : '$current%',
            textAlign: TextAlign.end,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
      ],
    ),
  );

  Widget _track(BuildContext context, int current) {
    final palette = LauncherPalette.of(context);
    final fraction = current / _maxPercent;
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (details) =>
              _setFromPosition(details.localPosition.dx, width),
          onHorizontalDragUpdate: (details) =>
              _setFromPosition(details.localPosition.dx, width),
          child: SizedBox(
            height: _knobSize,
            child: Stack(
              alignment: Alignment.centerLeft,
              children: [
                _bar(palette.panelBorder, width),
                _bar(palette.accent, width * fraction),
                Positioned(
                  left: (width - _knobSize) * fraction,
                  child: Container(
                    width: _knobSize,
                    height: _knobSize,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(color: palette.accent, width: 3),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _bar(Color color, double width) => Container(
    width: width,
    height: _trackHeight,
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(_trackHeight),
    ),
  );
}
