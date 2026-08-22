import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../core/constants/app_colors.dart';
import '../core/constants/api_endpoints.dart';

class AppNetworkImage extends StatelessWidget {
  final String imageUrl;
  final BoxFit fit;
  final double? width;
  final double? height;
  final Widget? placeholder;
  final Widget? errorWidget;
  final BorderRadius? borderRadius;
  final int? memCacheWidth;

  const AppNetworkImage({
    super.key,
    required this.imageUrl,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
    this.placeholder,
    this.errorWidget,
    this.borderRadius,
    this.memCacheWidth,
  });

  @override
  Widget build(BuildContext context) {
    final cleanUrl = imageUrl.trim();
    if (cleanUrl.isEmpty || cleanUrl == 'null') {
      return _buildFallback();
    }

    Widget image = CachedNetworkImage(
      imageUrl: cleanUrl,
      httpHeaders: ApiEndpoints.imageHeaders,
      fit: fit,
      width: width,
      height: height,
      memCacheWidth: memCacheWidth,
      placeholder: (context, url) =>
          placeholder ??
          Container(
            width: width,
            height: height,
            color: AppColors.surface,
            child: const Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.primary,
                ),
              ),
            ),
          ),
      errorWidget: (context, url, error) {
        // Auto-evict corrupted cache entry
        try {
          CachedNetworkImage.evictFromCache(url);
        } catch (_) {}

        // Fallback to Image.network directly with proper headers
        return Image.network(
          url,
          headers: ApiEndpoints.imageHeaders,
          fit: fit,
          width: width,
          height: height,
          errorBuilder: (context, err, stack) => errorWidget ?? _buildFallback(),
        );
      },
    );

    if (borderRadius != null) {
      return ClipRRect(
        borderRadius: borderRadius!,
        child: image,
      );
    }

    return image;
  }

  Widget _buildFallback() {
    return errorWidget ??
        Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: borderRadius,
          ),
          child: Center(
            child: Icon(
              Icons.menu_book_rounded,
              color: AppColors.textMuted.withValues(alpha: 0.6),
              size: (width != null && width! < 60) ? 20 : 28,
            ),
          ),
        );
  }
}
