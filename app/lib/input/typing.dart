import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

const _firstPrintable = 0x20;
const _delete = 0x7f;

/// O foco está num campo de texto? Lá as setas e o Enter editam o texto.
bool isTypingInField() =>
    FocusManager.instance.primaryFocus?.context
        ?.findAncestorWidgetOfExactType<EditableText>() !=
    null;

/// Caractere visível digitado (letra, número, pontuação), ou `null` para
/// teclas de controle, espaço (que ativa o item focado) e atalhos com Ctrl,
/// Alt ou Super.
String? typedCharacter(KeyEvent event) {
  if (event is KeyUpEvent) return null;
  final character = event.character;
  if (character == null || character.trim().isEmpty) return null;
  final code = character.codeUnitAt(0);
  if (code < _firstPrintable || code == _delete) return null;
  final keys = HardwareKeyboard.instance;
  if (keys.isControlPressed || keys.isAltPressed || keys.isMetaPressed) {
    return null;
  }
  return character;
}

/// Digitar com um item focado (fora de um campo) entrega o caractere a
/// [onCharacter]: abre a pesquisa ou leva ao filtro com a letra já escrita.
class TypeToSearch extends StatelessWidget {
  const TypeToSearch({
    super.key,
    required this.onCharacter,
    required this.child,
  });

  final ValueChanged<String> onCharacter;
  final Widget child;

  @override
  Widget build(BuildContext context) => Focus(
    canRequestFocus: false,
    skipTraversal: true,
    onKeyEvent: (_, event) {
      final character = typedCharacter(event);
      if (character == null || isTypingInField()) {
        return KeyEventResult.ignored;
      }
      onCharacter(character);
      return KeyEventResult.handled;
    },
    child: child,
  );
}
