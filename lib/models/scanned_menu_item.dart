class ScannedMenuItem {
  final String name;
  final double? price;
  final String category;
  final String? description;
  final double confidence;

  const ScannedMenuItem({
    required this.name,
    this.price,
    this.category = 'General',
    this.description,
    this.confidence = 1.0,
  });

  factory ScannedMenuItem.fromJson(Map<String, dynamic> json) {
    return ScannedMenuItem(
      name: (json['name'] as String?)?.trim() ?? '',
      price: (json['price'] as num?)?.toDouble(),
      category: (json['category'] as String?)?.trim().isNotEmpty == true
          ? (json['category'] as String).trim()
          : 'General',
      description: json['description'] as String?,
      confidence: (json['confidence'] as num?)?.toDouble() ?? 1.0,
    );
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'price': price,
    'category': category,
    'description': description,
    'confidence': confidence,
  };

  ScannedMenuItem copyWith({
    String? name,
    double? price,
    String? category,
    String? description,
    double? confidence,
  }) {
    return ScannedMenuItem(
      name: name ?? this.name,
      price: price ?? this.price,
      category: category ?? this.category,
      description: description ?? this.description,
      confidence: confidence ?? this.confidence,
    );
  }
}

class ScanMenuResult {
  final List<ScannedMenuItem> items;
  final String? notes;

  const ScanMenuResult({
    required this.items,
    this.notes,
  });
}
