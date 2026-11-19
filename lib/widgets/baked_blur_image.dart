import 'dart:async';
import 'dart:ui' as ui;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../core/constants/api_endpoints.dart';

/// A heavily blurred version of a network image that costs nothing per frame.
///
/// A live `ImageFiltered`/`BackdropFilter` blur is re-run on every frame under
/// Impeller (there is no raster cache), which is what made scrolling over the
/// detail poster lag. Here the image is decoded tiny, blurred once on a
/// [ui.PictureRecorder] with a fade-out baked into its alpha, and the result
/// is shown as a plain bitmap. Upscaling a blurred thumbnail is visually
/// indistinguishable from blurring the full-size image.
///
/// Results are cached per URL, so revisiting a series is instant.
class BakedBlurImage extends StatefulWidget {
  final String imageUrl;
  final double sigma;
  final double opacity;

  /// Fraction of the height (from the top) that stays fully opaque before the
  /// fade to transparent begins.
  final double fadeStart;

  const BakedBlurImage({
    super.key,
    required this.imageUrl,
    this.sigma = 6,
    this.opacity = 0.75,
    this.fadeStart = 0.45,
  });

  @override
  State<BakedBlurImage> createState() => _BakedBlurImageState();
}

class _BakedBlurImageState extends State<BakedBlurImage> {
  // Thumbnail width the blur is computed at. Small on purpose: blur cost and
  // memory scale with pixels, and the result is upscaled smoothly anyway.
  static const int _bakeWidth = 72;
  static final Map<String, ui.Image> _cache = {};
  static final List<String> _lru = [];
  static const int _maxCached = 12;

  ui.Image? _image;
  ImageStream? _stream;
  ImageStreamListener? _listener;

  /// width / height of the box the image is shown in. The bitmap is baked at
  /// this exact shape so the fade ends precisely at the box's bottom edge.
  double? _aspect;

  String get _key =>
      '${widget.imageUrl}|${widget.sigma}|${widget.opacity}|${widget.fadeStart}|${_aspect?.toStringAsFixed(2)}';

  @override
  void didUpdateWidget(covariant BakedBlurImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageUrl != widget.imageUrl) {
      _stopListening();
      _image = null;
      if (_aspect != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _resolve();
        });
      }
    }
  }

  void _resolve() {
    final url = widget.imageUrl.trim();
    if (url.isEmpty) return;

    if (_aspect == null) return;
    final cached = _cache[_key];
    if (cached != null) {
      setState(() => _image = cached);
      return;
    }
    final key = _key;

    final provider = ResizeImage(
      CachedNetworkImageProvider(url, headers: ApiEndpoints.imageHeaders),
      width: _bakeWidth,
      policy: ResizeImagePolicy.fit,
    );
    _stream = provider.resolve(ImageConfiguration.empty);
    _listener = ImageStreamListener((info, _) {
      _stopListening();
      _bake(info.image).then((baked) {
        info.dispose();
        if (baked == null) return;
        _remember(key, baked);
        if (mounted) setState(() => _image = baked);
      });
    }, onError: (_, _) => _stopListening());
    _stream!.addListener(_listener!);
  }

  Future<ui.Image?> _bake(ui.Image src) async {
    try {
      final aspect = _aspect ?? (src.width / src.height);
      final srcW = src.width.toDouble();
      final srcH = src.height.toDouble();

      // Output: the display box's shape at thumbnail resolution.
      final w = _bakeWidth.toDouble();
      final h = (w / aspect).clamp(8.0, 512.0).roundToDouble();

      // "Cover" crop of the source, anchored to the top (posters keep faces up top).
      final scale = (w / srcW) > (h / srcH) ? w / srcW : h / srcH;
      final cropW = w / scale;
      final cropH = h / scale;
      final srcRect = Rect.fromLTWH((srcW - cropW) / 2, 0, cropW, cropH);

      // Pad by the blur radius so edges don't darken (decal) or smear (clamp).
      final pad = (widget.sigma * 3).ceilToDouble();

      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, w, h));

      canvas.saveLayer(Rect.fromLTWH(0, 0, w, h), Paint());
      // 1. Blurred image (slightly overscaled so the blurred edge falls outside)
      canvas.drawImageRect(
        src,
        srcRect,
        Rect.fromLTWH(-pad, -pad, w + pad * 2, h + pad * 2),
        Paint()
          ..filterQuality = FilterQuality.medium
          ..imageFilter = ui.ImageFilter.blur(
            sigmaX: widget.sigma,
            sigmaY: widget.sigma,
            tileMode: TileMode.clamp,
          ),
      );
      // 2. Fade-to-transparent mask + overall opacity baked into alpha
      canvas.drawRect(
        Rect.fromLTWH(0, 0, w, h),
        Paint()
          ..blendMode = BlendMode.dstIn
          ..shader = ui.Gradient.linear(
            Offset.zero,
            Offset(0, h),
            [
              Color.fromRGBO(255, 255, 255, widget.opacity),
              Color.fromRGBO(255, 255, 255, widget.opacity),
              const Color(0x00FFFFFF),
            ],
            [0.0, widget.fadeStart, 1.0],
          ),
      );
      canvas.restore();

      final picture = recorder.endRecording();
      final image = await picture.toImage(w.round(), h.round());
      picture.dispose();
      return image;
    } catch (e) {
      debugPrint('BakedBlurImage: $e');
      return null;
    }
  }

  static void _remember(String key, ui.Image image) {
    _cache[key] = image;
    _lru
      ..remove(key)
      ..add(key);
    while (_lru.length > _maxCached) {
      _cache.remove(_lru.removeAt(0))?.dispose();
    }
  }

  void _stopListening() {
    if (_stream != null && _listener != null) {
      _stream!.removeListener(_listener!);
    }
    _stream = null;
    _listener = null;
  }

  @override
  void dispose() {
    _stopListening();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.hasBoundedWidth &&
            constraints.hasBoundedHeight &&
            constraints.maxHeight > 0) {
          final aspect = constraints.maxWidth / constraints.maxHeight;
          if (_aspect == null || (aspect - _aspect!).abs() > 0.01) {
            _aspect = aspect;
            // Resolve after this frame; layout is not the place to start work.
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) return;
              _stopListening();
              final cached = _cache[_key];
              if (cached != null) {
                setState(() => _image = cached);
              } else {
                _resolve();
              }
            });
          }
        }

        final image = _image;
        return AnimatedOpacity(
          opacity: image == null ? 0 : 1,
          duration: const Duration(milliseconds: 300),
          child: image == null
              ? const SizedBox.expand()
              : RawImage(
                  image: image,
                  width: constraints.maxWidth,
                  height: constraints.maxHeight,
                  // Baked at the box's exact shape, so fill == no crop.
                  fit: BoxFit.fill,
                  // Smooth upscale: a blurred thumbnail has no detail to lose,
                  // so this reads as a full-resolution blur.
                  filterQuality: FilterQuality.medium,
                ),
        );
      },
    );
  }
}
