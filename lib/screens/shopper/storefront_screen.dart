import 'package:flutter/material.dart';
import '../../core/config.dart';
import '../../core/theme.dart';
import '../../models/business.dart';
import '../../models/product.dart';
import '../../models/promo.dart';
import '../../services/data_service.dart';
import 'promo_detail_screen.dart';

/// StorefrontScreen presents the MSME merchant's public profile,
/// active promotions, and catalog products.
class StorefrontScreen extends StatefulWidget {
  final Business business;

  const StorefrontScreen({
    super.key,
    required this.business,
  });

  @override
  State<StorefrontScreen> createState() => _StorefrontScreenState();
}

class _StorefrontScreenState extends State<StorefrontScreen> {
  final DataService _dataService = DataService();

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
      body: CustomScrollView(
        slivers: [
          // Collapsible Image Header
          SliverAppBar(
            expandedHeight: 200,
            pinned: true,
            backgroundColor: MarketColors.surface,
            leading: IconButton(
              icon: Container(
                padding: const EdgeInsets.all(6),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.arrow_back_rounded, color: MarketColors.onSurface, size: 20),
              ),
              onPressed: () => Navigator.of(context).pop(),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
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
                  // Title & Verification Pill
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.business.name,
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w800,
                                color: MarketColors.onSurface,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              categoryLabel,
                              style: const TextStyle(
                                fontSize: 14,
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
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.schedule_rounded, size: 16, color: MarketColors.outline),
                          const SizedBox(width: 4),
                          Text(
                            widget.business.hours ?? 'Hours not specified',
                            style: const TextStyle(fontSize: 13, color: MarketColors.secondary),
                          ),
                        ],
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.location_on_outlined, size: 16, color: MarketColors.outline),
                          const SizedBox(width: 4),
                          Text(
                            widget.business.address ?? 'San Jose, Antique',
                            style: const TextStyle(fontSize: 13, color: MarketColors.secondary),
                          ),
                        ],
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
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: MarketColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: MarketColors.cardBorder),
        boxShadow: MarketElevation.level1,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
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
    );
  }
}
