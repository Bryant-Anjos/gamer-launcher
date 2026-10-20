import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gamer_launcher/input/adjust_intent.dart';
import 'package:gamer_launcher/input/item_intents.dart';
import 'package:gamer_launcher/input/typing.dart';
import 'package:gamer_launcher/src/rust/api/input.dart';

final _keyActions = {
  LogicalKeyboardKey.arrowUp: GamepadAction.up,
  LogicalKeyboardKey.arrowDown: GamepadAction.down,
  LogicalKeyboardKey.arrowLeft: GamepadAction.left,
  LogicalKeyboardKey.arrowRight: GamepadAction.right,
  LogicalKeyboardKey.enter: GamepadAction.confirm,
  LogicalKeyboardKey.numpadEnter: GamepadAction.confirm,
  LogicalKeyboardKey.escape: GamepadAction.back,
};

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
    this.onFeedback,
    this.onBackToMenu,
  });

  final Stream<GamepadAction> actions;
  final VoidCallback onClose;
  final VoidCallback? onSearch;
  final VoidCallback? onQuickControls;

  /// -1 para a aba anterior, +1 para a próxima.
  final ValueChanged<int>? onTabChange;

  /// Falha da leitura do controle (ex.: [GamepadUnavailable]).
  final ValueChanged<Object>? onError;

  /// Cada ação do controle, e as teclas equivalentes (setas, Enter, Esc)
  /// fora de campos de texto, para o retorno sonoro.
  final ValueChanged<GamepadAction>? onFeedback;

  /// B (ou Esc) sem diálogo aberto: o foco volta à navegação.
  final VoidCallback? onBackToMenu;
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
    widget.onFeedback?.call(action);
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
      case GamepadAction.secondary:
        _invokeOnFocused(const SecondaryIntent());
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
    if (!_tryAdjust(focused, direction)) _moveFocus(focused, direction);
  }

  /// Pelo mesmo caminho das setas do teclado, para quem trata a direção
  /// (a navegação lateral, um campo de texto) decidir; sem ninguém, a
  /// travessia direcional do Flutter.
  void _moveFocus(FocusNode focused, TraversalDirection direction) {
    final focusedContext = focused.context;
    final intent = DirectionalFocusIntent(direction, ignoreTextFields: false);
    final action = focusedContext == null
        ? null
        : Actions.maybeFind<DirectionalFocusIntent>(focusedContext);
    if (action == null || focusedContext == null) {
      focused.focusInDirection(direction);
      return;
    }
    Actions.invoke(focusedContext, intent);
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

  /// Invoca [intent] no item focado se alguém ali aceitar; diz se aceitou.
  bool _invokeOnFocused(Intent intent) {
    final focusedContext = _focusedItem?.context;
    if (focusedContext == null) return false;
    final action = Actions.maybeFind<Intent>(focusedContext, intent: intent);
    if (action == null || !action.isEnabled(intent)) return false;
    Actions.invoke(focusedContext, intent);
    return true;
  }

  /// O item focado pode cancelar o que está fazendo (mover um favorito);
  /// senão fecha a camada de cima (diálogo, painel); sem nenhuma aberta,
  /// leva o foco de volta à navegação.
  void _back() {
    if (_invokeOnFocused(const CancelIntent())) return;
    final primaryContext = _primary?.context;
    final navigator = primaryContext == null
        ? null
        : Navigator.maybeOf(primaryContext);
    if (navigator != null && navigator.canPop()) {
      navigator.maybePop();
      return;
    }
    widget.onBackToMenu?.call();
  }

  bool get _hasOverlay {
    final primaryContext = _primary?.context;
    if (primaryContext == null) return false;
    return Navigator.maybeOf(primaryContext)?.canPop() ?? false;
  }

  /// Só observa: a tecla segue para quem a trata (a travessia do Flutter).
  KeyEventResult _observeKey(FocusNode _, KeyEvent event) {
    final action = event is KeyUpEvent ? null : _keyActions[event.logicalKey];
    // num campo de texto as setas e o Enter editam, não navegam
    if (action == null || isTypingInField()) return KeyEventResult.ignored;
    widget.onFeedback?.call(action);
    // Esc como o B: primeiro o cancelamento do item, depois a navegação
    if (action == GamepadAction.back &&
        _invokeOnFocused(const CancelIntent())) {
      return KeyEventResult.handled;
    }
    if (action == GamepadAction.back && !_hasOverlay) {
      widget.onBackToMenu?.call();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
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
        child: Focus(
          focusNode: _landing,
          autofocus: true,
          onKeyEvent: _observeKey,
          child: widget.child,
        ),
      ),
    );
  }
}
