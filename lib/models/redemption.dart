class Redemption {
  final String id;
  final String promoId;
  final String userId;
  final String code; // 8-char uppercase alphanumeric e.g. 'KT8X29Q1'
  final String status; // 'issued' or 'redeemed'
  final DateTime createdAt;
  final DateTime? redeemedAt;

  const Redemption({
    required this.id,
    required this.promoId,
    required this.userId,
    required this.code,
    this.status = 'issued',
    required this.createdAt,
    this.redeemedAt,
  });

  bool get isRedeemed => status == 'redeemed';
  bool get isIssued => status == 'issued';

  factory Redemption.fromJson(Map<String, dynamic> json) {
    return Redemption(
      id: json['id'] as String,
      promoId: json['promo_id'] as String,
      userId: json['user_id'] as String,
      code: ((json['code'] as String?) ?? '').toUpperCase().trim(),
      status: (json['status'] as String?) ?? 'issued',
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String).toUtc()
          : DateTime.now().toUtc(),
      redeemedAt: json['redeemed_at'] != null
          ? DateTime.parse(json['redeemed_at'] as String).toUtc()
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'promo_id': promoId,
      'user_id': userId,
      'code': code,
      'status': status,
      'created_at': createdAt.toUtc().toIso8601String(),
      'redeemed_at': redeemedAt?.toUtc().toIso8601String(),
    };
  }

  Redemption copyWith({
    String? id,
    String? promoId,
    String? userId,
    String? code,
    String? status,
    DateTime? createdAt,
    DateTime? redeemedAt,
  }) {
    return Redemption(
      id: id ?? this.id,
      promoId: promoId ?? this.promoId,
      userId: userId ?? this.userId,
      code: code ?? this.code,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      redeemedAt: redeemedAt ?? this.redeemedAt,
    );
  }
}
