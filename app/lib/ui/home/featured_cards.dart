import 'package:flutter/material.dart';
import 'package:gamer_launcher/state/launcher_controller.dart';
import 'package:gamer_launcher/theme/dimens.dart';
import 'package:gamer_launcher/theme/launcher_theme.dart';
import 'package:gamer_launcher/ui/launcher_scope.dart';
import 'package:gamer_launcher/ui/widgets/app_icon.dart';
import 'package:gamer_launcher/ui/widgets/focus_tile.dart';

const _cardIcon = 34.0;
const _artIcon = 72.0;
const _artIconAlpha = 0.35;
const _captionAlpha = 0.55;

/// Cartão sem ação fica apagado, mas legível (diz por que está assim).
const _disabledCardOpacity = 0.75;

/// Fração da altura da tela ocupada pelos cartões, com limites.
const _heightFraction = 0.28;
const _maxCardHeight = 340.0;

double featuredCardHeight(double screenHeight) =>
    (screenHeight * _heightFraction).clamp(
      Dimens.featuredCardHeight,
      _maxCardHeight,
    );

/// Colunas da tela inicial (cartões de destaque e favoritos): em telas estreitas
/// (notebook de 1366 px) cabem dois blocos por linha, grandes como nas telas
/// largas, em vez de quatro pequenos ao lado de um painel lateral largo.
const wideColumns = 4;
const _narrowScreenWidth = 1500.0;

int homeColumns(double screenWidth) =>
    screenWidth < _narrowScreenWidth ? 2 : wideColumns;

/// Os quatro cartões de destaque: Continuar, Projetos, Jogos e Músicas.
class FeaturedCards extends StatelessWidget {
  const FeaturedCards({super.key, required this.state});

  final LauncherState state;

  @override
  Widget build(BuildContext context) {
    final controller = LauncherScope.of(context).controller;
    final lastApp = state.lastApp;
    final games = state.gameLaunchers;
    final music = state.musicPlayer;
    final cards = [
      FeaturedCard(
        title: 'Continuar',
        subtitle: lastApp?.name ?? 'Nenhum app aberto ainda',
        gradient: CardGradients.resume,
        art: Icons.play_arrow_rounded,
        leading: lastApp == null
            ? const Icon(Icons.history_rounded, size: _cardIcon)
            : AppIcon(
                name: lastApp.name,
                iconPath: lastApp.iconPath,
                size: _cardIcon,
              ),
        onActivate: lastApp == null
            ? null
            : () => controller.launchApp(lastApp.id),
      ),
      FeaturedCard(
        title: 'Projetos',
        subtitle: '${state.recents.length} itens recentes',
        gradient: CardGradients.projects,
        art: Icons.forest_rounded,
        leading: const Icon(Icons.folder_rounded, size: _cardIcon),
        onActivate: () => controller.selectSection(Section.files),
      ),
      FeaturedCard(
        title: 'Jogos',
        subtitle: games.isEmpty
            ? 'Steam, Heroic ou Lutris não encontrados'
            : 'Iniciar biblioteca',
        gradient: CardGradients.games,
        art: Icons.directions_car_filled_rounded,
        leading: const Icon(Icons.sports_esports_rounded, size: _cardIcon),
        onActivate: switch (games.length) {
          0 => null,
          1 => () => controller.launchApp(games.single.id),
          _ => () => controller.selectSection(Section.games),
        },
      ),
      FeaturedCard(
        title: 'Músicas',
        subtitle: music == null ? 'Nenhum player encontrado' : 'Abrir player',
        gradient: CardGradients.music,
        art: Icons.headphones_rounded,
        leading: const Icon(Icons.music_note_rounded, size: _cardIcon),
        onActivate: music == null ? null : () => controller.launchApp(music.id),
      ),
    ];
    final screen = MediaQuery.sizeOf(context);
    final height = featuredCardHeight(screen.height);
    final columns = homeColumns(screen.width);
    Widget row(List<Widget> items) => SizedBox(
      height: height,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final (index, card) in items.indexed) ...[
            if (index > 0) const SizedBox(width: Dimens.gap),
            Expanded(child: card),
          ],
        ],
      ),
    );
    if (columns >= cards.length) return row(cards);
    return Column(
      children: [
        for (var start = 0; start < cards.length; start += columns) ...[
          if (start > 0) const SizedBox(height: Dimens.gap),
          row(cards.sublist(start, (start + columns).clamp(0, cards.length))),
        ],
      ],
    );
  }
}

/// Cartão com "arte" em degradê em cima e título embaixo, como na arte de
/// conceito (que usa ilustrações; aqui não há imagens próprias).
class FeaturedCard extends StatelessWidget {
  const FeaturedCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.gradient,
    required this.art,
    required this.leading,
    required this.onActivate,
  });

  final String title;
  final String subtitle;
  final List<Color> gradient;
  final IconData art;
  final Widget leading;
  final VoidCallback? onActivate;

  @override
  Widget build(BuildContext context) {
    final palette = LauncherPalette.of(context);
    final card = FocusTile(
      onActivate: onActivate,
      semanticLabel: '$title: $subtitle',
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: gradient,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Icon(
                art,
                size: _artIcon,
                color: Colors.white.withValues(alpha: _artIconAlpha),
              ),
            ),
            Container(
              color: Colors.black.withValues(alpha: _captionAlpha),
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  IconTheme(
                    data: const IconThemeData(color: Colors.white),
                    child: leading,
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: _caption(palette)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
    return onActivate == null
        ? Opacity(opacity: _disabledCardOpacity, child: card)
        : card;
  }

  Widget _caption(LauncherPalette palette) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(
        title,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w600,
          fontSize: 16,
        ),
      ),
      Text(
        subtitle,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(color: Colors.white70, fontSize: 13),
      ),
    ],
  );
}
