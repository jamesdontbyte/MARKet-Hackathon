/// Represents an individual step in the 7-day merchant conversion funnel.
class FunnelStep {
  final String title;
  final int count;
  final String unit;
  final double conversionRate; // e.g. 33.7 for 33.7%
  final bool isSampleData;

  const FunnelStep({
    required this.title,
    required this.count,
    required this.unit,
    required this.conversionRate,
    required this.isSampleData,
  });

  FunnelStep copyWith({
    String? title,
    int? count,
    String? unit,
    double? conversionRate,
    bool? isSampleData,
  }) {
    return FunnelStep(
      title: title ?? this.title,
      count: count ?? this.count,
      unit: unit ?? this.unit,
      conversionRate: conversionRate ?? this.conversionRate,
      isSampleData: isSampleData ?? this.isSampleData,
    );
  }
}

/// 7-day funnel metrics for the MSME merchant analytics dashboard.
/// Fallback numbers come from specs/04-demo-shortcuts.md.
class MerchantAnalyticsData {
  final FunnelStep pingsSent;
  final FunnelStep deliveredAndOpened;
  final FunnelStep storeAndPromoViews;
  final FunnelStep claimsGenerated;
  final FunnelStep counterRedemptions;

  const MerchantAnalyticsData({
    required this.pingsSent,
    required this.deliveredAndOpened,
    required this.storeAndPromoViews,
    required this.claimsGenerated,
    required this.counterRedemptions,
  });

  /// Default fallback numbers from specs/04-demo-shortcuts.md
  factory MerchantAnalyticsData.fallback() {
    return const MerchantAnalyticsData(
      pingsSent: FunnelStep(
        title: 'Geofence Pings Sent',
        count: 1840,
        unit: 'pedestrians',
        conversionRate: 100.0,
        isSampleData: true,
      ),
      deliveredAndOpened: FunnelStep(
        title: 'Delivered & Opened Notifications',
        count: 620,
        unit: 'opened',
        conversionRate: 33.7,
        isSampleData: true,
      ),
      storeAndPromoViews: FunnelStep(
        title: 'Store & Promo Views',
        count: 412,
        unit: 'views',
        conversionRate: 66.4,
        isSampleData: true,
      ),
      claimsGenerated: FunnelStep(
        title: 'Promo Claims Generated',
        count: 142,
        unit: 'claims',
        conversionRate: 34.5,
        isSampleData: true,
      ),
      counterRedemptions: FunnelStep(
        title: 'Counter QR Scanned / Redeemed',
        count: 118,
        unit: 'redemptions',
        conversionRate: 83.1,
        isSampleData: true,
      ),
    );
  }

  /// Create analytics data from real Supabase counts, falling back to specs per metric when 0.
  factory MerchantAnalyticsData.fromCounts({
    required int realPings,
    required int realOpened,
    required int realViews,
    required int realClaims,
    required int realRedeemed,
  }) {
    final pingsCount = realPings > 0 ? realPings : 1840;
    final isPingsSample = realPings <= 0;

    final openedCount = realOpened > 0 ? realOpened : 620;
    final isOpenedSample = realOpened <= 0;
    final openedRate = isOpenedSample
        ? 33.7
        : (pingsCount > 0 ? (openedCount / pingsCount * 100) : 0.0);

    final viewsCount = realViews > 0 ? realViews : 412;
    final isViewsSample = realViews <= 0;
    final viewsRate = isViewsSample
        ? 66.4
        : (openedCount > 0 ? (viewsCount / openedCount * 100) : 0.0);

    final claimsCount = realClaims > 0 ? realClaims : 142;
    final isClaimsSample = realClaims <= 0;
    final claimsRate = isClaimsSample
        ? 34.5
        : (viewsCount > 0 ? (claimsCount / viewsCount * 100) : 0.0);

    final redeemedCount = realRedeemed > 0 ? realRedeemed : 118;
    final isRedeemedSample = realRedeemed <= 0;
    final redeemedRate = isRedeemedSample
        ? 83.1
        : (claimsCount > 0 ? (redeemedCount / claimsCount * 100) : 0.0);

    return MerchantAnalyticsData(
      pingsSent: FunnelStep(
        title: 'Geofence Pings Sent',
        count: pingsCount,
        unit: 'pedestrians',
        conversionRate: 100.0,
        isSampleData: isPingsSample,
      ),
      deliveredAndOpened: FunnelStep(
        title: 'Delivered & Opened Notifications',
        count: openedCount,
        unit: 'opened',
        conversionRate: double.parse(openedRate.toStringAsFixed(1)),
        isSampleData: isOpenedSample,
      ),
      storeAndPromoViews: FunnelStep(
        title: 'Store & Promo Views',
        count: viewsCount,
        unit: 'views',
        conversionRate: double.parse(viewsRate.toStringAsFixed(1)),
        isSampleData: isViewsSample,
      ),
      claimsGenerated: FunnelStep(
        title: 'Promo Claims Generated',
        count: claimsCount,
        unit: 'claims',
        conversionRate: double.parse(claimsRate.toStringAsFixed(1)),
        isSampleData: isClaimsSample,
      ),
      counterRedemptions: FunnelStep(
        title: 'Counter QR Scanned / Redeemed',
        count: redeemedCount,
        unit: 'redemptions',
        conversionRate: double.parse(redeemedRate.toStringAsFixed(1)),
        isSampleData: isRedeemedSample,
      ),
    );
  }
}
