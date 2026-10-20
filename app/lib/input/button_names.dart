import 'package:flutter/foundation.dart';
import 'package:gamer_launcher/src/rust/api/settings.dart';

/// Layout de botões em vigor (o automático já resolvido).
enum PadLayout { xbox, nintendo }

/// Papel do botão na tela, independente de onde ele fica no controle.
enum PadRole { confirm, back, search }

/// Onde o botão fica no losango de botões do controle.
enum FacePosition {
  bottom('botão de baixo'),
  right('botão da direita'),
  top('botão de cima'),
  left('botão da esquerda');

  const FacePosition(this.spoken);

  /// Como a leitura em voz alta descreve a posição.
  final String spoken;
}

/// Nome impresso no botão e a posição dele no controle.
@immutable
class PadButtonName {
  const PadButtonName(this.letter, this.position);

  final String letter;
  final FacePosition position;

  @override
  bool operator ==(Object other) =>
      other is PadButtonName &&
      other.letter == letter &&
      other.position == position;

  @override
  int get hashCode => Object.hash(letter, position);

  @override
  String toString() => '$letter (${position.spoken})';
}

/// O automático segue o controle detectado pelo núcleo; uma escolha forçada
/// vale para qualquer controle.
PadLayout effectiveLayout(
  LauncherButtonLayout setting,
  LauncherButtonLayout detected,
) => switch (setting) {
  LauncherButtonLayout.xbox => PadLayout.xbox,
  LauncherButtonLayout.nintendo => PadLayout.nintendo,
  LauncherButtonLayout.auto =>
    detected == LauncherButtonLayout.nintendo
        ? PadLayout.nintendo
        : PadLayout.xbox,
};

/// As letras são as mesmas nos dois layouts (o núcleo troca as posições);
/// muda onde o botão está: no Nintendo o A fica à direita e o B embaixo.
PadButtonName buttonFor(PadRole role, PadLayout layout) =>
    switch ((role, layout)) {
      (PadRole.confirm, PadLayout.xbox) => const PadButtonName(
        'A',
        FacePosition.bottom,
      ),
      (PadRole.confirm, PadLayout.nintendo) => const PadButtonName(
        'A',
        FacePosition.right,
      ),
      (PadRole.back, PadLayout.xbox) => const PadButtonName(
        'B',
        FacePosition.right,
      ),
      (PadRole.back, PadLayout.nintendo) => const PadButtonName(
        'B',
        FacePosition.bottom,
      ),
      (PadRole.search, PadLayout.xbox) => const PadButtonName(
        'Y',
        FacePosition.top,
      ),
      (PadRole.search, PadLayout.nintendo) => const PadButtonName(
        'Y',
        FacePosition.left,
      ),
    };
