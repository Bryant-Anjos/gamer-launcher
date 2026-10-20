import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gamer_launcher/theme/dimens.dart';
import 'package:gamer_launcher/theme/launcher_theme.dart';

/// Campo de pesquisa (pesquisa global e filtro dos favoritos), com a cara da
/// barra de pesquisa da tela inicial: superfície dos painéis, raio grande e
/// o anel de foco na cor de destaque. A digitação é pelo teclado físico.
///
/// Para baixo (seta ou direcional) sai do campo para os resultados; A ou
/// Enter chamam [onSubmit] (abrir o primeiro resultado).
class SearchInput extends StatelessWidget {
  const SearchInput({
    super.key,
    required this.controller,
    required this.hint,
    required this.onChanged,
    required this.onSubmit,
    this.focusNode,
    this.autofocus = false,
  });

  final TextEditingController controller;
  final String hint;
  final ValueChanged<String> onChanged;
  final VoidCallback onSubmit;
  final FocusNode? focusNode;
  final bool autofocus;

  OutlineInputBorder _border(Color color, double width) => OutlineInputBorder(
    borderRadius: BorderRadius.circular(Dimens.radius),
    borderSide: BorderSide(color: color, width: width),
  );

  @override
  Widget build(BuildContext context) {
    final palette = LauncherPalette.of(context);
    return Shortcuts(
      shortcuts: const {
        // o campo ignora direções por padrão (a seta move o cursor)
        SingleActivator(LogicalKeyboardKey.arrowDown): DirectionalFocusIntent(
          TraversalDirection.down,
          ignoreTextFields: false,
        ),
      },
      child: Actions(
        actions: {
          // o A do controle chega como ativação do item focado
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) {
              onSubmit();
              return null;
            },
          ),
        },
        child: TextField(
          controller: controller,
          focusNode: focusNode,
          autofocus: autofocus,
          onChanged: onChanged,
          onSubmitted: (_) => onSubmit(),
          textInputAction: TextInputAction.search,
          style: TextStyle(color: palette.textPrimary),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: palette.textMuted),
            prefixIcon: Icon(Icons.search_rounded, color: palette.textMuted),
            filled: true,
            fillColor: palette.panel,
            enabledBorder: _border(palette.panelBorder, Dimens.divider),
            focusedBorder: _border(palette.focusRing, Dimens.focusBorder),
          ),
        ),
      ),
    );
  }
}
