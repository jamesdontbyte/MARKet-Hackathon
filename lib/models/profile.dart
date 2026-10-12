class Profile {
  final String id;
  final String role; // 'shopper' or 'merchant'
  final String? fullName;
  final String? phone;
  final List<String> interests;
  final Map<String, dynamic> prefs;
  final DateTime createdAt;

  const Profile({
    required this.id,
    required this.role,
    this.fullName,
    this.phone,
    this.interests = const [],
    this.prefs = const {
      'flash_promos': true,
      'expiry_reminders': true,
      'weekly_digest': false,
    },
    required this.createdAt,
  });

  bool get isShopper => role == 'shopper';
  bool get isMerchant => role == 'merchant';

  factory Profile.fromJson(Map<String, dynamic> json) {
    return Profile(
      id: json['id'] as String,
      role: (json['role'] as String?) ?? 'shopper',
      fullName: json['full_name'] as String?,
      phone: json['phone'] as String?,
      interests: (json['interests'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      prefs: (json['prefs'] as Map<String, dynamic>?) ??
          const {
            'flash_promos': true,
            'expiry_reminders': true,
            'weekly_digest': false,
          },
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String).toUtc()
          : DateTime.now().toUtc(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'role': role,
      'full_name': fullName,
      'phone': phone,
      'interests': interests,
      'prefs': prefs,
      'created_at': createdAt.toUtc().toIso8601String(),
    };
  }

  Profile copyWith({
    String? id,
    String? role,
    String? fullName,
    String? phone,
    List<String>? interests,
    Map<String, dynamic>? prefs,
    DateTime? createdAt,
  }) {
    return Profile(
      id: id ?? this.id,
      role: role ?? this.role,
      fullName: fullName ?? this.fullName,
      phone: phone ?? this.phone,
      interests: interests ?? this.interests,
      prefs: prefs ?? this.prefs,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
