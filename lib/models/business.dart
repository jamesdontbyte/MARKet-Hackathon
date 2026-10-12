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
  final double? radiusMeters;
  final double rating;
  final bool verified;
  final String? coverUrl;
  final String? logoUrl;
  final List<String> interiorUrls;
  final List<String> openDays;
  final String? opensAt;
  final String? closesAt;
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
    this.radiusMeters,
    this.rating = 4.5,
    this.verified = false,
    this.coverUrl,
    this.logoUrl,
    this.interiorUrls = const [],
    this.openDays = const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'],
    this.opensAt,
    this.closesAt,
    required this.createdAt,
  });

  double get latitude => lat;
  double get longitude => lng;

  factory Business.fromJson(Map<String, dynamic> json) {
    List<String> parseStringList(dynamic value) {
      if (value == null) return const [];
      if (value is List) return value.map((e) => e.toString()).toList();
      return const [];
    }

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
      radiusMeters: (json['radius_m'] as num?)?.toDouble(),
      rating: (json['rating'] as num?)?.toDouble() ?? 4.5,
      verified: (json['verified'] as bool?) ?? false,
      coverUrl: json['cover_url'] as String?,
      logoUrl: json['logo_url'] as String?,
      interiorUrls: parseStringList(json['interior_urls']),
      openDays: json['open_days'] != null
          ? parseStringList(json['open_days'])
          : const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'],
      opensAt: json['opens_at'] as String?,
      closesAt: json['closes_at'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String).toUtc()
          : DateTime.now().toUtc(),
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
      'logo_url': logoUrl,
      'interior_urls': interiorUrls,
      'open_days': openDays,
      'opens_at': opensAt,
      'closes_at': closesAt,
      'created_at': createdAt.toUtc().toIso8601String(),
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
    String? logoUrl,
    List<String>? interiorUrls,
    List<String>? openDays,
    String? opensAt,
    String? closesAt,
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
      logoUrl: logoUrl ?? this.logoUrl,
      interiorUrls: interiorUrls ?? this.interiorUrls,
      openDays: openDays ?? this.openDays,
      opensAt: opensAt ?? this.opensAt,
      closesAt: closesAt ?? this.closesAt,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  /// Calculates whether business is open now based on real hours & days.
  bool get isOpenNow {
    final now = DateTime.now().toLocal();
    final weekday = now.weekday; // 1 = Mon .. 7 = Sun
    final dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final currentDayName = dayNames[weekday - 1];

    if (openDays.isNotEmpty) {
      final normalizedDays = openDays.map((d) => d.toLowerCase().trim()).toSet();
      final isDayOpen = normalizedDays.contains(currentDayName.toLowerCase()) ||
          normalizedDays.contains(currentDayName.substring(0, 1).toLowerCase()) ||
          normalizedDays.contains(['m', 't', 'w', 'th', 'f', 'sa', 'su'][weekday - 1]);
      if (!isDayOpen) return false;
    }

    if (opensAt != null && closesAt != null) {
      final openMinutes = _parseMinutes(opensAt!);
      final closeMinutes = _parseMinutes(closesAt!);
      if (openMinutes != null && closeMinutes != null) {
        final currentMinutes = now.hour * 60 + now.minute;
        return currentMinutes >= openMinutes && currentMinutes <= closeMinutes;
      }
    }

    return true;
  }

  /// Formatted status pill text, e.g. "Open • Closes 9:00 PM" or "Closed • Opens 7:30 AM".
  String get openStatusText {
    final now = DateTime.now().toLocal();
    final weekday = now.weekday;
    final dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final currentDayName = dayNames[weekday - 1];

    if (openDays.isNotEmpty) {
      final normalizedDays = openDays.map((d) => d.toLowerCase().trim()).toSet();
      final isDayOpen = normalizedDays.contains(currentDayName.toLowerCase()) ||
          normalizedDays.contains(currentDayName.substring(0, 1).toLowerCase()) ||
          normalizedDays.contains(['m', 't', 'w', 'th', 'f', 'sa', 'su'][weekday - 1]);
      if (!isDayOpen) return 'Closed today';
    }

    if (opensAt != null && closesAt != null) {
      final openMinutes = _parseMinutes(opensAt!);
      final closeMinutes = _parseMinutes(closesAt!);
      if (openMinutes != null && closeMinutes != null) {
        final currentMinutes = now.hour * 60 + now.minute;
        if (currentMinutes < openMinutes) {
          return 'Closed • Opens ${_formatTimeString(opensAt!)}';
        } else if (currentMinutes > closeMinutes) {
          return 'Closed for today';
        } else {
          return 'Open • Closes ${_formatTimeString(closesAt!)}';
        }
      }
    }

    if (hours != null && hours!.trim().isNotEmpty) {
      return 'Open • ${hours!.trim()}';
    }
    return 'Open today';
  }

  static int? _parseMinutes(String str) {
    try {
      final s = str.trim().toUpperCase();
      final isPm = s.contains('PM');
      final isAm = s.contains('AM');
      final clean = s.replaceAll('AM', '').replaceAll('PM', '').trim();
      final parts = clean.split(':');
      if (parts.length >= 2) {
        var h = int.parse(parts[0].trim());
        final m = int.parse(parts[1].trim());
        if (isPm && h < 12) h += 12;
        if (isAm && h == 12) h = 0;
        return h * 60 + m;
      }
    } catch (_) {}
    return null;
  }

  static String _formatTimeString(String str) {
    try {
      final minutes = _parseMinutes(str);
      if (minutes != null) {
        final h24 = minutes ~/ 60;
        final m = minutes % 60;
        final h12 = h24 == 0 ? 12 : (h24 > 12 ? h24 - 12 : h24);
        final ampm = h24 >= 12 ? 'PM' : 'AM';
        final mStr = m.toString().padLeft(2, '0');
        return '$h12:$mStr $ampm';
      }
    } catch (_) {}
    return str;
  }
}
