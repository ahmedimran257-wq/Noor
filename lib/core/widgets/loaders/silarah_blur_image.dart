// SILARAH — Reusable BlurHash Network Image
// progressive loading: renders blurred placeholder → crossfades to network image
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:blurhash_dart/blurhash_dart.dart';
import 'package:image/image.dart' as img;
import 'package:cached_network_image/cached_network_image.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_dimensions.dart';
import '../../theme/silarah_spring.dart';

class SilarahBlurImage extends StatefulWidget {
  const SilarahBlurImage({
    super.key,
    required this.imageUrl,
    this.blurhash,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
    this.onImageError,
  });

  final String imageUrl;
  final String? blurhash;
  final BoxFit fit;
  final double? width;
  final double? height;
  final VoidCallback? onImageError;

  @override
  State<SilarahBlurImage> createState() => _SilarahBlurImageState();
}

class _SilarahBlurImageState extends State<SilarahBlurImage> {
  // Photos are stored up to 720 px wide; decoding wider buys nothing.
  static const _maxDecodeWidth = 720;
  // Scrolling lists rebuild the same rows repeatedly. Keep decoded blurhash
  // placeholders so each one is computed once per app session.
  static const _placeholderCacheLimit = 200;
  static final _placeholderCache = <String, Uint8List>{};

  Uint8List? _placeholderBytes;
  bool _reportedImageError = false;

  @override
  void initState() {
    super.initState();
    _placeholderBytes = _cachedPlaceholder(widget.blurhash);
    if (_placeholderBytes == null) _decodePlaceholder();
  }

  static Uint8List? _cachedPlaceholder(String? blurhash) {
    if (blurhash == null || blurhash.isEmpty) return null;
    final cached = _placeholderCache.remove(blurhash);
    if (cached != null) _placeholderCache[blurhash] = cached;
    return cached;
  }

  static void _rememberPlaceholder(String blurhash, Uint8List bytes) {
    _placeholderCache[blurhash] = bytes;
    if (_placeholderCache.length > _placeholderCacheLimit) {
      _placeholderCache.remove(_placeholderCache.keys.first);
    }
  }

  @override
  void didUpdateWidget(SilarahBlurImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageUrl != widget.imageUrl) {
      _reportedImageError = false;
    }
    if (oldWidget.blurhash != widget.blurhash) {
      final cached = _cachedPlaceholder(widget.blurhash);
      if (cached != null) {
        setState(() => _placeholderBytes = cached);
      } else {
        _decodePlaceholder();
      }
    }
  }

  void _reportImageError() {
    if (_reportedImageError || widget.onImageError == null) return;
    _reportedImageError = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.onImageError?.call();
    });
  }

  Future<void> _decodePlaceholder() async {
    if (widget.blurhash == null || widget.blurhash!.isEmpty) {
      if (mounted) setState(() => _placeholderBytes = null);
      return;
    }

    try {
      final hash = widget.blurhash!;
      final bytes = await Future.microtask(() {
        final blurHash = BlurHash.decode(hash);
        // Using small resolution for faster decoding and memory efficiency.
        // BMP skips JPEG compression work on the UI thread.
        final image = blurHash.toImage(32, 32);
        return Uint8List.fromList(img.encodeBmp(image));
      });
      _rememberPlaceholder(hash, bytes);

      if (mounted && widget.blurhash == hash) {
        setState(() {
          _placeholderBytes = bytes;
        });
      }
    } catch (e) {
      debugPrint('Error decoding blurhash: $e');
      if (mounted) {
        setState(() {
          _placeholderBytes = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget placeholder;
    if (_placeholderBytes != null) {
      placeholder = Image.memory(
        _placeholderBytes!,
        fit: widget.fit,
        width: widget.width,
        height: widget.height,
      );
    } else {
      placeholder = Container(
        color: AppColors.surfaceGlassHover,
        width: widget.width,
        height: widget.height,
      );
    }

    final width = widget.width;
    final height = widget.height;
    if (width != null && height != null) {
      return _network(placeholder, _decodeWidth(context, width, height));
    }
    return LayoutBuilder(
      builder: (context, constraints) => _network(
        placeholder,
        _decodeWidth(
          context,
          width ?? constraints.maxWidth,
          height ?? constraints.maxHeight,
        ),
      ),
    );
  }

  /// Decode avatars and cards at the size they are drawn, not at the stored
  /// 720x1280. Uses the larger side so portrait photos stay sharp under
  /// BoxFit.cover in square or tall boxes.
  int? _decodeWidth(BuildContext context, double width, double height) {
    final side = [width, height].where((v) => v.isFinite && v > 0);
    if (side.isEmpty) return null;
    final logical = side.reduce((a, b) => a > b ? a : b);
    final pixels = (logical * MediaQuery.devicePixelRatioOf(context)).ceil();
    return pixels >= _maxDecodeWidth ? null : pixels;
  }

  Widget _network(Widget placeholder, int? decodeWidth) {
    return CachedNetworkImage(
      imageUrl: widget.imageUrl,
      memCacheWidth: decodeWidth,
      // Supabase rotates signed query tokens. The underlying object path only
      // changes when a photo is replaced, so it is the stable cache identity.
      cacheKey: _stableObjectCacheKey(widget.imageUrl),
      fit: widget.fit,
      width: widget.width,
      height: widget.height,
      maxWidthDiskCache: 720,
      maxHeightDiskCache: 1280,
      placeholder: (context, url) => placeholder,
      errorWidget: (context, url, error) {
        _reportImageError();
        return Container(
          color: AppColors.surfaceGlassHover,
          width: widget.width,
          height: widget.height,
          child: Icon(
            Icons.broken_image_outlined,
            color: AppColors.slateMist,
            size: AppDimensions.iconSizeMedium,
          ),
        );
      },
      fadeInDuration: const Duration(milliseconds: 300),
      fadeInCurve: const SpringCurve(
        spring: SilarahSpring.gentle,
        duration: Duration(milliseconds: 300),
      ),
    );
  }

  String? _stableObjectCacheKey(String value) {
    final uri = Uri.tryParse(value);
    if (uri == null || uri.path.isEmpty) return null;
    if (!uri.path.contains('/storage/v1/object/sign/')) return null;
    return uri.path;
  }
}
