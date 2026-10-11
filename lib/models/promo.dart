class Promo {
  final String id;
  final String businessId;
  final String title;
  final String? description;
  final String promoType; // 'bogo', 'percent', 'amount_off'
  final String? valueLabel; // 'BOGO', '20% OFF', '₱100 OFF'
  final DateTime startsAt;
  final DateTime endsAt;
  final int redeemLimit;
  final int redeemedCount;
  final bool active;
  final DateTime createdAt;

  const Promo({
    required this.id,
    required this.businessId,
    required this.title,
    this.description,
    this.promoType = 'percent',
    this.valueLabel,
    required this.startsAt,
    required this.endsAt,
    this.redeemLimit = 100,
    this.redeemedCount = 0,
    this.active = true,
    required this.createdAt,
  });

  /// Evaluates whether the promo is currently redeemable
  bool get isCurrentlyValid {
    final now = DateTime.now();
    return active &&
        now.isAfter(startsAt) &&
        now.isBefore(endsAt) &&
        redeemedCount < redeemLimit;
  }

  /// Calculates percentage of vouchers claimed / redeemed
  double get progressFraction {
    if (redeemLimit <= 0) return 0.0;
    return (redeemedCount / redeemLimit).clamp(0.0, 1.0);
  }

  factory Promo.fromJson(Map<String, dynamic> json) {
    return Promo(
      id: json['id'] as String,
      businessId: json['business_id'] as String,
      title: (json['title'] as String?) ?? '',
      description: json['description'] as String?,
      promoType: (json['promo_type'] as String?) ?? 'percent',
      valueLabel: json['value_label'] as String?,
      startsAt: json['starts_at'] != null
          ? DateTime.parse(json['starts_at'] as String)
          : DateTime.now(),
      endsAt: json['ends_at'] != null
          ? DateTime.parse(json['ends_at'] as String)
          : DateTime.now().add(const Duration(days: 7)),
      redeemLimit: (json['redeem_limit'] as num?)?.toInt() ?? 100,
      redeemedCount: (json['redeemed_count'] as num?)?.toInt() ?? 0,
      active: (json['active'] as bool?) ?? true,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'business_id': businessId,
      'title': title,
      'description': description,
      'promo_type': promoType,
      'value_label': valueLabel,
      'starts_at': startsAt.toIso8601String(),
      'ends_at': endsAt.toIso8601String(),
      'redeem_limit': redeemLimit,
      'redeemed_count': redeemedCount,
      'active': active,
      'created_at': createdAt.toIso8601String(),
    };
  }

  Promo copyWith({
    String? id,
    String? businessId,
    String? title,
    String? description,
    String? promoType,
    String? valueLabel,
    DateTime? startsAt,
    DateTime? endsAt,
    int? redeemLimit,
    int? redeemedCount,
    bool? active,
    DateTime? createdAt,
  }) {
    return Promo(
      id: id ?? this.id,
      businessId: businessId ?? this.businessId,
      title: title ?? this.title,
      description: description ?? this.description,
      promoType: promoType ?? this.promoType,
      valueLabel: valueLabel ?? this.valueLabel,
      startsAt: startsAt ?? this.startsAt,
      endsAt: endsAt ?? this.endsAt,
      redeemLimit: redeemLimit ?? this.redeemLimit,
      redeemedCount: redeemedCount ?? this.redeemedCount,
      active: active ?? this.active,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
