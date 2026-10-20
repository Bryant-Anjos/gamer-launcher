import 'dart:async';

import 'package:flutter/material.dart';
import 'package:gamer_launcher/backend/launcher_backend.dart';
import 'package:gamer_launcher/input/content_focus.dart';
import 'package:gamer_launcher/input/input_router.dart';
import 'package:gamer_launcher/src/rust/api/input.dart';
import 'package:gamer_launcher/src/rust/api/settings.dart';
import 'package:gamer_launcher/state/clock.dart';
import 'package:gamer_launcher/state/autostart_controller.dart';
import 'package:gamer_launcher/state/bluetooth_devices_controller.dart';
import 'package:gamer_launcher/state/claude_controller.dart';
import 'package:gamer_launcher/state/gamepad_status.dart';
import 'package:gamer_launcher/state/launcher_controller.dart';
import 'package:gamer_launcher/state/messages.dart';
import 'package:gamer_launcher/state/power_controller.dart';
import 'package:gamer_launcher/state/quick_controls_controller.dart';
import 'package:gamer_launcher/state/system_monitor.dart';
import 'package:gamer_launcher/state/ui_sounds.dart';
import 'package:gamer_launcher/theme/dimens.dart';
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
    final controller = LauncherController(backend, messages);
    _services = LauncherServices(
      backend: backend,
      controller: controller,
      quickControls: QuickControlsController(backend, messages),
      monitor: SystemMonitor(backend.sampleStats, onError: messages.show),
      gamepad: GamepadStatus(
        backend.gamepadConnected,
        detectLayout: backend.detectedButtonLayout,
      ),
      clock: Clock(now: widget.now),
      focus: LauncherFocus(),
      messages: messages,
      coreVersion: widget.coreVersion,
      openFavoritesPicker: _openFavoritesPicker,
      power: PowerController(backend, messages),
      autostart: AutostartController(backend, messages),
      openPowerMenu: _openPowerMenu,
      closeLauncher: widget.onClose,
      sounds: UiSounds(
        backend,
        messages,
        isEnabled: () => controller.value.settings.sounds,
      ),
      bluetoothDevices: BluetoothDevicesController(backend, messages),
      openSearch: _openSearch,
      enterContent: _enterContent,
      claude: _claudeIfInstalled(backend),
    );
    _messageSubscription = messages.stream.listen(_showMessage);
    _lifecycle = AppLifecycleListener(onStateChange: _onLifecycle);
    unawaited(_services.controller.load());
    unawaited(_services.autostart.load());
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    unawaited(_messageSubscription.cancel());
    _services.controller.dispose();
    _services.quickControls.dispose();
    _services.power.dispose();
    _services.autostart.dispose();
    _services.bluetoothDevices.dispose();
    _services.claude?.dispose();
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
    _services.power.poller.visible = visible;
    _services.bluetoothDevices.poller.visible = visible;
    for (final poller in _services.claude?.pollers ?? const []) {
      poller.visible = visible;
    }
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

  void _openPowerMenu() {
    final navigator = _navigator;
    if (navigator == null || _overlayOpen) return;
    unawaited(showPowerMenu(navigator));
  }

  /// Só com o Claude Code instalado; na dúvida (a ponte falhou), sem ele.
  ClaudeController? _claudeIfInstalled(LauncherBackend backend) {
    try {
      if (!backend.claudeInstalled()) return null;
    } on BackendException {
      return null;
    }
    return ClaudeController(backend, now: widget.now);
  }

  /// Depois do próximo quadro: a página da seção pode ter acabado de trocar.
  void _afterFrame(VoidCallback action) {
    WidgetsBinding.instance
      ..addPostFrameCallback((_) => action())
      ..ensureVisualUpdate();
  }

  /// A num item da navegação (ou a direita): o primeiro item da página.
  void _enterContent() =>
      _afterFrame(() => firstItemIn(_services.focus.content)?.requestFocus());

  /// B no conteúdo: o foco volta ao item da seção atual na navegação.
  void _backToMenu() {
    if (_overlayOpen) return;
    final section = _services.controller.value.section;
    _services.focus.nav[section.index].requestFocus();
  }

  /// Botão Home do controle: fecha o painel aberto (se houver), vai para o
  /// Início e leva o foco ao item dele na navegação. Não fecha o app.
  void _goHome() {
    _navigator?.popUntil((route) => route.isFirst);
    _services.controller.selectSection(Section.home);
    _afterFrame(() => _services.focus.nav[Section.home.index].requestFocus());
  }

  /// LB/RB trocam de seção e levam o foco para o item dela na navegação.
  void _changeTab(int delta) {
    if (_overlayOpen) return;
    _services.controller.cycleSection(delta, among: _services.sections);
    final section = _services.controller.value.section;
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _services.focus.nav[section.index].requestFocus(),
    );
  }

  /// Y abre a pesquisa por cima da seção atual (não com o painel de
  /// pesquisa oculto nas configurações, nem com outro painel aberto).
  void _openSearch([String initialText = '']) {
    final navigator = _navigator;
    if (navigator == null || _overlayOpen) return;
    if (!_shows((panels) => panels.search)) return;
    unawaited(showSearchOverlay(navigator, initialText));
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

  void _playFeedback(GamepadAction action) {
    final sound = soundFor(action);
    if (sound != null) _services.sounds.play(sound);
  }

  /// "Reduzir animações" vale como o pedido do sistema: as telas leem
  /// `MediaQuery.disableAnimations` (veja [Motion.of]). O `MediaQuery` fica
  /// sempre na árvore, para ligar e desligar não recriar o `Navigator`.
  Widget _withMotion(BuildContext context, Widget child) {
    final media = MediaQuery.of(context);
    final reduce = _services.controller.value.settings.reduceAnimations;
    return MediaQuery(
      data: media.copyWith(
        disableAnimations: media.disableAnimations || reduce,
      ),
      child: child,
    );
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
        themeAnimationDuration:
            _services.controller.value.settings.reduceAnimations
            ? Duration.zero
            : kThemeAnimationDuration,
        builder: (context, child) => _withMotion(
          context,
          LauncherScope(
            services: _services,
            child: InputRouter(
              actions: widget.actions,
              onClose: widget.onClose,
              onHome: _goHome,
              onSearch: _openSearch,
              onQuickControls: _toggleQuickControls,
              onTabChange: _changeTab,
              onError: (error) => _services.messages.show(error.toString()),
              onFeedback: _playFeedback,
              onBackToMenu: _backToMenu,
              child: child ?? const SizedBox.shrink(),
            ),
          ),
        ),
        home: const LauncherShell(),
      ),
    );
  }
}
