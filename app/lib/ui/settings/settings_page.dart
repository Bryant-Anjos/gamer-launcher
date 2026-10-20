import 'package:flutter/material.dart';
import 'package:gamer_launcher/src/rust/api/settings.dart';
import 'package:gamer_launcher/state/launcher_controller.dart';
import 'package:gamer_launcher/state/settings_edit.dart';
import 'package:gamer_launcher/theme/dimens.dart';
import 'package:gamer_launcher/ui/launcher_scope.dart';
import 'package:gamer_launcher/ui/pages/page_header.dart';
import 'package:gamer_launcher/ui/settings/input_settings.dart';
import 'package:gamer_launcher/ui/settings/settings_controls.dart';
import 'package:gamer_launcher/ui/settings/wallpaper_picker.dart';
import 'package:gamer_launcher/ui/widgets/panel_card.dart';

/// Personalização: tema (com horários do automático), wallpaper e painéis.
/// Cada mudança é gravada na hora pelo núcleo, que valida.
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key, required this.state});

  final LauncherState state;

  @override
  Widget build(BuildContext context) {
    final services = LauncherScope.of(context);
    final settings = state.settings;
    void edit(LauncherSettings Function(LauncherSettings current) change) =>
        services.controller.editSettings(change);
    Widget box(Widget child) => SliverToBoxAdapter(child: child);
    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.only(
            left: Dimens.focusInset,
            right: Dimens.gutter,
          ),
          sliver: SliverMainAxisGroup(
            slivers: [
              box(const PageHeader(title: 'Configurações', inset: 0)),
              box(const SectionTitle('Tema')),
              box(_ThemeChoices(settings: settings, onEdit: edit)),
              if (settings.themeMode == LauncherThemeMode.auto)
                box(
                  Padding(
                    padding: const EdgeInsets.only(top: Dimens.gap),
                    child: _Schedule(settings: settings, onEdit: edit),
                  ),
                ),
              box(const SizedBox(height: Dimens.gutter)),
              box(const SectionTitle('Wallpaper')),
              WallpaperPicker(
                selected: settings.wallpaper,
                onSelect: (path) =>
                    edit((current) => current.withWallpaper(path)),
              ),
              box(const SizedBox(height: Dimens.gutter)),
              box(const SectionTitle('Painéis da tela inicial')),
              SliverList.list(
                children: [
                  for (final kind in PanelKind.values)
                    if (kind != PanelKind.claude || services.claude != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: Dimens.smallGap),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: SwitchRow(
                            label: kind.label,
                            value: kind.isVisibleIn(settings),
                            onChanged: (visible) => edit(
                              (current) => current.withPanel(kind, visible),
                            ),
                          ),
                        ),
                      ),
                ],
              ),
              box(const SizedBox(height: Dimens.gutter)),
              box(const SectionTitle('Botões do controle')),
              box(ButtonLayoutChoices(settings: settings, onEdit: edit)),
              box(const SizedBox(height: Dimens.gutter)),
              box(const SectionTitle('Sons e animações')),
              box(FeedbackSwitches(settings: settings, onEdit: edit)),
              box(const SizedBox(height: Dimens.gutter)),
              box(const SectionTitle('Ao ligar o computador')),
              box(
                Align(
                  alignment: Alignment.centerLeft,
                  child: ValueListenableBuilder(
                    valueListenable: services.autostart,
                    builder: (context, enabled, _) => SwitchRow(
                      label: 'Iniciar com o sistema',
                      value: enabled ?? false,
                      onWord: 'ligado',
                      offWord: 'desligado',
                      onChanged: services.autostart.set,
                    ),
                  ),
                ),
              ),
              box(
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: Dimens.gutter),
                  child: MutedText('Núcleo ${services.coreVersion}'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ThemeChoices extends StatelessWidget {
  const _ThemeChoices({required this.settings, required this.onEdit});

  final LauncherSettings settings;
  final SettingsEdit onEdit;

  @override
  Widget build(BuildContext context) {
    ChoiceTile choice(LauncherThemeMode mode, String label, IconData icon) =>
        ChoiceTile(
          label: label,
          icon: icon,
          selected: settings.themeMode == mode,
          onSelect: () =>
              onEdit((current) => current.copyWith(themeMode: mode)),
        );
    return Wrap(
      spacing: Dimens.gap,
      runSpacing: Dimens.gap,
      children: [
        choice(LauncherThemeMode.light, 'Claro', Icons.light_mode_rounded),
        choice(LauncherThemeMode.dark, 'Escuro', Icons.dark_mode_rounded),
        choice(LauncherThemeMode.auto, 'Automático', Icons.schedule_rounded),
      ],
    );
  }
}

class _Schedule extends StatelessWidget {
  const _Schedule({required this.settings, required this.onEdit});

  final LauncherSettings settings;
  final SettingsEdit onEdit;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      TimeStepper(
        label: 'Escuro a partir de',
        minute: settings.darkStartsMinute,
        onChanged: (minute) =>
            onEdit((current) => current.copyWith(darkStartsMinute: minute)),
      ),
      const SizedBox(height: Dimens.smallGap),
      TimeStepper(
        label: 'Claro a partir de',
        minute: settings.lightStartsMinute,
        onChanged: (minute) =>
            onEdit((current) => current.copyWith(lightStartsMinute: minute)),
      ),
    ],
  );
}
