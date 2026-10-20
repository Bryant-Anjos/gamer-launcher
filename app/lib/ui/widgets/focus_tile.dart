import 'package:flutter/material.dart';
import 'package:gamer_launcher/theme/dimens.dart';
import 'package:gamer_launcher/theme/launcher_theme.dart';

/// Item navegável por controle: recebe foco, ativa com A/Enter/clique e
/// mostra um anel de foco bem visível (borda, brilho e leve aumento).
///
/// O destaque segue o foco de verdade (`onFocusChange`), não o modo de
/// destaque do Flutter, que só liga depois de usar o teclado: com o
/// controle nenhuma tecla é apertada.
class FocusTile extends StatefulWidget {
  const FocusTile({
    super.key,
    required this.child,
    this.onActivate,
    this.focusable,
    this.focusNode,
    this.autofocus = false,
    this.borderRadius = Dimens.radius,
    this.semanticLabel,
    this.onFocusChange,
  });

  final Widget child;
  final VoidCallback? onActivate;

  /// Padrão: focável só se puder ser ativado. Controles ajustáveis (volume)
  /// são focáveis sem ativação.
  final bool? focusable;
  final FocusNode? focusNode;
  final bool autofocus;
  final double borderRadius;
  final String? semanticLabel;
  final ValueChanged<bool>? onFocusChange;

  @override
  State<FocusTile> createState() => _FocusTileState();
}

class _FocusTileState extends State<FocusTile> {
  bool _focused = false;
  bool _hovered = false;

  bool get _focusable => widget.focusable ?? widget.onActivate != null;

  void _handleFocus(bool focused) {
    setState(() => _focused = focused);
    widget.onFocusChange?.call(focused);
    if (focused) {
      Scrollable.ensureVisible(
        context,
        alignment: 0.5,
        duration: Motion.of(context, Motion.scroll),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = LauncherPalette.of(context);
    final radius = BorderRadius.circular(widget.borderRadius);
    final motion = Motion.of(context, Motion.focus);
    final inner = BorderRadius.circular(
      (widget.borderRadius - Dimens.focusBorder).clamp(0, widget.borderRadius),
    );
    return Semantics(
      button: widget.onActivate != null,
      label: widget.semanticLabel,
      child: FocusableActionDetector(
        enabled: _focusable,
        focusNode: widget.focusNode,
        autofocus: widget.autofocus,
        onFocusChange: _handleFocus,
        onShowHoverHighlight: (hovered) => setState(() => _hovered = hovered),
        mouseCursor: widget.onActivate != null
            ? SystemMouseCursors.click
            : MouseCursor.defer,
        actions: {
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) {
              widget.onActivate?.call();
              return null;
            },
          ),
        },
        child: GestureDetector(
          onTap: widget.onActivate,
          child: AnimatedScale(
            scale: _focused ? Dimens.focusScale : 1,
            duration: motion,
            child: AnimatedContainer(
              duration: motion,
              decoration: BoxDecoration(
                borderRadius: radius,
                border: Border.all(
                  width: Dimens.focusBorder,
                  color: _focused ? palette.focusRing : Colors.transparent,
                ),
                boxShadow: _focused
                    ? [
                        BoxShadow(
                          color: palette.focusRing.withValues(
                            alpha: Opacities.glow,
                          ),
                          blurRadius: Dimens.focusGlow,
                        ),
                      ]
                    : null,
              ),
              foregroundDecoration: _hovered && !_focused
                  ? BoxDecoration(
                      borderRadius: radius,
                      color: palette.textPrimary.withValues(
                        alpha: Opacities.hover,
                      ),
                    )
                  : null,
              child: ClipRRect(borderRadius: inner, child: widget.child),
            ),
          ),
        ),
      ),
    );
  }
}
