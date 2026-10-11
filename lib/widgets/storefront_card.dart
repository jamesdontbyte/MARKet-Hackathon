import 'package:flutter/material.dart';
import '../core/config.dart';
import '../core/theme.dart';
import 'app_card.dart';
import 'promo_badge.dart';
import 'status_pill.dart';

/// StorefrontCard presents MSME businesses with a 16:9 cover preview,
/// verified badge, category fallback image, distance label, and active promos.
/// Ensures minimum 48x48dp interactive target and pressed feedback.
class StorefrontCard extends StatelessWidget {
  final String id;
  final String name;
  final String category;
  final String? coverUrl;
  final bool isVerified;
  final bool isOpen;
  final double? distanceMeters;
  final String? activePromoTitle;
  final VoidCallback? onTap;

  const StorefrontCard({
    super.key,
    required this.id,
    required this.name,
    required this.category,
    this.coverUrl,
    this.isVerified = true,
    this.isOpen = true,
    this.distanceMeters,
    this.activePromoTitle,
    this.onTap,
  });

  Widget _buildCoverImage() {
    final placeholderAsset = 'assets/categories/$category.png';

    Widget imageWidget;
    if (coverUrl != null && coverUrl!.isNotEmpty) {
      imageWidget = Image.network(
        coverUrl!,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return Image.asset(
            placeholderAsset,
            fit: BoxFit.cover,
            errorBuilder: (ctx, err, st) {
              return Container(
                color: MarketColors.surfaceContainer,
                child: const Center(
                  child: Icon(Icons.storefront, size: 40, color: MarketColors.outline),
                ),
              );
            },
          );
        },
      );
    } else {
      imageWidget = Image.asset(
        placeholderAsset,
        fit: BoxFit.cover,
        errorBuilder: (ctx, err, st) {
          return Container(
            color: MarketColors.surfaceContainer,
            child: const Center(
              child: Icon(Icons.storefront, size: 40, color: MarketColors.outline),
            ),
          );
        },
      );
    }

    return AspectRatio(
      aspectRatio: 16 / 9,
      child: Stack(
        fit: StackFit.expand,
        children: [
          imageWidget,
          // Bottom gradient overlay for contrast
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: 60,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.65),
                  ],
                ),
              ),
            ),
          ),
          // Top badges: Verified MSME + Open Status
          Positioned(
            top: 10,
            left: 10,
            right: 10,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (isVerified)
                  StatusPill.verifiedMsme(isSmall: true)
                else
                  const SizedBox.shrink(),
                StatusPill.openStatus(isOpen: isOpen, isSmall: true),
              ],
            ),
          ),
          // Bottom info overlay: distance
          if (distanceMeters != null)
            Positioned(
              left: 12,
              bottom: 8,
              child: Row(
                children: [
                  const Icon(
                    Icons.place_rounded,
                    size: 14,
                    color: Colors.white,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    distanceMeters! >= 1000
                        ? '${(distanceMeters! / 1000).toStringAsFixed(1)} km away'
                        : '${distanceMeters!.toStringAsFixed(0)} m away',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final catLabel = categoryLabels[category] ?? category;

    return AppCard(
      padding: EdgeInsets.zero,
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildCoverImage(),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: MarketColors.onSurface,
                        ),
                      ),
                    ),
                    Text(
                      catLabel,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: MarketColors.outline,
                      ),
                    ),
                  ],
                ),
                if (activePromoTitle != null) ...[
                  const SizedBox(height: 8),
                  PromoBadge(
                    label: activePromoTitle!,
                    isSmall: true,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
