import 'package:flutter/material.dart';
import 'package:gamer_launcher/src/rust/api/settings.dart';
import 'package:gamer_launcher/state/settings_edit.dart';
import 'package:gamer_launcher/theme/dimens.dart';
import 'package:gamer_launcher/ui/settings/settings_controls.dart';
import 'package:gamer_launcher/ui/widgets/panel_card.dart';
import 'package:gamer_launcher/ui/widgets/svg_icon.dart';

typedef SettingsEdit = void Function(
  LauncherSettings Function(LauncherSettings current) change,
);

/// Disposição dos botões: automático (pelo fabricante do controle), Xbox
/// (A embaixo) ou Nintendo (A à direita). Vale na hora.
class ButtonLayoutChoices extends StatelessWidget {
  const ButtonLayoutChoices({
    super.key,
    required this.settings,
    required this.onEdit,
  });

  final LauncherSettings settings;
  final SettingsEdit onEdit;

  @override
  Widget build(BuildContext context) {
    ChoiceTile choice(LauncherButtonLayout layout, String label, Widget icon) =>
        ChoiceTile(
          label: label,
          leading: icon,
          selected: settings.buttonLayout == layout,
          onSelect: () =>
              onEdit((current) => current.copyWith(buttonLayout: layout)),
        );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: Dimens.gap,
          runSpacing: Dimens.gap,
          children: [
            choice(
              LauncherButtonLayout.auto,
              'Automático',
              const Icon(Icons.autorenew_rounded),
            ),
            choice(
              LauncherButtonLayout.xbox,
              'Xbox',
              const Icon(Icons.sports_esports_rounded),
            ),
            choice(LauncherButtonLayout.nintendo, 'Nintendo', const PadIcon()),
          ],
        ),
        const SizedBox(height: Dimens.smallGap),
        const MutedText(
          'Automático reconhece controles Nintendo (A à direita, B embaixo); '
          'os outros seguem o Xbox (A embaixo, B à direita).',
          maxLines: 2,
        ),
      ],
    );
  }
}

/// Sons da interface e animações reduzidas.
class FeedbackSwitches extends StatelessWidget {
  const FeedbackSwitches({
    super.key,
    required this.settings,
    required this.onEdit,
  });

  final LauncherSettings settings;
  final SettingsEdit onEdit;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      SwitchRow(
        label: 'Sons',
        value: settings.sounds,
        onWord: 'ligados',
        offWord: 'desligados',
        onChanged: (on) => onEdit((current) => current.copyWith(sounds: on)),
      ),
      const SizedBox(height: Dimens.smallGap),
      SwitchRow(
        label: 'Reduzir animações',
        value: settings.reduceAnimations,
        onWord: 'ligado',
        offWord: 'desligado',
        onChanged: (on) =>
            onEdit((current) => current.copyWith(reduceAnimations: on)),
      ),
    ],
  );
}
