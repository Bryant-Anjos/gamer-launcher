import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:gamer_launcher/ui/widgets/icon_color.dart';

/// Lado da miniatura amostrada: pouca memória e trabalho, e cor de sobra.
const _sampleSide = 32;

/// Ícone maior que isso nem é lido (não é um ícone de verdade).
const maxIconBytes = 2 * 1024 * 1024;

typedef IconColorLoader = Future<Color?> Function(String path);

/// A cor principal do ícone em [path] (PNG, outros bitmaps ou SVG), lida de
/// uma miniatura. Arquivo que não abre, grande demais ou sem pixel colorido
/// dá `null`: quem chama usa a cor de reserva do nome.
Future<Color?> loadIconColor(String path) async {
  try {
    final file = File(path);
    if (await file.length() > maxIconBytes) return null;
    final image = path.toLowerCase().endsWith('.svg')
        ? await _rasterSvg(file)
        : await _rasterBitmap(file);
    try {
      final data = await image.toByteData();
      return data == null ? null : dominantColor(data.buffer.asUint8List());
    } finally {
      image.dispose();
    }
  } on Object {
    // Arquivo ilegível ou formato desconhecido: fica a cor de reserva.
    return null;
  }
}

/// Decodifica já reduzido: nunca a imagem inteira no tamanho original.
Future<ui.Image> _rasterBitmap(File file) async {
  final codec = await ui.instantiateImageCodec(
    await file.readAsBytes(),
    targetWidth: _sampleSide,
    targetHeight: _sampleSide,
  );
  try {
    return (await codec.getNextFrame()).image;
  } finally {
    codec.dispose();
  }
}

Future<ui.Image> _rasterSvg(File file) async {
  final info = await vg.loadPicture(SvgFileLoader(file), null);
  try {
    final longest = math.max(info.size.width, info.size.height);
    final recorder = ui.PictureRecorder();
    if (longest > 0) {
      Canvas(recorder)
        ..scale(_sampleSide / longest)
        ..drawPicture(info.picture);
    }
    final picture = recorder.endRecording();
    try {
      return await picture.toImage(_sampleSide, _sampleSide);
    } finally {
      picture.dispose();
    }
  } finally {
    info.picture.dispose();
  }
}

/// Cor de cada ícone, lida uma vez só por caminho e guardada na memória
/// (inclusive o "não tem cor", para não ler de novo).
class IconColorCache {
  IconColorCache({this.loader = loadIconColor});

  /// O cache do app inteiro.
  static final shared = IconColorCache();

  final IconColorLoader loader;
  final _known = <String, Color?>{};
  final _pending = <String, Future<Color?>>{};

  bool contains(String path) => _known.containsKey(path);

  Color? peek(String path) => _known[path];

  Future<Color?> resolve(String path) {
    if (_known.containsKey(path)) return Future.value(_known[path]);
    return _pending[path] ??= loader(path).then((color) {
      _known[path] = color;
      _pending.remove(path);
      return color;
    });
  }
}

/// Entrega a cor principal do ícone do app a [builder]: a de reserva do
/// nome no primeiro frame e a do ícone assim que for lida (na hora, se já
/// estava no cache).
class IconTint extends StatefulWidget {
  const IconTint({
    super.key,
    required this.name,
    required this.iconPath,
    required this.builder,
    this.cache,
  });

  final String name;
  final String? iconPath;
  final Widget Function(BuildContext context, Color color) builder;
  final IconColorCache? cache;

  @override
  State<IconTint> createState() => _IconTintState();
}

class _IconTintState extends State<IconTint> {
  Color? _iconColor;

  IconColorCache get _cache => widget.cache ?? IconColorCache.shared;

  @override
  void initState() {
    super.initState();
    _read();
  }

  @override
  void didUpdateWidget(IconTint old) {
    super.didUpdateWidget(old);
    if (old.iconPath != widget.iconPath) _read();
  }

  void _read() {
    final path = widget.iconPath;
    _iconColor = path == null ? null : _cache.peek(path);
    if (path == null || _cache.contains(path)) return;
    _cache.resolve(path).then((color) {
      if (!mounted || widget.iconPath != path) return;
      setState(() => _iconColor = color);
    });
  }

  @override
  Widget build(BuildContext context) =>
      widget.builder(context, _iconColor ?? fallbackIconColor(widget.name));
}
