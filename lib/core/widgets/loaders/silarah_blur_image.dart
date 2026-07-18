// lib/core/widgets/loaders/silarah_blur_image.dart
// ============================================================
// SILARAH — Reusable BlurHash Network Image
// progressive loading: renders blurred placeholder → crossfades to network image
// ============================================================

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
  Uint8List? _placeholderBytes;
  bool _reportedImageError = false;

  @override
  void initState() {
    super.initState();
    _decodePlaceholder();
  }

  @override
  void didUpdateWidget(SilarahBlurImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageUrl != widget.imageUrl) {
      _reportedImageError = false;
    }
    if (oldWidget.blurhash != widget.blurhash) {
      _decodePlaceholder();
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
      final bytes = await Future.microtask(() {
        final blurHash = BlurHash.decode(widget.blurhash!);
        // Using small resolution for faster decoding and memory efficiency
        final image = blurHash.toImage(32, 32);
        return Uint8List.fromList(img.encodeJpg(image));
      });

      if (mounted) {
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

    return CachedNetworkImage(
      imageUrl: widget.imageUrl,
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
          child: const Icon(
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
