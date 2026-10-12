import 'package:flutter/material.dart';
import '../core/theme.dart';

/// PromoPhotoView renders a promo photo with the required fallback chain:
/// 1. promoImageUrl
/// 2. businessCoverUrl
/// 3. assets/categories/{category}.png
/// Includes loading placeholder and error placeholder, and respects constraints.
class PromoPhotoView extends StatelessWidget {
  final String? promoImageUrl;
  final String? businessCoverUrl;
  final String? category;
  final double? width;
  final double? height;
  final BoxFit fit;
  final BorderRadius? borderRadius;

  const PromoPhotoView({
    super.key,
    this.promoImageUrl,
    this.businessCoverUrl,
    this.category,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    final catSlug = (category != null && category!.isNotEmpty) ? category! : 'retail';
    final placeholderAsset = 'assets/categories/$catSlug.png';

    Widget content;

    if (promoImageUrl != null && promoImageUrl!.trim().isNotEmpty) {
      content = Image.network(
        promoImageUrl!.trim(),
        fit: fit,
        width: width,
        height: height,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return _buildLoadingPlaceholder();
        },
        errorBuilder: (context, error, stackTrace) {
          return _buildCoverOrCategoryFallback(placeholderAsset);
        },
      );
    } else {
      content = _buildCoverOrCategoryFallback(placeholderAsset);
    }

    if (borderRadius != null) {
      content = ClipRRect(
        borderRadius: borderRadius!,
        child: content,
      );
    }

    return content;
  }

  Widget _buildCoverOrCategoryFallback(String placeholderAsset) {
    if (businessCoverUrl != null && businessCoverUrl!.trim().isNotEmpty) {
      return Image.network(
        businessCoverUrl!.trim(),
        fit: fit,
        width: width,
        height: height,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return _buildLoadingPlaceholder();
        },
        errorBuilder: (context, error, stackTrace) {
          return Image.asset(
            placeholderAsset,
            fit: fit,
            width: width,
            height: height,
          );
        },
      );
    }
    return Image.asset(
      placeholderAsset,
      fit: fit,
      width: width,
      height: height,
    );
  }

  Widget _buildLoadingPlaceholder() {
    return Container(
      width: width,
      height: height,
      color: MarketColors.surfaceContainerLow,
      child: const Center(
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(MarketColors.primary),
          ),
        ),
      ),
    );
  }
}
