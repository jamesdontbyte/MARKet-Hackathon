import 'package:flutter/material.dart';
import '../../core/config.dart';
import '../../core/theme.dart';
import '../../models/business.dart';
import '../../models/promo.dart';
import '../../services/auth_service.dart';
import '../../services/data_service.dart';
import '../../widgets/merchant_bottom_nav.dart';
import '../../widgets/status_pill.dart';
import 'account_screen.dart';
import 'analytics_screen.dart';
import 'catalog_screen.dart';
import 'promotions_screen.dart';

/// MSME Merchant Dashboard with Immersive Header
/// Matches Stitch frame: market_tab_1_dashboard_immersive_scroll_header
class MerchantDashboardScreen extends StatefulWidget {
  final Business? business;

  const MerchantDashboardScreen({
    super.key,
    this.business,
  });

  @override
  State<MerchantDashboardScreen> createState() => _MerchantDashboardScreenState();
}

class _MerchantDashboardScreenState extends State<MerchantDashboardScreen> {
  final AuthService _authService = AuthService();
  final DataService _dataService = DataService();

  Business? _business;
  List<Promo> _promos = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _business = widget.business;
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      if (_business == null) {
        final uid = _authService.currentUserId;
        if (uid != null) {
          _business = await _dataService.fetchMerchantBusiness(uid);
        }
      }

      // If still null, fallback to demo shop Kape Tahanan
      _business ??= await _dataService.fetchBusinessById(demoShopId);

      if (_business != null) {
        _promos = await _dataService.fetchPromosForBusiness(_business!.id);
      }
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception:', '').trim();
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _onBottomNavTapped(int index) {
    if (index == 0) return; // Already on dashboard
    if (index == 1) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => MerchantCatalogScreen(business: _business),
        ),
      );
    } else if (index == 2) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => MerchantAnalyticsScreen(business: _business),
        ),
      );
    } else if (index == 3) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => MerchantAccountScreen(business: _business),
        ),
      );
    }
  }


  @override
  Widget build(BuildContext context) {
    final biz = _business;
    final coverImage = biz?.coverUrl ??
        'https://images.unsplash.com/photo-1554118811-1e0d58224f24?auto=format&fit=crop&w=800&q=80';
    final categoryText = categoryLabels[biz?.category] ?? biz?.category ?? 'Café & Pastries';

    return Scaffold(
      backgroundColor: MarketColors.surface,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null && biz == null
              ? _buildErrorView()
              : RefreshIndicator(
                  onRefresh: _loadDashboardData,
                  child: CustomScrollView(
                    slivers: [
                      // Immersive Collapsible Hero Header
                      SliverAppBar(
                        expandedHeight: 240,
                        pinned: true,
                        backgroundColor: MarketColors.surface,
                        elevation: 0,
                        flexibleSpace: FlexibleSpaceBar(
                          background: Stack(
                            fit: StackFit.expand,
                            children: [
                              Image.network(
                                coverImage,
                                fit: BoxFit.cover,
                                errorBuilder: (ctx, err, stack) => Container(
                                  color: MarketColors.surfaceContainerHigh,
                                  child: const Center(
                                    child: Icon(Icons.storefront_rounded,
                                        size: 48, color: MarketColors.primary),
                                  ),
                                ),
                              ),
                              // Dark bottom gradient overlay
                              Container(
                                decoration: const BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [
                                      Colors.transparent,
                                      Color(0x60000000),
                                      Color(0xD00F172A),
                                    ],
                                    stops: [0.3, 0.65, 1.0],
                                  ),
                                ),
                              ),
                              // Store identity text
                              Positioned(
                                left: MarketSpacing.screenMargin,
                                right: MarketSpacing.screenMargin,
                                bottom: 16,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        StatusPill.verifiedMsme(),
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 8, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: Colors.black45,
                                            borderRadius: BorderRadius.circular(10),
                                            border: Border.all(color: Colors.white24),
                                          ),
                                          child: Text(
                                            categoryText,
                                            style: const TextStyle(
                                              fontSize: 11,
                                              color: Colors.white,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      biz?.name ?? 'Kape Tahanan',
                                      style: const TextStyle(
                                        fontSize: 24,
                                        fontWeight: FontWeight.w800,
                                        color: Colors.white,
                                        letterSpacing: -0.5,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      biz?.address ?? 'San Jose de Buenavista, Antique',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.white.withValues(alpha: 0.85),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      // Main Dashboard Body
                      SliverPadding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: MarketSpacing.screenMargin,
                          vertical: 16,
                        ),
                        sliver: SliverList(
                          delegate: SliverChildListDelegate([
                            // Performance Overview Section
                            _buildPerformanceCard(),
                            const SizedBox(height: 20),

                            // Active Promos Section
                            _buildActivePromosSection(),
                            const SizedBox(height: 20),

                            // About Our Business Section
                            _buildAboutBusinessSection(biz),
                            const SizedBox(height: 40),
                          ]),
                        ),
                      ),
                    ],
                  ),
                ),
      bottomNavigationBar: MerchantBottomNav(
        currentIndex: 0,
        onTap: _onBottomNavTapped,
      ),
    );
  }

  Widget _buildPerformanceCard() {
    final claimsCount = _promos.fold<int>(0, (sum, p) => sum + p.redeemedCount);
    final displayClaims = claimsCount > 0 ? claimsCount.toString() : '142';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: MarketColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: MarketColors.outlineVariant.withValues(alpha: 0.3),
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x080F172A),
            offset: Offset(0, 4),
            blurRadius: 16,
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text(
                    'PERFORMANCE OVERVIEW',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                      color: MarketColors.outline,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'This Week',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: MarketColors.onSurface,
                    ),
                  ),
                ],
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: MarketColors.primaryContainer,
                  foregroundColor: MarketColors.onSurface,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text(
                  'Create Promo',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                ),
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => MerchantPromotionsScreen(business: _business),
                    ),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 16),

          // 2 Stats Row
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: MarketColors.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Expanded(
                            child: Text(
                              'Store Views',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: MarketColors.onSurfaceVariant,
                              ),
                            ),
                          ),
                          const Icon(Icons.visibility_outlined,
                              size: 16, color: MarketColors.outline),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          const Text(
                            '412',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: MarketColors.onSurface,
                            ),
                          ),
                          const SizedBox(width: 6),
                          _buildSampleBadge(),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: const [
                          Icon(Icons.trending_up_rounded,
                              size: 14, color: Color(0xFF16A34A)),
                          SizedBox(width: 4),
                          Text(
                            '+18% vs last week',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF16A34A),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: MarketColors.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Expanded(
                            child: Text(
                              'Promo Claims',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: MarketColors.onSurfaceVariant,
                              ),
                            ),
                          ),
                          const Icon(Icons.confirmation_number_outlined,
                              size: 16, color: MarketColors.outline),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(
                            displayClaims,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: MarketColors.onSurface,
                            ),
                          ),
                          if (claimsCount <= 0) ...[
                            const SizedBox(width: 6),
                            _buildSampleBadge(),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: const [
                          Icon(Icons.trending_up_rounded,
                              size: 14, color: Color(0xFF16A34A)),
                          SizedBox(width: 4),
                          Text(
                            '+34% claims rate',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF16A34A),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSampleBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF3C7),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: const Color(0xFFF59E0B)),
      ),
      child: const Text(
        'Sample data',
        style: TextStyle(
          fontSize: 8,
          fontWeight: FontWeight.w700,
          color: Color(0xFF92400E),
        ),
      ),
    );
  }

  Widget _buildActivePromosSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: const [
                Icon(Icons.campaign_rounded,
                    color: MarketColors.primary, size: 22),
                SizedBox(width: 8),
                Text(
                  'Active Promos',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: MarketColors.onSurface,
                  ),
                ),
              ],
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => MerchantPromotionsScreen(business: _business),
                  ),
                );
              },
              child: const Text(
                'Manage',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: MarketColors.primary,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),

        if (_promos.isEmpty) ...[
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: MarketColors.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: MarketColors.outlineVariant.withValues(alpha: 0.3),
              ),
            ),
            child: Column(
              children: [
                const Icon(Icons.local_offer_outlined,
                    size: 36, color: MarketColors.outline),
                const SizedBox(height: 8),
                const Text(
                  'No promotions created yet',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: MarketColors.onSurface,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Launch your first flash deal to reach shoppers entering San Jose.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    color: MarketColors.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 12),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: MarketColors.primaryContainer,
                    foregroundColor: MarketColors.onSurface,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => MerchantPromotionsScreen(business: _business),
                      ),
                    );
                  },
                  child: const Text('Create First Promo'),
                ),
              ],
            ),
          ),
        ] else ...[
          ..._promos.take(2).map((promo) {
            final valueLabel = promo.valueLabel ??
                (promo.promoType == 'bogo' ? 'BOGO' : 'Special Deal');

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF0F9FF),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xFFBAE6FD)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: MarketColors.primaryContainer,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          valueLabel,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: MarketColors.onSurface,
                          ),
                        ),
                      ),
                      Row(
                        children: const [
                          Icon(Icons.schedule_rounded,
                              size: 14, color: Color(0xFF0284C7)),
                          SizedBox(width: 4),
                          Text(
                            'Active Promo',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF0284C7),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    promo.title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: MarketColors.onSurface,
                    ),
                  ),
                  if (promo.description != null && promo.description!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      promo.description!,
                      style: const TextStyle(
                        fontSize: 12,
                        color: MarketColors.onSurfaceVariant,
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  const Divider(height: 1, color: Color(0xFFBAE6FD)),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${promo.redeemedCount} claimed by locals',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: MarketColors.onSurfaceVariant,
                        ),
                      ),
                      GestureDetector(
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => MerchantPromotionsScreen(business: _business),
                            ),
                          );
                        },
                        child: Row(
                          children: const [
                            Text(
                              'Details',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF0284C7),
                              ),
                            ),
                            Icon(Icons.arrow_forward_rounded,
                                size: 14, color: Color(0xFF0284C7)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          }),
        ],
      ],
    );
  }

  Widget _buildAboutBusinessSection(Business? biz) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: MarketColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: MarketColors.outlineVariant.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'About Our Business',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: MarketColors.onSurface,
                ),
              ),
              TextButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => MerchantAccountScreen(business: biz),
                    ),
                  );
                },
                child: const Text('Edit Info', style: TextStyle(fontSize: 12)),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Operating Hours
          Row(
            children: [
              const Icon(Icons.schedule_rounded, size: 18, color: MarketColors.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  biz?.hours ?? 'Mon – Sun: 7:00 AM – 9:00 PM',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: MarketColors.onSurface,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Feature chips
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: const [
              _FeatureBadge(label: 'Locally Sourced', icon: Icons.eco_outlined),
              _FeatureBadge(label: 'Pet Friendly', icon: Icons.pets_outlined),
              _FeatureBadge(label: 'Fast Wi-Fi', icon: Icons.wifi_rounded),
            ],
          ),
          const SizedBox(height: 14),

          // Bio
          Text(
            biz?.bio ??
                'Hand-roasted heirloom Philippine coffee blends, slow drip brews, and homemade native pastries served in an open garden setting.',
            style: const TextStyle(
              fontSize: 13,
              color: MarketColors.onSurfaceVariant,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded,
                size: 48, color: MarketColors.error),
            const SizedBox(height: 12),
            Text(
              _errorMessage ?? 'Failed to load merchant data',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, color: MarketColors.onSurface),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadDashboardData,
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

class _FeatureBadge extends StatelessWidget {
  final String label;
  final IconData icon;

  const _FeatureBadge({required this.label, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: MarketColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: MarketColors.outlineVariant.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: MarketColors.outline),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: MarketColors.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
