import 'dart:async';

import 'package:flutter/material.dart';
import 'package:gamer_launcher/backend/launcher_backend.dart';
import 'package:gamer_launcher/input/input_router.dart';
import 'package:gamer_launcher/src/rust/api/input.dart';
import 'package:gamer_launcher/src/rust/api/settings.dart';
import 'package:gamer_launcher/state/clock.dart';
import 'package:gamer_launcher/state/gamepad_status.dart';
import 'package:gamer_launcher/state/launcher_controller.dart';
import 'package:gamer_launcher/state/messages.dart';
import 'package:gamer_launcher/state/quick_controls_controller.dart';
import 'package:gamer_launcher/state/system_monitor.dart';
import 'package:gamer_launcher/theme/launcher_theme.dart';
import 'package:gamer_launcher/ui/launcher_scope.dart';
import 'package:gamer_launcher/ui/quick/overlays.dart';
import 'package:gamer_launcher/ui/shell/launcher_shell.dart';

const _minutesPerHour = 60;

/// Criados uma vez: o MaterialApp é reconstruído a cada minuto (relógio).
final _lightTheme = buildLauncherTheme(Brightness.light);
final _darkTheme = buildLauncherTheme(Brightness.dark);

/// Raiz do launcher: cria os serviços, escolhe o tema (claro, escuro ou
/// pela hora), liga o controle às ações e mostra os avisos.
class LauncherApp extends StatefulWidget {
  const LauncherApp({
    super.key,
    required this.backend,
    required this.actions,
    required this.onClose,
    this.coreVersion = '',
    this.now = DateTime.now,
  });

  final LauncherBackend backend;
  final Stream<GamepadAction> actions;
  final VoidCallback onClose;
  final String coreVersion;
  final DateTime Function() now;

  @override
  State<LauncherApp> createState() => _LauncherAppState();
}

class _LauncherAppState extends State<LauncherApp> {
  final _navigatorKey = GlobalKey<NavigatorState>();
  final _messengerKey = GlobalKey<ScaffoldMessengerState>();
  late final LauncherServices _services;
  late final AppLifecycleListener _lifecycle;
  late final StreamSubscription<String> _messageSubscription;
  bool _quickControlsOpen = false;

  @override
  void initState() {
    super.initState();
    final messages = LauncherMessages();
    final backend = widget.backend;
    _services = LauncherServices(
      backend: backend,
      controller: LauncherController(backend, messages),
      quickControls: QuickControlsController(backend, messages),
      monitor: SystemMonitor(backend.sampleStats, onError: messages.show),
      gamepad: GamepadStatus(backend.gamepadConnected),
      clock: Clock(now: widget.now),
      focus: LauncherFocus(),
      messages: messages,
      coreVersion: widget.coreVersion,
      openFavoritesPicker: _openFavoritesPicker,
    );
    _messageSubscription = messages.stream.listen(_showMessage);
    _lifecycle = AppLifecycleListener(onStateChange: _onLifecycle);
    unawaited(_services.controller.load());
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    unawaited(_messageSubscription.cancel());
    _services.controller.dispose();
    _services.quickControls.dispose();
    _services.monitor.dispose();
    _services.gamepad.dispose();
    _services.clock.dispose();
    _services.focus.dispose();
    unawaited(_services.messages.dispose());
    super.dispose();
  }

  /// Com o launcher escondido (um jogo por cima, por exemplo) nada é lido.
  void _onLifecycle(AppLifecycleState state) {
    final visible = state == AppLifecycleState.resumed;
    _services.quickControls.poller.visible = visible;
    _services.monitor.poller.visible = visible;
    _services.gamepad.poller.visible = visible;
    if (visible) unawaited(_services.controller.refreshRecents());
  }

  void _showMessage(String message) {
    _messengerKey.currentState
      ?..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  NavigatorState? get _navigator => _navigatorKey.currentState;

  bool get _overlayOpen => _navigator?.canPop() ?? false;

  bool _shows(bool Function(PanelVisibility panels) panel) =>
      panel(_services.controller.value.settings.panels);

  void _toggleQuickControls() {
    final navigator = _navigator;
    if (navigator == null) return;
    if (_quickControlsOpen) {
      navigator.pop();
      return;
    }
    if (_overlayOpen || !_shows((panels) => panels.quickControls)) return;
    _quickControlsOpen = true;
    showQuickControls(navigator).whenComplete(() => _quickControlsOpen = false);
  }

  void _openFavoritesPicker() {
    final navigator = _navigator;
    if (navigator == null || _overlayOpen) return;
    unawaited(showFavoritesPicker(navigator));
  }

  /// LB/RB trocam de seção e levam o foco para o item dela na navegação.
  void _changeTab(int delta) {
    if (_overlayOpen) return;
    _services.controller.cycleSection(delta);
    final section = _services.controller.value.section;
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _services.focus.nav[section.index].requestFocus(),
    );
  }

  /// Y leva à pesquisa (na tela inicial); a busca em si é da Fase 6.
  void _focusSearch() {
    if (_overlayOpen || !_shows((panels) => panels.search)) return;
    _services.controller.selectSection(Section.home);
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _services.focus.search.requestFocus(),
    );
  }

  ThemeMode _themeMode(LauncherSettings settings, DateTime now) {
    try {
      final minute = now.hour * _minutesPerHour + now.minute;
      return switch (widget.backend.resolveTheme(settings, minute)) {
        ResolvedTheme.light => ThemeMode.light,
        ResolvedTheme.dark => ThemeMode.dark,
      };
    } on BackendException {
      return ThemeMode.dark;
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([_services.controller, _services.clock]),
      builder: (context, _) => MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Gamer Launcher',
        navigatorKey: _navigatorKey,
        scaffoldMessengerKey: _messengerKey,
        theme: _lightTheme,
        darkTheme: _darkTheme,
        themeMode: _themeMode(
          _services.controller.value.settings,
          _services.clock.value,
        ),
        builder: (context, child) => LauncherScope(
          services: _services,
          child: InputRouter(
            actions: widget.actions,
            onClose: widget.onClose,
            onSearch: _focusSearch,
            onQuickControls: _toggleQuickControls,
            onTabChange: _changeTab,
            onError: (error) => _services.messages.show(error.toString()),
            child: child ?? const SizedBox.shrink(),
          ),
        ),
        home: const LauncherShell(),
      ),
    );
  }
}
