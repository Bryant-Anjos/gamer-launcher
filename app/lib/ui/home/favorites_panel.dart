import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gamer_launcher/input/item_intents.dart';
import 'package:gamer_launcher/src/rust/api/catalog.dart';
import 'package:gamer_launcher/state/favorites_order.dart';
import 'package:gamer_launcher/state/settings_edit.dart';
import 'package:gamer_launcher/theme/dimens.dart';
import 'package:gamer_launcher/theme/launcher_theme.dart';
import 'package:gamer_launcher/ui/home/favorite_tile.dart';
import 'package:gamer_launcher/ui/home/featured_cards.dart';
import 'package:gamer_launcher/ui/launcher_scope.dart';
import 'package:gamer_launcher/ui/widgets/app_icon.dart';
import 'package:gamer_launcher/ui/widgets/icon_color_cache.dart';
import 'package:gamer_launcher/ui/home/favorites_hints.dart';
import 'package:gamer_launcher/ui/widgets/panel_card.dart';

export 'package:gamer_launcher/ui/home/favorite_tile.dart';

const addFavoriteLabel = 'Adicionar';

/// Colunas da grade de favoritos: as mesmas dos cartões de destaque, para os
/// blocos terem o mesmo tamanho e ficarem alinhados com eles.
const favoriteColumns = wideColumns;

/// Favoritos em blocos grandes, do tamanho dos cartões de destaque (como numa
/// TV), e o "Adicionar". X (ou M no teclado) num favorito começa a movê-lo:
/// o direcional muda o lugar, A grava a ordem e B desfaz. Com o mouse, é só
/// arrastar um bloco para o lugar de outro.
class FavoritesPanel extends StatefulWidget {
  const FavoritesPanel({super.key, required this.favorites});

  final List<AppInfo> favorites;

  @override
  State<FavoritesPanel> createState() => _FavoritesPanelState();
}

class _FavoritesPanelState extends State<FavoritesPanel> {
  /// Ordem provisória enquanto um favorito é movido (nada gravado ainda).
  List<String>? _draft;
  String? _moving;
  String? _focusedId;
  bool _hasFocus = false;

  List<String> get _ids => [for (final app in widget.favorites) app.id];

  List<AppInfo> get _ordered {
    final draft = _draft;
    if (draft == null) return widget.favorites;
    final byId = {for (final app in widget.favorites) app.id: app};
    return [for (final id in draft) ?byId[id]];
  }

  void _startMove() {
    final id = _focusedId;
    if (id == null || _moving != null) return;
    setState(() {
      _moving = id;
      _draft = _ids;
    });
  }

  void _cancelMove() => setState(() {
    _moving = null;
    _draft = null;
  });

  void _step(TraversalDirection direction) {
    final draft = _draft;
    final moving = _moving;
    if (draft == null || moving == null) return;
    final from = draft.indexOf(moving);
    final to = moveTarget(
      from,
      direction,
      columns: homeColumns(MediaQuery.sizeOf(context).width),
      length: draft.length,
    );
    setState(() => _draft = moveItem(draft, from, to));
  }

  /// Grava a ordem; favoritos de apps que sumiram continuam no fim.
  void _save(List<String> order) {
    final controller = LauncherScope.of(context).controller;
    controller.editSettings((current) {
      final missing = current.favorites.where((id) => !order.contains(id));
      return current.copyWith(favorites: [...order, ...missing]);
    });
  }

  void _confirmMove() {
    final draft = _draft;
    _cancelMove();
    if (draft != null) _save(draft);
  }

  void _drop(String dragged, String target) {
    final order = _ids;
    final from = order.indexOf(dragged);
    final to = order.indexOf(target);
    if (from < 0 || to < 0 || from == to) return;
    _save(moveItem(order, from, to));
  }

  void _open(AppInfo app) {
    if (_moving != null) {
      _confirmMove();
      return;
    }
    LauncherScope.of(context).controller.launchApp(app.id);
  }

  Object? _direction(DirectionalFocusIntent intent) {
    if (_moving != null) {
      _step(intent.direction);
    } else {
      FocusManager.instance.primaryFocus?.focusInDirection(intent.direction);
    }
    return null;
  }

  void _onPanelFocus(bool focused) {
    setState(() => _hasFocus = focused);
    if (!focused && _moving != null) _cancelMove();
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    mainAxisSize: MainAxisSize.min,
    children: [
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Expanded(child: SectionTitle('Aplicativos favoritos')),
          if (_moving != null)
            const MovingHints()
          else if (_hasFocus && _focusedId != null)
            const MoveHint(),
        ],
      ),
      Focus(
        canRequestFocus: false,
        skipTraversal: true,
        onFocusChange: _onPanelFocus,
        child: Shortcuts(
          shortcuts: const {
            SingleActivator(LogicalKeyboardKey.keyM): SecondaryIntent(),
          },
          child: Actions(
            actions: {
              SecondaryIntent: _WhenAction<SecondaryIntent>(
                enabledWhen: () => _focusedId != null && _moving == null,
                onInvoke: _startMove,
              ),
              CancelIntent: _WhenAction<CancelIntent>(
                enabledWhen: () => _moving != null,
                onInvoke: _cancelMove,
              ),
              DirectionalFocusIntent: CallbackAction<DirectionalFocusIntent>(
                onInvoke: _direction,
              ),
            },
            child: _grid(context),
          ),
        ),
      ),
    ],
  );

  Widget _grid(BuildContext context) {
    final services = LauncherScope.of(context);
    final height = featuredCardHeight(MediaQuery.sizeOf(context).height);
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = homeColumns(MediaQuery.sizeOf(context).width);
        final gaps = Dimens.gap * (columns - 1);
        final width = (constraints.maxWidth - gaps) / columns;
        final size = Size(width, height);
        return Wrap(
          spacing: Dimens.gap,
          runSpacing: Dimens.gap,
          children: [
            for (final app in _ordered)
              SizedBox.fromSize(
                key: ValueKey(app.id),
                size: size,
                child: _draggable(app, size),
              ),
            SizedBox.fromSize(
              size: size,
              child: FavoriteTile(
                label: addFavoriteLabel,
                icon: const Icon(
                  Icons.add_rounded,
                  size: favoriteArtIcon,
                  color: Colors.white,
                ),
                color: LauncherPalette.of(context).accent,
                onActivate: services.openFavoritesPicker,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _draggable(AppInfo app, Size size) => IconTint(
    name: app.name,
    iconPath: app.iconPath,
    builder: (context, color) => _dragTarget(app, size, color),
  );

  Widget _dragTarget(AppInfo app, Size size, Color color) {
    final tile = FavoriteTile(
      label: app.name,
      color: color,
      isMoving: _moving == app.id,
      icon: AppIcon(
        name: app.name,
        iconPath: app.iconPath,
        size: favoriteArtIcon,
      ),
      onActivate: () => _open(app),
      onFocusChange: (focused) => setState(() {
        if (focused) {
          _focusedId = app.id;
        } else if (_focusedId == app.id) {
          _focusedId = null;
        }
      }),
    );
    return DragTarget<String>(
      onAcceptWithDetails: (details) => _drop(details.data, app.id),
      builder: (context, _, _) => Draggable<String>(
        data: app.id,
        feedback: SizedBox.fromSize(size: size, child: FavoriteDragImage(app)),
        childWhenDragging: Opacity(opacity: Opacities.disabled, child: tile),
        child: tile,
      ),
    );
  }
}

/// Ação habilitada só quando [isEnabled] diz: assim B e X caem no padrão
/// (voltar ao menu, nada) quando não há o que mover.
class _WhenAction<T extends Intent> extends Action<T> {
  _WhenAction({required bool Function() enabledWhen, required this.onInvoke})
    : _enabled = enabledWhen;

  final bool Function() _enabled;
  final VoidCallback onInvoke;

  @override
  bool isEnabled(T intent) => _enabled();

  @override
  Object? invoke(T intent) {
    onInvoke();
    return null;
  }
}
