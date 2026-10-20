import 'package:flutter/material.dart';
import 'package:gamer_launcher/src/rust/api/system.dart';
import 'package:gamer_launcher/theme/dimens.dart';
import 'package:gamer_launcher/theme/launcher_theme.dart';
import 'package:gamer_launcher/ui/launcher_scope.dart';
import 'package:gamer_launcher/ui/widgets/focus_tile.dart';
import 'package:gamer_launcher/ui/widgets/panel_card.dart';

const _menuWidth = 420.0;

/// Uma opção do menu; [action] vazio é "fechar o launcher".
class _Option {
  const _Option(this.label, this.icon, this.action, {this.confirmTitle});

  final String label;
  final IconData icon;
  final PowerAction? action;

  /// Pergunta antes de executar; vazio executa na hora.
  final String? confirmTitle;
}

const _options = [
  _Option('Suspender', Icons.bedtime_rounded, PowerAction.suspend),
  _Option(
    'Reiniciar',
    Icons.restart_alt_rounded,
    PowerAction.reboot,
    confirmTitle: 'Reiniciar o computador?',
  ),
  _Option(
    'Desligar',
    Icons.power_settings_new_rounded,
    PowerAction.shutdown,
    confirmTitle: 'Desligar o computador?',
  ),
  _Option(
    'Encerrar sessão',
    Icons.logout_rounded,
    PowerAction.logOut,
    confirmTitle: 'Encerrar a sessão?',
  ),
  _Option('Fechar o launcher', Icons.close_rounded, null),
];

/// Energia e saída: suspender, reiniciar, desligar, encerrar a sessão e
/// fechar o próprio launcher. O que derruba a sessão pede confirmação, com
/// "Cancelar" já focado; B volta um passo e depois fecha o menu.
class PowerMenu extends StatefulWidget {
  const PowerMenu({super.key});

  @override
  State<PowerMenu> createState() => _PowerMenuState();
}

class _PowerMenuState extends State<PowerMenu> {
  _Option? _confirming;

  void _choose(_Option option) {
    if (option.confirmTitle != null) {
      setState(() => _confirming = option);
      return;
    }
    _run(option);
  }

  void _run(_Option option) {
    final services = LauncherScope.of(context);
    Navigator.of(context).pop();
    final action = option.action;
    if (action == null) {
      services.closeLauncher();
    } else {
      services.power.perform(action);
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = LauncherPalette.of(context);
    final confirming = _confirming;
    return PopScope(
      canPop: confirming == null,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) setState(() => _confirming = null);
      },
      child: Center(
        child: SizedBox(
          width: _menuWidth,
          child: Material(
            color: palette.background,
            borderRadius: BorderRadius.circular(Dimens.radius),
            child: Padding(
              padding: const EdgeInsets.all(Dimens.gutter),
              child: confirming == null
                  ? _OptionList(onChoose: _choose)
                  : _Confirmation(
                      option: confirming,
                      onCancel: () => setState(() => _confirming = null),
                      onConfirm: () => _run(confirming),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

class _OptionList extends StatelessWidget {
  const _OptionList({required this.onChoose});

  final ValueChanged<_Option> onChoose;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const SectionTitle('Energia'),
      const MutedText('A escolhe · B fecha'),
      const SizedBox(height: Dimens.gap),
      for (final (index, option) in _options.indexed)
        Padding(
          padding: const EdgeInsets.only(bottom: Dimens.smallGap),
          child: _OptionTile(
            label: option.label,
            icon: option.icon,
            autofocus: index == 0,
            onActivate: () => onChoose(option),
          ),
        ),
    ],
  );
}

class _Confirmation extends StatelessWidget {
  const _Confirmation({
    required this.option,
    required this.onCancel,
    required this.onConfirm,
  });

  final _Option option;
  final VoidCallback onCancel;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      SectionTitle(option.confirmTitle ?? option.label),
      const MutedText('Salve o que estiver aberto antes de continuar.'),
      const SizedBox(height: Dimens.gap),
      // Cancelar primeiro e focado: um A distraído não derruba a sessão
      _OptionTile(
        label: 'Cancelar',
        icon: Icons.arrow_back_rounded,
        autofocus: true,
        onActivate: onCancel,
      ),
      const SizedBox(height: Dimens.smallGap),
      _OptionTile(
        label: option.label,
        icon: option.icon,
        onActivate: onConfirm,
        emphasized: true,
      ),
    ],
  );
}

class _OptionTile extends StatelessWidget {
  const _OptionTile({
    required this.label,
    required this.icon,
    required this.onActivate,
    this.autofocus = false,
    this.emphasized = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback onActivate;
  final bool autofocus;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final palette = LauncherPalette.of(context);
    final foreground = emphasized ? palette.onAccent : palette.textPrimary;
    return FocusTile(
      autofocus: autofocus,
      semanticLabel: label,
      borderRadius: Dimens.smallRadius,
      onActivate: onActivate,
      child: Container(
        color: emphasized ? palette.accent : palette.panel,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Icon(icon, color: foreground),
            const SizedBox(width: 14),
            Text(label, style: TextStyle(color: foreground, fontSize: 16)),
          ],
        ),
      ),
    );
  }
}
