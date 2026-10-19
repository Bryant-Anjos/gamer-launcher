import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gamer_launcher/input/adjust_intent.dart';
import 'package:gamer_launcher/src/rust/api/input.dart';

class _CloseIntent extends Intent {
  const _CloseIntent();
}

/// Traduz as ações do controle em foco, ativação e navegação, como se
/// fossem teclas. Também fecha o app com Ctrl+Q.
///
/// Fica acima do `Navigator` (em `MaterialApp.builder`), para o Ctrl+Q
/// valer com diálogos abertos; por isso tudo parte do foco primário, que
/// está sempre na camada de cima (o diálogo aberto ou a tela).
class InputRouter extends StatefulWidget {
  const InputRouter({
    super.key,
    required this.actions,
    required this.onClose,
    required this.child,
    this.onSearch,
    this.onQuickControls,
    this.onTabChange,
    this.onError,
  });

  final Stream<GamepadAction> actions;
  final VoidCallback onClose;
  final VoidCallback? onSearch;
  final VoidCallback? onQuickControls;

  /// -1 para a aba anterior, +1 para a próxima.
  final ValueChanged<int>? onTabChange;

  /// Falha da leitura do controle (ex.: [GamepadUnavailable]).
  final ValueChanged<Object>? onError;
  final Widget child;

  @override
  State<InputRouter> createState() => _InputRouterState();
}

class _InputRouterState extends State<InputRouter> {
  /// Foco de partida: recebe o teclado antes de haver algo selecionado e
  /// fica fora da travessia, para a primeira direção cair no primeiro item.
  final _landing = FocusNode(
    debugLabel: 'launcher-landing',
    skipTraversal: true,
  );
  StreamSubscription<GamepadAction>? _subscription;

  @override
  void initState() {
    super.initState();
    _subscription = _listen();
  }

  StreamSubscription<GamepadAction> _listen() => widget.actions.listen(
    _handle,
    onError: (Object error) => widget.onError?.call(error),
  );

  @override
  void didUpdateWidget(InputRouter oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.actions != widget.actions) {
      _subscription?.cancel();
      _subscription = _listen();
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _landing.dispose();
    super.dispose();
  }

  void _handle(GamepadAction action) {
    switch (action) {
      case GamepadAction.up:
        _move(TraversalDirection.up);
      case GamepadAction.down:
        _move(TraversalDirection.down);
      case GamepadAction.left:
        _move(TraversalDirection.left);
      case GamepadAction.right:
        _move(TraversalDirection.right);
      case GamepadAction.confirm:
        _activate();
      case GamepadAction.back:
        _back();
      case GamepadAction.search:
        widget.onSearch?.call();
      case GamepadAction.quickControls:
        widget.onQuickControls?.call();
      case GamepadAction.tabPrevious:
        widget.onTabChange?.call(-1);
      case GamepadAction.tabNext:
        widget.onTabChange?.call(1);
      case GamepadAction.close:
        widget.onClose();
    }
  }

  FocusNode? get _primary => FocusManager.instance.primaryFocus;

  FocusNode? get _focusedItem {
    final primary = _primary;
    if (primary == null || primary == _landing || primary is FocusScopeNode) {
      return null;
    }
    return primary;
  }

  void _move(TraversalDirection direction) {
    final focused = _focusedItem;
    if (focused == null) {
      _focusFirstItem();
      return;
    }
    if (!_tryAdjust(focused, direction)) {
      focused.focusInDirection(direction);
    }
  }

  /// Sem item focado, entra no primeiro item da camada de cima. Partir do
  /// foco primário (e não do contexto deste widget) evita focar um item
  /// escondido atrás de um diálogo.
  void _focusFirstItem() {
    final start = _primary ?? _landing;
    final startContext = start.context ?? context;
    final policy =
        FocusTraversalGroup.maybeOf(startContext) ??
        ReadingOrderTraversalPolicy();
    policy.findFirstFocus(start, ignoreCurrentFocus: true)?.requestFocus();
  }

  /// Esquerda e direita ajustam o item focado se ele aceitar [AdjustIntent]
  /// (volume, brilho...). Devolve se o ajuste aconteceu.
  bool _tryAdjust(FocusNode focused, TraversalDirection direction) {
    final isHorizontal =
        direction == TraversalDirection.left ||
        direction == TraversalDirection.right;
    final focusedContext = focused.context;
    if (!isHorizontal || focusedContext == null) return false;
    final intent = AdjustIntent(direction == TraversalDirection.right ? 1 : -1);
    final action = Actions.maybeFind<AdjustIntent>(focusedContext);
    if (action == null || !action.isEnabled(intent)) return false;
    Actions.invoke(focusedContext, intent);
    return true;
  }

  void _activate() {
    final focusedContext = _focusedItem?.context;
    if (focusedContext != null) {
      Actions.maybeInvoke(focusedContext, const ActivateIntent());
    }
  }

  /// Volta no Navigator da camada de cima; na tela inicial não há o que fechar.
  void _back() {
    final primaryContext = _primary?.context;
    if (primaryContext == null) return;
    Navigator.maybeOf(primaryContext)?.maybePop();
  }

  @override
  Widget build(BuildContext context) {
    return Shortcuts(
      shortcuts: const {
        SingleActivator(LogicalKeyboardKey.keyQ, control: true): _CloseIntent(),
      },
      child: Actions(
        actions: {
          _CloseIntent: CallbackAction<_CloseIntent>(
            onInvoke: (_) {
              widget.onClose();
              return null;
            },
          ),
        },
        child: Focus(focusNode: _landing, autofocus: true, child: widget.child),
      ),
    );
  }
}
