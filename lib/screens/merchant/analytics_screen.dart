import 'package:flutter/material.dart';
import '../../core/theme.dart';
import '../../models/business.dart';
import '../../models/merchant_analytics.dart';
import '../../services/auth_service.dart';
import '../../services/data_service.dart';
import '../../widgets/app_bottom_nav.dart';
import '../../widgets/app_header.dart';
import 'account_screen.dart';
import 'catalog_screen.dart';
import 'dashboard_screen.dart';
import 'promotions_screen.dart';

/// MerchantAnalyticsScreen matches Stitch frame: market_tab_3_analytics
/// Visualizes the 7-day MSME conversion funnel from geofence_events,
/// a proximity radar visualizer, and peak footfall insights.
class MerchantAnalyticsScreen extends StatefulWidget {
  final Business? business;
  final DataService? dataService;

  const MerchantAnalyticsScreen({
    super.key,
    this.business,
    this.dataService,
  });

  @override
  State<MerchantAnalyticsScreen> createState() => _MerchantAnalyticsScreenState();
}

class _MerchantAnalyticsScreenState extends State<MerchantAnalyticsScreen>
    with SingleTickerProviderStateMixin {
  late final DataService _dataService;
  final AuthService _authService = AuthService();

  Business? _business;
  MerchantAnalyticsData? _analyticsData;
  bool _isLoading = true;
  String? _errorMessage;
  final String _selectedDateFilter = '7-Day Cohort';

  late final AnimationController _radarController;

  @override
  void initState() {
    super.initState();
    _dataService = widget.dataService ?? DataService();
    _business = widget.business;

    _radarController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();

    _loadAnalytics();
  }

  @override
  void dispose() {
    _radarController.dispose();
    super.dispose();
  }

  Future<void> _loadAnalytics() async {
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
        final data = await _dataService.fetchMerchantFunnel(_business!.id);
        if (mounted) {
          setState(() {
            _analyticsData = data;
            _isLoading = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _analyticsData = MerchantAnalyticsData.zero();
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _analyticsData = MerchantAnalyticsData.zero();
          _isLoading = false;
          _errorMessage =
              'Could not load telemetry: ${e.toString().replaceAll("Exception:", "").trim()}';
        });
      }
    }
  }

  void _onBottomNavTapped(int index) {
    if (index == 2) return; // Already on Analytics
    if (index == 0) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => MerchantDashboardScreen(business: _business),
        ),
      );
    } else if (index == 1) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => MerchantCatalogScreen(business: _business),
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

  void _openCreatePromoScreen() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MerchantPromotionsScreen(business: _business),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bizName = _business?.name.isNotEmpty == true
        ? _business!.name
        : 'My Business';

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        _onBottomNavTapped(0);
      },
      child: Scaffold(
        backgroundColor: MarketColors.surface,
        appBar: const AppHeader(
          showBack: false,
          subtitle: 'Analytics',
        ),
        body: SafeArea(
          child: RefreshIndicator(
            onRefresh: _loadAnalytics,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(
                MarketSpacing.screenMargin,
                8,
                MarketSpacing.screenMargin,
                88,
              ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Store Context & Location Row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          const Icon(
                            Icons.storefront_rounded,
                            size: 18,
                            color: MarketColors.primary,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              bizName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: MarketColors.onSurface,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: MarketColors.primaryContainer.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: MarketColors.primaryContainer.withValues(alpha: 0.3),
                        ),
                      ),
                      child: const Text(
                        'San Jose de Buenavista',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: MarketColors.primary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                if (_isLoading)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 60),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else ...[
                  // Error notice if Supabase was unreachable
                  if (_errorMessage != null)
                    Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF3C7),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFF59E0B)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.info_outline_rounded,
                              size: 18, color: Color(0xFFD97706)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Displaying baseline benchmarks: $_errorMessage',
                              style: const TextStyle(
                                fontSize: 11,
                                color: Color(0xFF92400E),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                  // 1. Radar Visualizer Card
                  _buildRadarCard(bizName),
                  const SizedBox(height: 16),

                  // 2. 7-Day Conversion Funnel Card
                  _buildFunnelCard(_analyticsData ?? MerchantAnalyticsData.zero()),
                  const SizedBox(height: 16),

                  // 3. Peak Footfall Insights Card
                  _buildPeakInsightsCard(),
                  const SizedBox(height: 32),
                ],
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: AppBottomNav(
        currentIndex: 2,
        role: AppNavRole.merchant,
        onTap: _onBottomNavTapped,
      ),
    ),
  );
}

  Widget _buildRadarCard(String bizName) {
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.radar_rounded, color: MarketColors.primary, size: 22),
              SizedBox(width: 8),
              Text(
                'Geofence Range',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: MarketColors.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'Real-time localized customer proximity',
            style: TextStyle(
              fontSize: 12,
              color: MarketColors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),

          // Radar Screen Area
          Container(
            height: 200,
            width: double.infinity,
            decoration: BoxDecoration(
              color: MarketColors.surfaceContainerLow,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: MarketColors.outlineVariant.withValues(alpha: 0.25),
              ),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Animated Expanding Radar Rings
                AnimatedBuilder(
                  animation: _radarController,
                  builder: (context, _) {
                    final scale = 0.8 + (_radarController.value * 0.4);
                    final opacity = (1.0 - _radarController.value).clamp(0.0, 1.0);
                    return Transform.scale(
                      scale: scale,
                      child: Container(
                        width: 160,
                        height: 160,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: MarketColors.primaryContainer.withValues(alpha: opacity * 0.7),
                            width: 1.5,
                          ),
                          color: MarketColors.primaryContainer.withValues(alpha: opacity * 0.08),
                        ),
                      ),
                    );
                  },
                ),

                // Concentric Fixed Rings
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: MarketColors.primaryContainer.withValues(alpha: 0.2),
                      width: 1,
                    ),
                  ),
                ),
                Container(
                  width: 70,
                  height: 70,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: MarketColors.primary.withValues(alpha: 0.2),
                      width: 1,
                    ),
                  ),
                ),

                // Pulsing Pedestrian Points (San Jose zone simulator)
                Positioned(
                  top: 40,
                  left: 60,
                  child: _buildRadarBlip(),
                ),
                Positioned(
                  top: 50,
                  right: 70,
                  child: _buildRadarBlip(),
                ),
                Positioned(
                  bottom: 45,
                  left: 75,
                  child: _buildRadarBlip(),
                ),
                Positioned(
                  bottom: 55,
                  right: 80,
                  child: _buildRadarBlip(),
                ),

                // Center Merchant Node
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: MarketColors.onSurface,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: MarketColors.primaryContainer,
                          width: 2,
                        ),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x30000000),
                            blurRadius: 10,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.storefront_rounded,
                        color: MarketColors.primaryContainer,
                        size: 24,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: MarketColors.onSurface.withValues(alpha: 0.9),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        bizName,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),

                // Active Discovery Radius Tag
                Positioned(
                  top: 10,
                  right: 10,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x0A0F172A),
                          blurRadius: 4,
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(
                            color: MarketColors.primaryContainer,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Text(
                          'Active Discovery Radius',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: MarketColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // RA 10173 Compliance Note
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: MarketColors.surfaceContainerLow,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: MarketColors.outlineVariant.withValues(alpha: 0.2),
              ),
            ),
            child: const Row(
              children: [
                Icon(Icons.verified_user_rounded,
                    size: 16, color: MarketColors.primary),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Complies with RA 10173 (Philippine Data Privacy Act) — aggregated anonymous footfall only.',
                    style: TextStyle(
                      fontSize: 11,
                      color: MarketColors.onSurfaceVariant,
                      height: 1.3,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRadarBlip() {
    return Container(
      width: 7,
      height: 7,
      decoration: BoxDecoration(
        color: MarketColors.primaryContainer,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: MarketColors.primaryContainer.withValues(alpha: 0.6),
            blurRadius: 6,
            spreadRadius: 1,
          ),
        ],
      ),
    );
  }

  Widget _buildFunnelCard(MerchantAnalyticsData data) {
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.filter_alt_rounded,
                      color: MarketColors.primary, size: 22),
                  SizedBox(width: 8),
                  Text(
                    'Conversion Funnel',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: MarketColors.onSurface,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: MarketColors.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _selectedDateFilter,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: MarketColors.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Step 1: Pings Sent
          _buildFunnelRow(
            stepIndex: 1,
            title: data.pingsSent.title,
            countText: _formatCount(data.pingsSent.count),
            subtext: 'pedestrians',
            barFillFraction: data.pingsSent.count > 0 ? 1.0 : 0.0,
            barColor: MarketColors.primary,
          ),
          const SizedBox(height: 14),

          // Step 2: Delivered & Opened
          _buildFunnelRow(
            stepIndex: 2,
            title: data.deliveredAndOpened.title,
            countText: _formatCount(data.deliveredAndOpened.count),
            subtext: '· ${data.deliveredAndOpened.conversionRate}%',
            barFillFraction: data.deliveredAndOpened.count > 0
                ? (data.deliveredAndOpened.conversionRate / 100).clamp(0.05, 1.0)
                : 0.0,
            barColor: MarketColors.primaryContainer,
          ),
          const SizedBox(height: 14),

          // Step 3: Store & Promo Views
          _buildFunnelRow(
            stepIndex: 3,
            title: data.storeAndPromoViews.title,
            countText: _formatCount(data.storeAndPromoViews.count),
            subtext: '· ${data.storeAndPromoViews.conversionRate}%',
            barFillFraction: data.storeAndPromoViews.count > 0
                ? (data.storeAndPromoViews.conversionRate / 100).clamp(0.05, 1.0)
                : 0.0,
            barColor: const Color(0xFF6FBFFF),
          ),
          const SizedBox(height: 14),

          // Step 4: Promo Claims Generated
          _buildFunnelRow(
            stepIndex: 4,
            title: data.claimsGenerated.title,
            countText: _formatCount(data.claimsGenerated.count),
            subtext: '· ${data.claimsGenerated.conversionRate}%',
            barFillFraction: data.claimsGenerated.count > 0
                ? (data.claimsGenerated.conversionRate / 100).clamp(0.05, 1.0)
                : 0.0,
            barColor: const Color(0xFF7AD0FF),
          ),
          const SizedBox(height: 14),

          // Step 5: Counter QR Scanned / Redeemed (Highlighted Conversion Hero)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: MarketColors.surfaceContainerLow,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: MarketColors.primaryContainer.withValues(alpha: 0.4),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Container(
                            width: 20,
                            height: 20,
                            decoration: const BoxDecoration(
                              color: MarketColors.primary,
                              shape: BoxShape.circle,
                            ),
                            alignment: Alignment.center,
                            child: const Text(
                              '5',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              data.counterRedemptions.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: MarketColors.primary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _formatCount(data.counterRedemptions.count),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: MarketColors.primary,
                      ),
                    ),
                    Text(
                      '· ${data.counterRedemptions.conversionRate}% redemption',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF16A34A),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    height: 8,
                    color: MarketColors.surfaceContainerHigh,
                    child: FractionallySizedBox(
                      alignment: Alignment.centerLeft,
                      widthFactor: data.counterRedemptions.count > 0
                          ? (data.counterRedemptions.conversionRate / 100).clamp(0.05, 1.0)
                          : 0.0,
                      child: Container(color: MarketColors.primaryContainer),
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                const Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    'High in-store walk-in completion',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                      color: MarketColors.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (data.pingsSent.count == 0 && data.counterRedemptions.count == 0) ...[
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: MarketColors.surfaceContainerLow,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: const [
                  Icon(Icons.info_outline_rounded, size: 16, color: MarketColors.outline),
                  SizedBox(width: 8),
                  Text(
                    'No activity yet this week',
                    style: TextStyle(fontSize: 12, color: MarketColors.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFunnelRow({
    required int stepIndex,
    required String title,
    required String countText,
    required String subtext,
    required double barFillFraction,
    required Color barColor,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Row(
                children: [
                  Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      color: MarketColors.surfaceContainerHigh,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      stepIndex.toString(),
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: MarketColors.primary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: MarketColors.onSurface,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            RichText(
              text: TextSpan(
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: MarketColors.onSurface,
                ),
                children: [
                  TextSpan(text: countText),
                  const TextSpan(text: ' '),
                  TextSpan(
                    text: subtext,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: MarketColors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: Container(
            height: 6,
            width: double.infinity,
            color: MarketColors.surfaceContainerHigh,
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: barFillFraction.clamp(0.0, 1.0),
              child: Container(color: barColor),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPeakInsightsCard() {
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: Row(
                  children: [
                    Icon(Icons.insights_rounded,
                        color: MarketColors.primary, size: 20),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Peak Footfall Insights',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: MarketColors.onSurface,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: MarketColors.primaryContainer.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text(
                  'AI Proximity',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: MarketColors.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Insight highlight box
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: MarketColors.surfaceContainerLow,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: MarketColors.outlineVariant.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: MarketColors.primaryContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.lightbulb_rounded,
                    size: 18,
                    color: MarketColors.onSurface,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Peak nearby foot traffic is 4:00 PM – 6:30 PM on Thursdays & Fridays.',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: MarketColors.onSurface,
                          height: 1.3,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Recommend launching happy hour promos during this window to capture afternoon office-commute coffee drinkers.',
                        style: TextStyle(
                          fontSize: 12,
                          color: MarketColors.onSurfaceVariant,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Schedule Footfall Promo CTA
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: MarketColors.primaryContainer,
              foregroundColor: MarketColors.onSurface,
              minimumSize: const Size(double.infinity, 48),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            icon: const Icon(Icons.add_circle_outline_rounded, size: 18),
            label: const Text(
              'Schedule Footfall Promo',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
            onPressed: _openCreatePromoScreen,
          ),
        ],
      ),
    );
  }

  String _formatCount(int number) {
    if (number >= 1000) {
      final s = number.toString();
      final remainder = s.substring(s.length - 3);
      final leading = s.substring(0, s.length - 3);
      return '$leading,$remainder';
    }
    return number.toString();
  }
}
