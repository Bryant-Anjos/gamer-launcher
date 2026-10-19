import 'package:flutter/material.dart';
import 'package:gamer_launcher/state/launcher_controller.dart';
import 'package:gamer_launcher/theme/dimens.dart';
import 'package:gamer_launcher/ui/home/recents_panel.dart';
import 'package:gamer_launcher/ui/launcher_scope.dart';
import 'package:gamer_launcher/ui/pages/page_header.dart';
import 'package:gamer_launcher/ui/widgets/recent_tile.dart';

const _listMaxWidth = 900.0;

/// Arquivos: a lista completa de arquivos e pastas recentes.
class FilesPage extends StatelessWidget {
  const FilesPage({super.key, required this.state});

  final LauncherState state;

  @override
  Widget build(BuildContext context) {
    final services = LauncherScope.of(context);
    final recents = state.recents;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const PageHeader(
          title: 'Arquivos',
          subtitle: 'Arquivos e pastas abertos recentemente',
        ),
        Expanded(
          child: recents.isEmpty
              ? const EmptyState(
                  icon: Icons.folder_off_rounded,
                  text: noRecentsText,
                )
              : Align(
                  alignment: Alignment.topLeft,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: _listMaxWidth),
                    child: ValueListenableBuilder(
                      valueListenable: services.clock,
                      builder: (context, now, _) => ListView.separated(
                        padding: const EdgeInsets.all(Dimens.smallGap),
                        itemCount: recents.length,
                        separatorBuilder: (_, _) =>
                            const SizedBox(height: Dimens.smallGap),
                        itemBuilder: (context, index) => RecentTile(
                          file: recents[index],
                          now: now,
                          onOpen: () =>
                              services.controller.openRecent(recents[index]),
                        ),
                      ),
                    ),
                  ),
                ),
        ),
      ],
    );
  }
}
