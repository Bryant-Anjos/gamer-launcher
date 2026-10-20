import 'package:flutter/widgets.dart';

/// Ação secundária do item focado (botão X do controle; M no teclado onde
/// faz sentido): por exemplo, começar a mover um favorito.
class SecondaryIntent extends Intent {
  const SecondaryIntent();
}

/// Cancelar o que o item focado está fazendo (mover um favorito). Quem
/// declara uma ação habilitada para isso recebe o B e o Esc antes de eles
/// levarem o foco de volta à navegação.
class CancelIntent extends Intent {
  const CancelIntent();
}
