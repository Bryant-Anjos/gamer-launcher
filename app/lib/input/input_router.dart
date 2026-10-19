import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gamer_launcher/src/rust/api/input.dart';

class _CloseIntent extends Intent {
  const _CloseIntent();
}

/// Traduz as ações do controle em foco, ativação e navegação, como se
/// fossem teclas. Também fecha o app com Ctrl+Q.
class InputRouter extends StatefulWidget {
  const InputRouter({
    super.key,
    required this.actions,
    required this.onClose,
    required this.child,
    this.onSearch,
    this.onQuickControls,
    this.onTabChange,
  });

  final Stream<GamepadAction> actions;
  final VoidCallback onClose;
  final VoidCallback? onSearch;
  final VoidCallback? onQuickControls;

  /// -1 para a aba anterior, +1 para a próxima.
  final ValueChanged<int>? onTabChange;
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
    _subscription = widget.actions.listen(_handle);
  }

  @override
  void didUpdateWidget(InputRouter oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.actions != widget.actions) {
      _subscription?.cancel();
      _subscription = widget.actions.listen(_handle);
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
        Navigator.of(context).maybePop();
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

  FocusNode? get _focusedItem {
    final primary = FocusManager.instance.primaryFocus;
    if (primary == null || primary == _landing || primary is FocusScopeNode) {
      return null;
    }
    return primary;
  }

  void _move(TraversalDirection direction) {
    final focused = _focusedItem;
    if (focused != null) {
      focused.focusInDirection(direction);
      return;
    }
    FocusTraversalGroup.of(context)
        .findFirstFocus(_landing, ignoreCurrentFocus: true)
        ?.requestFocus();
  }

  void _activate() {
    final focusedContext = _focusedItem?.context;
    if (focusedContext != null) {
      Actions.maybeInvoke(focusedContext, const ActivateIntent());
    }
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
