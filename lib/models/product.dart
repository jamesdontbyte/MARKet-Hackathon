class Product {
  final String id;
  final String businessId;
  final String name;
  final double price;
  final String? category;
  final String? description;
  final String? imageUrl;
  final bool isBestSeller;
  final bool available;
  final DateTime createdAt;

  const Product({
    required this.id,
    required this.businessId,
    required this.name,
    required this.price,
    this.category,
    this.description,
    this.imageUrl,
    this.isBestSeller = false,
    this.available = true,
    required this.createdAt,
  });

  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      id: json['id'] as String,
      businessId: json['business_id'] as String,
      name: (json['name'] as String?) ?? '',
      price: (json['price'] as num?)?.toDouble() ?? 0.0,
      category: json['category'] as String?,
      description: json['description'] as String?,
      imageUrl: json['image_url'] as String?,
      isBestSeller: (json['is_best_seller'] as bool?) ?? false,
      available: (json['available'] as bool?) ?? true,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String).toUtc()
          : DateTime.now().toUtc(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'business_id': businessId,
      'name': name,
      'price': price,
      'category': category,
      'description': description,
      'image_url': imageUrl,
      'is_best_seller': isBestSeller,
      'available': available,
      'created_at': createdAt.toUtc().toIso8601String(),
    };
  }

  Product copyWith({
    String? id,
    String? businessId,
    String? name,
    double? price,
    String? category,
    String? description,
    String? imageUrl,
    bool? isBestSeller,
    bool? available,
    DateTime? createdAt,
  }) {
    return Product(
      id: id ?? this.id,
      businessId: businessId ?? this.businessId,
      name: name ?? this.name,
      price: price ?? this.price,
      category: category ?? this.category,
      description: description ?? this.description,
      imageUrl: imageUrl ?? this.imageUrl,
      isBestSeller: isBestSeller ?? this.isBestSeller,
      available: available ?? this.available,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

