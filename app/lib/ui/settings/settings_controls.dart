import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gamer_launcher/input/adjust_intent.dart';
import 'package:gamer_launcher/theme/dimens.dart';
import 'package:gamer_launcher/theme/launcher_theme.dart';
import 'package:gamer_launcher/ui/widgets/focus_tile.dart';
import 'package:gamer_launcher/util/formatting.dart';

const minutesPerDay = 24 * 60;
const scheduleStepMinutes = 30;
const _choiceWidth = 180.0;
const _rowWidth = 420.0;

/// Opção de uma escolha única (ex.: tema claro/escuro/automático).
class ChoiceTile extends StatelessWidget {
  const ChoiceTile({
    super.key,
    required this.label,
    required this.icon,
    required this.selected,
    required this.onSelect,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onSelect;

  @override
  Widget build(BuildContext context) {
    final palette = LauncherPalette.of(context);
    return FocusTile(
      semanticLabel: '$label${selected ? ', selecionado' : ''}',
      borderRadius: Dimens.smallRadius,
      onActivate: onSelect,
      child: Container(
        constraints: const BoxConstraints(minWidth: _choiceWidth),
        padding: const EdgeInsets.all(14),
        color: selected ? palette.accent : palette.panel,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: selected ? palette.onAccent : null),
            const SizedBox(width: 10),
            Text(
              label,
              style: TextStyle(color: selected ? palette.onAccent : null),
            ),
          ],
        ),
      ),
    );
  }
}

/// Liga/desliga com o rótulo (A alterna).
class SwitchRow extends StatelessWidget {
  const SwitchRow({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.onWord = 'exibido',
    this.offWord = 'oculto',
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  /// Como a leitura em voz alta descreve cada estado.
  final String onWord;
  final String offWord;

  @override
  Widget build(BuildContext context) => FocusTile(
    semanticLabel: '$label: ${value ? onWord : offWord}',
    borderRadius: Dimens.smallRadius,
    onActivate: () => onChanged(!value),
    child: Container(
      width: _rowWidth,
      color: LauncherPalette.of(context).panel,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          ExcludeFocus(
            child: Switch(value: value, onChanged: onChanged),
          ),
        ],
      ),
    ),
  );
}

/// Horário ajustável de 30 em 30 minutos com esquerda/direita, dando a
/// volta na meia-noite.
class TimeStepper extends StatelessWidget {
  const TimeStepper({
    super.key,
    required this.label,
    required this.minute,
    required this.onChanged,
  });

  final String label;
  final int minute;
  final ValueChanged<int> onChanged;

  void _step(int direction) =>
      onChanged((minute + direction * scheduleStepMinutes) % minutesPerDay);

  @override
  Widget build(BuildContext context) => Shortcuts(
    shortcuts: const {
      SingleActivator(LogicalKeyboardKey.arrowLeft): AdjustIntent(-1),
      SingleActivator(LogicalKeyboardKey.arrowRight): AdjustIntent(1),
    },
    child: Actions(
      actions: {
        AdjustIntent: CallbackAction<AdjustIntent>(
          onInvoke: (intent) {
            _step(intent.step);
            return null;
          },
        ),
      },
      child: FocusTile(
        focusable: true,
        semanticLabel: '$label ${formatMinuteOfDay(minute)}',
        borderRadius: Dimens.smallRadius,
        child: Container(
          width: _rowWidth,
          color: LauncherPalette.of(context).panel,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: Row(
            children: [
              Expanded(child: Text(label)),
              // o mouse usa as setas; o controle ajusta pelo item inteiro
              ExcludeFocus(
                child: IconButton(
                  tooltip: 'Mais cedo',
                  icon: const Icon(Icons.chevron_left_rounded),
                  onPressed: () => _step(-1),
                ),
              ),
              Text(
                formatMinuteOfDay(minute),
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              // o mouse usa as setas; o controle ajusta pelo item inteiro
              ExcludeFocus(
                child: IconButton(
                  tooltip: 'Mais tarde',
                  icon: const Icon(Icons.chevron_right_rounded),
                  onPressed: () => _step(1),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
