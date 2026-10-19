import 'package:flutter/material.dart';
import 'package:gamer_launcher/src/rust/api/files.dart';
import 'package:gamer_launcher/theme/dimens.dart';
import 'package:gamer_launcher/ui/launcher_scope.dart';
import 'package:gamer_launcher/ui/widgets/panel_card.dart';
import 'package:gamer_launcher/ui/widgets/recent_tile.dart';

/// A tela inicial mostra só os mais novos; a lista inteira fica em Arquivos.
const homeRecentsCount = 3;
const noRecentsText = 'Nada recente por aqui.';

class RecentsPanel extends StatelessWidget {
  const RecentsPanel({super.key, required this.recents});

  final List<RecentFile> recents;

  @override
  Widget build(BuildContext context) {
    final services = LauncherScope.of(context);
    final shown = recents.take(homeRecentsCount).toList();
    return PanelCard(
      title: 'Recentes',
      surface: false,
      child: shown.isEmpty
          ? const MutedText(noRecentsText)
          : ValueListenableBuilder(
              valueListenable: services.clock,
              builder: (context, now, _) => Column(
                children: [
                  for (final file in shown)
                    Padding(
                      padding: const EdgeInsets.only(bottom: Dimens.smallGap),
                      child: RecentTile(
                        file: file,
                        now: now,
                        onOpen: () => services.controller.openRecent(file),
                      ),
                    ),
                ],
              ),
            ),
    );
  }
}
