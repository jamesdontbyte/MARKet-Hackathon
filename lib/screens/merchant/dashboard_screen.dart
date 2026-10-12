import 'package:flutter/material.dart';
import '../../core/config.dart';
import '../../core/theme.dart';
import '../../models/business.dart';
import '../../models/merchant_analytics.dart';
import '../../models/promo.dart';
import '../../services/auth_service.dart';
import '../../services/data_service.dart';
import '../../widgets/app_bottom_nav.dart';
import '../../widgets/app_header.dart';
import '../../widgets/country_selector.dart';
import '../../widgets/promo_photo_view.dart';
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
  MerchantAnalyticsData? _funnelData;
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

      if (_business != null) {
        _promos = await _dataService.fetchPromosForBusiness(_business!.id);
        _funnelData = await _dataService.fetchMerchantFunnel(_business!.id);
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

  Future<void> _openEditBusinessModal(Business? biz) async {
    if (biz == null) return;

    final nameCtrl = TextEditingController(text: biz.name);
    final bioCtrl = TextEditingController(text: biz.bio ?? '');
    final addressCtrl = TextEditingController(text: biz.address ?? '');
    final phoneCtrl = TextEditingController(text: biz.phone ?? '');
    final hoursCtrl = TextEditingController(text: biz.hours ?? '');
    String selectedCategory = biz.category;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (modalCtx, setModalState) {
            return Container(
              height: MediaQuery.of(modalCtx).size.height * 0.85,
              decoration: const BoxDecoration(
                color: MarketColors.surface,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              padding: EdgeInsets.only(
                left: MarketSpacing.screenMargin,
                right: MarketSpacing.screenMargin,
                top: 16,
                bottom: MediaQuery.of(modalCtx).viewInsets.bottom + 16,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: MarketColors.outlineVariant.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Edit Business Details',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: MarketColors.onSurface,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () => Navigator.of(modalCtx).pop(),
                      ),
                    ],
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 12),
                          const Text(
                            'Business Name',
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 6),
                          TextFormField(
                            controller: nameCtrl,
                            decoration: const InputDecoration(
                              filled: true,
                              fillColor: MarketColors.surfaceContainerLowest,
                              contentPadding: EdgeInsets.all(12),
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'Category',
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: canonicalCategories.map((slug) {
                              final isSelected = selectedCategory == slug;
                              return ChoiceChip(
                                label: Text(categoryLabels[slug] ?? slug),
                                selected: isSelected,
                                onSelected: (sel) {
                                  if (sel) {
                                    setModalState(() {
                                      selectedCategory = slug;
                                    });
                                  }
                                },
                              );
                            }).toList(),
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'Shop Bio',
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 6),
                          TextFormField(
                            controller: bioCtrl,
                            maxLines: 3,
                            maxLength: 250,
                            decoration: const InputDecoration(
                              filled: true,
                              fillColor: MarketColors.surfaceContainerLowest,
                              contentPadding: EdgeInsets.all(12),
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'Street Address & Barangay',
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 6),
                          TextFormField(
                            controller: addressCtrl,
                            decoration: const InputDecoration(
                              filled: true,
                              fillColor: MarketColors.surfaceContainerLowest,
                              contentPadding: EdgeInsets.all(12),
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'Hotline / Mobile',
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 6),
                          TextFormField(
                            controller: phoneCtrl,
                            decoration: const InputDecoration(
                              filled: true,
                              fillColor: MarketColors.surfaceContainerLowest,
                              contentPadding: EdgeInsets.all(12),
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'Operating Hours',
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 6),
                          TextFormField(
                            controller: hoursCtrl,
                            decoration: const InputDecoration(
                              filled: true,
                              fillColor: MarketColors.surfaceContainerLowest,
                              contentPadding: EdgeInsets.all(12),
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 20),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: MarketColors.primaryContainer,
                        foregroundColor: MarketColors.onSurface,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () async {
                        final updated = biz.copyWith(
                          name: nameCtrl.text.trim(),
                          category: selectedCategory,
                          bio: bioCtrl.text.trim(),
                          address: addressCtrl.text.trim(),
                          phone: phoneCtrl.text.trim(),
                          hours: hoursCtrl.text.trim(),
                        );
                        try {
                          await _dataService.updateBusiness(updated);
                          if (mounted) {
                            setState(() {
                              _business = updated;
                            });
                          }
                          if (modalCtx.mounted) {
                            Navigator.of(modalCtx).pop();
                          }
                        } catch (e) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Failed to update: $e')),
                            );
                          }
                        }
                      },
                      child: const Text('Save Changes', style: TextStyle(fontWeight: FontWeight.w700)),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final biz = _business;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {},
      child: Scaffold(
        backgroundColor: MarketColors.surface,
        appBar: const AppHeader(
          showBack: false,
          subtitle: 'Dashboard',
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _errorMessage != null && biz == null
                ? _buildErrorView()
                : RefreshIndicator(
                    onRefresh: _loadDashboardData,
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(
                        MarketSpacing.screenMargin,
                        16,
                        MarketSpacing.screenMargin,
                        88,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildStoreIdentityCard(biz),
                          _buildPerformanceCard(),
                          const SizedBox(height: 20),
                          _buildActivePromosSection(),
                          const SizedBox(height: 20),
                          _buildAboutBusinessSection(biz),
                        ],
                      ),
                    ),
                  ),
        bottomNavigationBar: AppBottomNav(
          currentIndex: 0,
          role: AppNavRole.merchant,
          onTap: _onBottomNavTapped,
        ),
      ),
    );
  }

  Widget _buildStoreIdentityCard(Business? biz) {
    final categoryText = categoryLabels[biz?.category] ?? biz?.category ?? 'Retail & Shopping';
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      height: 130,
      decoration: BoxDecoration(
        color: MarketColors.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(16),
        boxShadow: MarketElevation.level1,
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (biz?.coverUrl != null && biz!.coverUrl!.isNotEmpty)
            Image.network(
              biz.coverUrl!,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => _buildCategoryHeroFallback(biz.category),
            )
          else
            _buildCategoryHeroFallback(biz?.category),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  Color(0x70000000),
                  Color(0xD00F172A),
                ],
                stops: [0.1, 0.5, 1.0],
              ),
            ),
          ),
          Positioned(
            left: 14,
            right: 14,
            bottom: 12,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: MarketColors.surfaceContainerLowest,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white, width: 2),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black26,
                        blurRadius: 6,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: biz?.logoUrl != null && biz!.logoUrl!.isNotEmpty
                      ? Image.network(
                          biz.logoUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => _buildCategoryAvatar(biz.category),
                        )
                      : _buildCategoryAvatar(biz?.category),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        biz?.name ?? 'My Business',
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: -0.3,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 6,
                        runSpacing: 2,
                        children: [
                          Text(
                            categoryText,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.white.withValues(alpha: 0.9),
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (biz?.verified == true)
                            StatusPill.verifiedMsme(isSmall: true),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                InkWell(
                  onTap: () => _openEditBusinessModal(biz),
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
                    ),
                    alignment: Alignment.center,
                    child: const Icon(Icons.edit_rounded, color: Colors.white, size: 18),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryHeroFallback(String? category) {
    final catSlug = category != null && canonicalCategories.contains(category) ? category : 'retail';
    return Container(
      color: MarketColors.surfaceContainerHigh,
      child: Center(
        child: Image.asset(
          'assets/categories/$catSlug.png',
          width: 80,
          height: 80,
          errorBuilder: (_, _, _) => const Icon(
            Icons.storefront_rounded,
            size: 64,
            color: MarketColors.primary,
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryAvatar(String? category) {
    final catSlug = category != null && canonicalCategories.contains(category) ? category : 'retail';
    return Padding(
      padding: const EdgeInsets.all(6),
      child: Image.asset(
        'assets/categories/$catSlug.png',
        fit: BoxFit.contain,
        errorBuilder: (_, _, _) => const Icon(
          Icons.storefront_rounded,
          color: MarketColors.primary,
        ),
      ),
    );
  }

  Widget _buildPerformanceCard() {
    final viewsCount = _funnelData?.storeAndPromoViews.count ?? 0;
    final claimsCount = _funnelData?.claimsGenerated.count ?? 0;
    final redemptionsCount = _funnelData?.redemptionsCount ??
        _promos.fold<int>(0, (sum, p) => sum + p.redeemedCount);

    final hasActivity = viewsCount > 0 || claimsCount > 0 || redemptionsCount > 0;

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
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 8,
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

          // Real data 3-metric strip
          Row(
            children: [
              Expanded(
                child: _buildMetricItem(
                  title: 'Store Views',
                  count: viewsCount,
                  icon: Icons.visibility_outlined,
                  subtitle: 'Shopper views',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildMetricItem(
                  title: 'Promo Claims',
                  count: claimsCount,
                  icon: Icons.confirmation_number_outlined,
                  subtitle: 'Vouchers saved',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildMetricItem(
                  title: 'Redeemed',
                  count: redemptionsCount,
                  icon: Icons.verified_rounded,
                  subtitle: 'Completed sales',
                ),
              ),
            ],
          ),

          if (!hasActivity) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: MarketColors.surfaceContainerLow,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: const [
                  Icon(Icons.info_outline_rounded, size: 14, color: MarketColors.outline),
                  SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'No shopper activity recorded yet this week',
                      style: TextStyle(fontSize: 11, color: MarketColors.onSurfaceVariant),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMetricItem({
    required String title,
    required int count,
    required IconData icon,
    required String subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.all(10),
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
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: MarketColors.onSurfaceVariant,
                  ),
                ),
              ),
              Icon(icon, size: 14, color: MarketColors.outline),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '$count',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: MarketColors.onSurface,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w600,
              color: MarketColors.outline,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActivePromosSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 8,
          runSpacing: 4,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: const [
                Icon(Icons.campaign_rounded,
                    color: MarketColors.primary, size: 22),
                SizedBox(width: 8),
                Flexible(
                  child: Text(
                    'Active Promos',
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: MarketColors.onSurface,
                    ),
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
                  'Launch your first deal to reach shoppers entering San Jose.',
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
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: SizedBox(
                          width: 72,
                          height: 72,
                          child: PromoPhotoView(
                            promoImageUrl: promo.imageUrl,
                            businessCoverUrl: _business?.coverUrl,
                            category: _business?.category,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Wrap(
                              alignment: WrapAlignment.spaceBetween,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              spacing: 8,
                              runSpacing: 4,
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
                                  mainAxisSize: MainAxisSize.min,
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
                            const SizedBox(height: 6),
                            Text(
                              promo.title,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: MarketColors.onSurface,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
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
                  Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 8,
                    runSpacing: 4,
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
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 4,
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
                onPressed: () => _openEditBusinessModal(biz),
                child: const Text('Edit Info', style: TextStyle(fontSize: 12)),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Real Operating Hours
          Row(
            children: [
              const Icon(Icons.schedule_rounded, size: 18, color: MarketColors.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  biz?.hours != null && biz!.hours!.trim().isNotEmpty
                      ? biz.hours!.trim()
                      : biz?.openStatusText ?? 'Hours not configured',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: MarketColors.onSurface,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Real Address
          if (biz?.address != null && biz!.address!.trim().isNotEmpty) ...[
            Row(
              children: [
                const Icon(Icons.location_on_outlined, size: 18, color: MarketColors.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    biz.address!.trim(),
                    style: const TextStyle(
                      fontSize: 13,
                      color: MarketColors.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],

          // Real Hotline
          if (biz?.phone != null && biz!.phone!.trim().isNotEmpty) ...[
            Row(
              children: [
                const Icon(Icons.phone_outlined, size: 18, color: MarketColors.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    formatPhoneDisplay(biz.phone),
                    style: const TextStyle(
                      fontSize: 13,
                      color: MarketColors.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
          ],

          // Real Bio (Never hardcoded sample coffee copy!)
          Text(
            biz?.bio != null && biz!.bio!.trim().isNotEmpty
                ? biz.bio!.trim()
                : 'No shop bio added yet. Tap "Edit Info" above to tell customers about your brand specialties.',
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
