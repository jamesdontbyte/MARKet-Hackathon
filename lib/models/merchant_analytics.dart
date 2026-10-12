/// Represents an individual step in the 7-day merchant conversion funnel.
class FunnelStep {
  final String title;
  final int count;
  final String unit;
  final double conversionRate; // e.g. 33.7 for 33.7%

  const FunnelStep({
    required this.title,
    required this.count,
    required this.unit,
    required this.conversionRate,
  });

  FunnelStep copyWith({
    String? title,
    int? count,
    String? unit,
    double? conversionRate,
  }) {
    return FunnelStep(
      title: title ?? this.title,
      count: count ?? this.count,
      unit: unit ?? this.unit,
      conversionRate: conversionRate ?? this.conversionRate,
    );
  }
}

/// 7-day funnel metrics for the MSME merchant analytics dashboard.
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

  /// All-zero metrics empty state
  factory MerchantAnalyticsData.zero() {
    return const MerchantAnalyticsData(
      pingsSent: FunnelStep(
        title: 'Geofence Pings Sent',
        count: 0,
        unit: 'pedestrians',
        conversionRate: 100.0,
      ),
      deliveredAndOpened: FunnelStep(
        title: 'Delivered & Opened Notifications',
        count: 0,
        unit: 'opened',
        conversionRate: 0.0,
      ),
      storeAndPromoViews: FunnelStep(
        title: 'Store & Promo Views',
        count: 0,
        unit: 'views',
        conversionRate: 0.0,
      ),
      claimsGenerated: FunnelStep(
        title: 'Promo Claims Generated',
        count: 0,
        unit: 'claims',
        conversionRate: 0.0,
      ),
      counterRedemptions: FunnelStep(
        title: 'Counter QR Scanned / Redeemed',
        count: 0,
        unit: 'redemptions',
        conversionRate: 0.0,
      ),
    );
  }

  bool get hasActivity =>
      pingsSent.count > 0 ||
      deliveredAndOpened.count > 0 ||
      storeAndPromoViews.count > 0 ||
      claimsGenerated.count > 0 ||
      counterRedemptions.count > 0;

  /// Create analytics data from real Supabase counts.
  factory MerchantAnalyticsData.fromCounts({
    required int realPings,
    required int realOpened,
    required int realViews,
    required int realClaims,
    required int realRedeemed,
  }) {
    final openedRate = realPings > 0 ? (realOpened / realPings * 100) : 0.0;
    final viewsRate = realOpened > 0 ? (realViews / realOpened * 100) : 0.0;
    final claimsRate = realViews > 0 ? (realClaims / realViews * 100) : 0.0;
    final redeemedRate = realClaims > 0 ? (realRedeemed / realClaims * 100) : 0.0;

    return MerchantAnalyticsData(
      pingsSent: FunnelStep(
        title: 'Geofence Pings Sent',
        count: realPings,
        unit: 'pedestrians',
        conversionRate: 100.0,
      ),
      deliveredAndOpened: FunnelStep(
        title: 'Delivered & Opened Notifications',
        count: realOpened,
        unit: 'opened',
        conversionRate: double.parse(openedRate.toStringAsFixed(1)),
      ),
      storeAndPromoViews: FunnelStep(
        title: 'Store & Promo Views',
        count: realViews,
        unit: 'views',
        conversionRate: double.parse(viewsRate.toStringAsFixed(1)),
      ),
      claimsGenerated: FunnelStep(
        title: 'Promo Claims Generated',
        count: realClaims,
        unit: 'claims',
        conversionRate: double.parse(claimsRate.toStringAsFixed(1)),
      ),
      counterRedemptions: FunnelStep(
        title: 'Counter QR Scanned / Redeemed',
        count: realRedeemed,
        unit: 'redemptions',
        conversionRate: double.parse(redeemedRate.toStringAsFixed(1)),
      ),
    );
  }
}
