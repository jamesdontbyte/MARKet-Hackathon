class Business {
  final String id;
  final String? ownerId;
  final String name;
  final String category;
  final String? subtitle;
  final String? bio;
  final String? address;
  final String? phone;
  final String? hours;
  final double lat;
  final double lng;
  final double radiusMeters;
  final double rating;
  final bool verified;
  final String? coverUrl;
  final DateTime createdAt;

  const Business({
    required this.id,
    this.ownerId,
    required this.name,
    required this.category,
    this.subtitle,
    this.bio,
    this.address,
    this.phone,
    this.hours,
    required this.lat,
    required this.lng,
    this.radiusMeters = 1500.0,
    this.rating = 4.5,
    this.verified = false,
    this.coverUrl,
    required this.createdAt,
  });

  factory Business.fromJson(Map<String, dynamic> json) {
    return Business(
      id: json['id'] as String,
      ownerId: json['owner_id'] as String?,
      name: (json['name'] as String?) ?? '',
      category: (json['category'] as String?) ?? 'retail',
      subtitle: json['subtitle'] as String?,
      bio: json['bio'] as String?,
      address: json['address'] as String?,
      phone: json['phone'] as String?,
      hours: json['hours'] as String?,
      lat: (json['lat'] as num?)?.toDouble() ?? 0.0,
      lng: (json['lng'] as num?)?.toDouble() ?? 0.0,
      radiusMeters: (json['radius_m'] as num?)?.toDouble() ?? 1500.0,
      rating: (json['rating'] as num?)?.toDouble() ?? 4.5,
      verified: (json['verified'] as bool?) ?? false,
      coverUrl: json['cover_url'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'owner_id': ownerId,
      'name': name,
      'category': category,
      'subtitle': subtitle,
      'bio': bio,
      'address': address,
      'phone': phone,
      'hours': hours,
      'lat': lat,
      'lng': lng,
      'radius_m': radiusMeters,
      'rating': rating,
      'verified': verified,
      'cover_url': coverUrl,
      'created_at': createdAt.toIso8601String(),
    };
  }

  Business copyWith({
    String? id,
    String? ownerId,
    String? name,
    String? category,
    String? subtitle,
    String? bio,
    String? address,
    String? phone,
    String? hours,
    double? lat,
    double? lng,
    double? radiusMeters,
    double? rating,
    bool? verified,
    String? coverUrl,
    DateTime? createdAt,
  }) {
    return Business(
      id: id ?? this.id,
      ownerId: ownerId ?? this.ownerId,
      name: name ?? this.name,
      category: category ?? this.category,
      subtitle: subtitle ?? this.subtitle,
      bio: bio ?? this.bio,
      address: address ?? this.address,
      phone: phone ?? this.phone,
      hours: hours ?? this.hours,
      lat: lat ?? this.lat,
      lng: lng ?? this.lng,
      radiusMeters: radiusMeters ?? this.radiusMeters,
      rating: rating ?? this.rating,
      verified: verified ?? this.verified,
      coverUrl: coverUrl ?? this.coverUrl,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
