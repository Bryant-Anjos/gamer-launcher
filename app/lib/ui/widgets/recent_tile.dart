import 'package:flutter/material.dart';
import 'package:gamer_launcher/src/rust/api/files.dart';
import 'package:gamer_launcher/theme/dimens.dart';
import 'package:gamer_launcher/theme/launcher_theme.dart';
import 'package:gamer_launcher/ui/widgets/focus_tile.dart';
import 'package:gamer_launcher/ui/widgets/panel_card.dart';
import 'package:gamer_launcher/util/formatting.dart';

const _folderColor = Color(0xFFF2B53A);
const _documentColor = Color(0xFF3B82F6);
const _recentIcon = 30.0;

IconData recentIcon(RecentFile file) =>
    file.isDir ? Icons.folder_rounded : Icons.description_rounded;

/// Linha de arquivo/pasta recente: ícone, nome, pasta e há quanto tempo.
class RecentTile extends StatelessWidget {
  const RecentTile({
    super.key,
    required this.file,
    required this.now,
    required this.onOpen,
  });

  final RecentFile file;
  final DateTime now;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final palette = LauncherPalette.of(context);
    return FocusTile(
      borderRadius: Dimens.smallRadius,
      semanticLabel: file.name,
      onActivate: onOpen,
      child: Container(
        color: palette.panel,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        child: Row(
          children: [
            Icon(
              recentIcon(file),
              size: _recentIcon,
              color: file.isDir ? _folderColor : _documentColor,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(file.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                  MutedText(file.location),
                ],
              ),
            ),
            const SizedBox(width: Dimens.smallGap),
            MutedText(formatRelative(file.modified, now)),
          ],
        ),
      ),
    );
  }
}
