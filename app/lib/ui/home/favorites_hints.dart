import 'package:flutter/material.dart';
import 'package:gamer_launcher/input/button_names.dart';
import 'package:gamer_launcher/theme/dimens.dart';
import 'package:gamer_launcher/ui/widgets/button_hints.dart';
import 'package:gamer_launcher/ui/widgets/panel_card.dart';

/// Com um favorito focado: o X começa a movê-lo.
class MoveHint extends StatelessWidget {
  const MoveHint({super.key});

  @override
  Widget build(BuildContext context) =>
      const ButtonHints([ButtonHint(PadRole.secondary, 'move')]);
}

/// Movendo um favorito: o direcional muda o lugar, A grava, B desfaz.
class MovingHints extends StatelessWidget {
  const MovingHints({super.key});

  @override
  Widget build(BuildContext context) => const Wrap(
    spacing: Dimens.smallGap,
    crossAxisAlignment: WrapCrossAlignment.center,
    children: [
      MutedText('Direcional muda o lugar'),
      MutedText('·'),
      ButtonHints([
        ButtonHint(PadRole.confirm, 'confirma'),
        ButtonHint(PadRole.back, 'cancela'),
      ]),
    ],
  );
}
