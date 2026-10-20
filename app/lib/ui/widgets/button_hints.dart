import 'package:flutter/material.dart';
import 'package:gamer_launcher/input/button_names.dart';
import 'package:gamer_launcher/theme/dimens.dart';
import 'package:gamer_launcher/theme/launcher_theme.dart';
import 'package:gamer_launcher/ui/launcher_scope.dart';
import 'package:gamer_launcher/ui/widgets/panel_card.dart';

const _glyphSize = 16.0;
const _dotRadius = 1.9;
const _activeDotRadius = 2.7;
const _dotOffset = 5.3;
const _dotStroke = 1.2;

/// Uma dica: o papel do botão e o que ele faz aqui ("fecha").
@immutable
class ButtonHint {
  const ButtonHint(this.role, this.action);

  final PadRole role;
  final String action;
}

/// Dicas dos botões ("A escolhe · B fecha") com o nome e a posição do
/// botão no layout em vigor: no Nintendo o A fica à direita, no Xbox embaixo.
class ButtonHints extends StatelessWidget {
  const ButtonHints(this.hints, {super.key});

  final List<ButtonHint> hints;

  @override
  Widget build(BuildContext context) {
    final services = LauncherScope.of(context);
    final detected = services.gamepad.detectedLayout;
    return ListenableBuilder(
      listenable: Listenable.merge([services.controller, detected]),
      builder: (context, _) {
        final layout = effectiveLayout(
          services.controller.value.settings.buttonLayout,
          detected.value,
        );
        return Wrap(
          spacing: Dimens.smallGap,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            for (final (index, hint) in hints.indexed) ...[
              if (index > 0) const MutedText('·'),
              _HintItem(
                name: buttonFor(hint.role, layout),
                action: hint.action,
              ),
            ],
          ],
        );
      },
    );
  }
}

class _HintItem extends StatelessWidget {
  const _HintItem({required this.name, required this.action});

  final PadButtonName name;
  final String action;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      ButtonGlyph(letter: name.letter, position: name.position),
      const SizedBox(width: Dimens.tinyGap),
      MutedText('${name.letter} $action'),
    ],
  );
}

/// Losango dos quatro botões do controle com o da [position] aceso.
class ButtonGlyph extends StatelessWidget {
  const ButtonGlyph({super.key, required this.letter, required this.position});

  final String letter;
  final FacePosition position;

  @override
  Widget build(BuildContext context) {
    final palette = LauncherPalette.of(context);
    return Semantics(
      label: '$letter, ${position.spoken}',
      child: CustomPaint(
        size: const Size.square(_glyphSize),
        painter: _DiamondPainter(
          active: position,
          on: palette.accent,
          off: palette.textMuted,
        ),
      ),
    );
  }
}

class _DiamondPainter extends CustomPainter {
  const _DiamondPainter({
    required this.active,
    required this.on,
    required this.off,
  });

  final FacePosition active;
  final Color on;
  final Color off;

  static Offset _offset(FacePosition position) => switch (position) {
    FacePosition.bottom => const Offset(0, _dotOffset),
    FacePosition.right => const Offset(_dotOffset, 0),
    FacePosition.top => const Offset(0, -_dotOffset),
    FacePosition.left => const Offset(-_dotOffset, 0),
  };

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final outline = Paint()
      ..color = off
      ..style = PaintingStyle.stroke
      ..strokeWidth = _dotStroke;
    final filled = Paint()..color = on;
    for (final position in FacePosition.values) {
      final at = center + _offset(position);
      if (position == active) {
        canvas.drawCircle(at, _activeDotRadius, filled);
      } else {
        canvas.drawCircle(at, _dotRadius, outline);
      }
    }
  }

  @override
  bool shouldRepaint(_DiamondPainter old) =>
      old.active != active || old.on != on || old.off != off;
}
