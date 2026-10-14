import 'package:flutter/material.dart';
import '../../core/config.dart';
import '../../core/theme.dart';
import '../../models/business.dart';
import '../../models/product.dart';
import '../../models/promo.dart';
import '../../services/data_service.dart';
import '../../widgets/app_buttons.dart';
import '../../widgets/app_header.dart';
import 'promo_detail_screen.dart';

/// StorefrontScreen presents the MSME merchant's public profile,
/// active promotions, and catalog products.
class StorefrontScreen extends StatefulWidget {
  final Business business;
  final DataService? dataService;

  const StorefrontScreen({
    super.key,
    required this.business,
    this.dataService,
  });

  @override
  State<StorefrontScreen> createState() => _StorefrontScreenState();
}

class _StorefrontScreenState extends State<StorefrontScreen> {
  late final DataService _dataService = widget.dataService ?? DataService();

  List<Promo> _promos = [];
  List<Product> _products = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadStorefrontData();
  }

  Future<void> _loadStorefrontData() async {
    try {
      final results = await Future.wait([
        _dataService.fetchPromosForBusiness(widget.business.id),
        _dataService.fetchProducts(widget.business.id),
      ]);

      if (mounted) {
        setState(() {
          _promos = results[0] as List<Promo>;
          _products = results[1] as List<Product>;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceAll('Exception:', '').trim();
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final categoryLabel = categoryLabels[widget.business.category] ?? widget.business.category;

    return Scaffold(
      backgroundColor: MarketColors.surface,
      appBar: AppHeader(
        showBack: true,
        subtitle: widget.business.name,
      ),
      body: CustomScrollView(
        slivers: [
          // Storefront Exterior Showcase Card
          SliverToBoxAdapter(
            child: Container(
              height: 180,
              margin: const EdgeInsets.fromLTRB(
                MarketSpacing.screenMargin,
                12,
                MarketSpacing.screenMargin,
                0,
              ),
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                boxShadow: MarketElevation.level1,
              ),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  widget.business.coverUrl != null && widget.business.coverUrl!.isNotEmpty
                      ? Image.network(
                          widget.business.coverUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => _buildCategoryFallbackImage(),
                        )
                      : _buildCategoryFallbackImage(),
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.transparent, Color(0x99000000)],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Business Details Content
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(MarketSpacing.screenMargin),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title, Logo Avatar & Verification Pill
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: MarketColors.surfaceContainerLowest,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: MarketColors.outlineVariant.withValues(alpha: 0.3),
                          ),
                          boxShadow: MarketElevation.level1,
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: widget.business.logoUrl != null && widget.business.logoUrl!.isNotEmpty
                            ? Image.network(
                                widget.business.logoUrl!,
                                fit: BoxFit.cover,
                                errorBuilder: (_, _, _) => _buildCategoryAvatar(widget.business.category),
                              )
                            : _buildCategoryAvatar(widget.business.category),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.business.name,
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                color: MarketColors.onSurface,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              categoryLabel,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: MarketColors.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (widget.business.verified)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFDCFCE7),
                            borderRadius: BorderRadius.circular(MarketRadii.pill),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.verified_rounded, size: 14, color: Color(0xFF15803D)),
                              SizedBox(width: 4),
                              Text(
                                'Verified MSME',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF15803D),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Open / Closed Pill from real hours
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: MarketColors.surfaceContainerLow,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: MarketColors.outlineVariant.withValues(alpha: 0.4),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 7,
                              height: 7,
                              decoration: BoxDecoration(
                                color: widget.business.isOpenNow
                                    ? const Color(0xFF10B981)
                                    : Colors.amber,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              widget.business.openStatusText,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: MarketColors.onSurface,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Subtitle & Bio
                  if (widget.business.bio != null && widget.business.bio!.isNotEmpty)
                    Text(
                      widget.business.bio!,
                      style: const TextStyle(
                        fontSize: 14,
                        color: MarketColors.onSurfaceVariant,
                        height: 1.45,
                      ),
                    ),
                  const SizedBox(height: 14),

                  // Metadata Badges (Rating, Hours, Address)
                  Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.star_rounded, size: 18, color: Color(0xFFF59E0B)),
                          const SizedBox(width: 4),
                          Text(
                            widget.business.rating.toStringAsFixed(1),
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: MarketColors.onSurface,
                            ),
                          ),
                        ],
                      ),
                      ConstrainedBox(
                        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width - 32),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.schedule_rounded, size: 16, color: MarketColors.outline),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                widget.business.hours ?? 'Hours not specified',
                                style: const TextStyle(fontSize: 13, color: MarketColors.secondary),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                      ConstrainedBox(
                        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width - 32),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.location_on_outlined, size: 16, color: MarketColors.outline),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                widget.business.address ?? 'San Jose, Antique',
                                style: const TextStyle(fontSize: 13, color: MarketColors.secondary),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (_errorMessage != null) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: MarketColors.errorContainer.withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: MarketColors.error.withValues(alpha: 0.3)),
                      ),
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(fontSize: 12, color: MarketColors.error),
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),

                  // Section: Active Promos
                  const Text(
                    'Active Promotions',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: MarketColors.onSurface,
                    ),
                  ),
                  const SizedBox(height: 10),

                  if (_isLoading)
                    const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator()))
                  else if (_promos.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: MarketColors.surfaceContainerLowest,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: MarketColors.cardBorder),
                      ),
                      child: const Center(
                        child: Text(
                          'No active promotions at this time.',
                          style: TextStyle(fontSize: 13, color: MarketColors.outline),
                        ),
                      ),
                    )
                  else
                    Column(
                      children: _promos.map((p) => _buildPromoCard(p)).toList(),
                    ),
                  const SizedBox(height: 24),

                  // Section: Products Menu
                  const Text(
                    'Menu & Offerings',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: MarketColors.onSurface,
                    ),
                  ),
                  const SizedBox(height: 10),

                  if (_isLoading)
                    const SizedBox.shrink()
                  else if (_products.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: MarketColors.surfaceContainerLowest,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: MarketColors.cardBorder),
                      ),
                      child: const Center(
                        child: Text(
                          'Catalog items coming soon.',
                          style: TextStyle(fontSize: 13, color: MarketColors.outline),
                        ),
                      ),
                    )
                  else
                    Column(
                      children: _products.map((prod) => _buildProductCard(prod)).toList(),
                    ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryFallbackImage() {
    return Image.asset(
      'assets/categories/${widget.business.category}.png',
      fit: BoxFit.cover,
      errorBuilder: (_, _, _) => Container(
        color: MarketColors.surfaceContainerHigh,
        child: const Center(
          child: Icon(Icons.storefront_rounded, size: 54, color: MarketColors.primary),
        ),
      ),
    );
  }

  Widget _buildCategoryAvatar(String category) {
    return Padding(
      padding: const EdgeInsets.all(6),
      child: Image.asset(
        'assets/categories/$category.png',
        fit: BoxFit.contain,
        errorBuilder: (_, _, _) => const Icon(
          Icons.storefront_rounded,
          color: MarketColors.primary,
        ),
      ),
    );
  }

  Widget _buildPromoCard(Promo p) {
    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => PromoDetailScreen(
              promo: p,
              fromNotification: false,
            ),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFF0F9FF),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFBAE6FD)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: MarketColors.primaryContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                p.valueLabel ?? p.promoType.toUpperCase(),
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: MarketColors.onPrimaryContainer,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    p.title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: MarketColors.onSurface,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    p.description ?? '',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12, color: MarketColors.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: MarketColors.primary),
          ],
        ),
      ),
    );
  }

  Widget _buildProductCard(Product prod) {
    return GestureDetector(
      key: Key('storefront_product_${prod.id}'),
      onTap: () => _showProductPreview(prod),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: MarketColors.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: MarketColors.cardBorder),
          boxShadow: MarketElevation.level1,
        ),
        child: Row(
          children: [
            if (prod.imageUrl != null && prod.imageUrl!.isNotEmpty) ...[
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.network(
                      prod.imageUrl!,
                      width: 56,
                      height: 56,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => Container(
                        width: 56,
                        height: 56,
                        color: MarketColors.surfaceContainerHigh,
                        child: const Icon(Icons.storefront_rounded, size: 24, color: MarketColors.outline),
                      ),
                    ),
                  ),
                  if (prod.imageSource == 'stock')
                    Positioned(
                      bottom: 2,
                      left: 2,
                      right: 2,
                      child: Container(
                        key: Key('stock_photo_badge_${prod.id}'),
                        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 1),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.7),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'Stock photo',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 8,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    prod.name,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: MarketColors.onSurface,
                    ),
                  ),
                  if (prod.description != null && prod.description!.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      prod.description!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12, color: MarketColors.secondary),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 12),
            Text(
              '₱${prod.price.toStringAsFixed(0)}',
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: MarketColors.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showProductPreview(Product prod) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(ctx).size.height * 0.85,
          ),
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          decoration: const BoxDecoration(
            color: MarketColors.surfaceContainerLowest,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const SizedBox(width: 36),
                    Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: MarketColors.outlineVariant,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 20, color: MarketColors.secondary),
                      onPressed: () => Navigator.of(ctx).pop(),
                      tooltip: 'Close',
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (prod.imageUrl != null && prod.imageUrl!.isNotEmpty) ...[
                  Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: AspectRatio(
                          aspectRatio: 16 / 9,
                          child: Image.network(
                            prod.imageUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => Container(
                              color: MarketColors.surfaceContainerHigh,
                              child: const Center(
                                child: Icon(Icons.broken_image_rounded, size: 36, color: MarketColors.outline),
                              ),
                            ),
                          ),
                        ),
                      ),
                      if (prod.imageSource == 'stock')
                        Positioned(
                          top: 10,
                          left: 10,
                          child: Container(
                            key: const Key('preview_stock_photo_badge'),
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.7),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              'Stock photo',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  if (prod.imageSource == 'stock' && prod.imageCredit != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      'Photo by ${prod.imageCredit} on Pixabay',
                      key: const Key('preview_photo_credit'),
                      style: const TextStyle(
                        fontSize: 11,
                        color: MarketColors.secondary,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                ],
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        prod.name,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: MarketColors.onSurface,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      '₱${prod.price.toStringAsFixed(0)}',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: MarketColors.primary,
                      ),
                    ),
                  ],
                ),
                if (prod.category != null && prod.category!.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: MarketColors.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      prod.category!,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: MarketColors.secondary,
                      ),
                    ),
                  ),
                ],
                if (prod.description != null && prod.description!.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    prod.description!,
                    style: const TextStyle(
                      fontSize: 13,
                      height: 1.4,
                      color: MarketColors.onSurfaceVariant,
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                SecondaryButton(
                  width: double.infinity,
                  label: 'Close',
                  onPressed: () => Navigator.of(ctx).pop(),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

