import 'dart:io';

import 'package:flutter/material.dart';
import 'package:gamer_launcher/backend/launcher_backend.dart';
import 'package:gamer_launcher/theme/dimens.dart';
import 'package:gamer_launcher/theme/launcher_theme.dart';
import 'package:gamer_launcher/ui/launcher_scope.dart';
import 'package:gamer_launcher/ui/widgets/focus_tile.dart';
import 'package:gamer_launcher/ui/widgets/panel_card.dart';

const wallpaperLimit = 60;
const noWallpaperLabel = 'Nenhum';
const _checkSize = 26.0;

/// Escolha do wallpaper entre as imagens da pasta de imagens e as do
/// sistema, ou nenhum. É um sliver (vai num `CustomScrollView`); as
/// miniaturas são decodificadas pequenas e só quando aparecem.
class WallpaperPicker extends StatefulWidget {
  const WallpaperPicker({
    super.key,
    required this.selected,
    required this.onSelect,
  });

  final String? selected;
  final ValueChanged<String?> onSelect;

  @override
  State<WallpaperPicker> createState() => _WallpaperPickerState();
}

class _WallpaperPickerState extends State<WallpaperPicker> {
  Future<List<String>>? _images;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _images ??= LauncherScope.of(context).backend
        .listWallpapers(wallpaperLimit);
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<List<String>>(
    future: _images,
    builder: (context, snapshot) {
      final error = snapshot.error;
      final images = snapshot.data ?? const <String>[];
      final paths = <String?>[null, ...images];
      // sliver: só as miniaturas na tela são montadas e decodificadas
      return SliverMainAxisGroup(
        slivers: [
          if (error != null)
            SliverToBoxAdapter(
              child: MutedText(
                'Não foi possível listar as imagens: '
                '${error is BackendException ? error.message : error}',
              ),
            ),
          SliverGrid.builder(
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: Dimens.wallpaperThumbWidth + Dimens.gap,
              mainAxisExtent: Dimens.wallpaperThumbHeight,
              mainAxisSpacing: Dimens.gap,
              crossAxisSpacing: Dimens.gap,
            ),
            itemCount: paths.length,
            itemBuilder: (context, index) => WallpaperTile(
              path: paths[index],
              isSelected: widget.selected == paths[index],
              onSelect: () => widget.onSelect(paths[index]),
            ),
          ),
        ],
      );
    },
  );
}

class WallpaperTile extends StatelessWidget {
  const WallpaperTile({
    super.key,
    required this.path,
    required this.isSelected,
    required this.onSelect,
  });

  final String? path;
  final bool isSelected;
  final VoidCallback onSelect;

  @override
  Widget build(BuildContext context) {
    final palette = LauncherPalette.of(context);
    final image = path;
    final pixels =
        (Dimens.wallpaperThumbWidth * MediaQuery.devicePixelRatioOf(context))
            .round();
    final name = image?.split(Platform.pathSeparator).last ?? noWallpaperLabel;
    return FocusTile(
      semanticLabel: '$name${isSelected ? ', selecionado' : ''}',
      borderRadius: Dimens.smallRadius,
      onActivate: onSelect,
      child: SizedBox(
        width: Dimens.wallpaperThumbWidth,
        height: Dimens.wallpaperThumbHeight,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (image == null)
              ColoredBox(
                color: palette.background,
                child: const Center(child: Text(noWallpaperLabel)),
              )
            else
              Image.file(
                File(image),
                fit: BoxFit.cover,
                cacheWidth: pixels,
                errorBuilder: (_, _, _) => ColoredBox(
                  color: palette.tile,
                  child: const Icon(Icons.broken_image_rounded),
                ),
              ),
            if (isSelected)
              Align(
                alignment: Alignment.topRight,
                child: Padding(
                  padding: const EdgeInsets.all(6),
                  child: Icon(
                    Icons.check_circle_rounded,
                    color: palette.accent,
                    size: _checkSize,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
