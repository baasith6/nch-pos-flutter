class ProductModel {
  final String id;
  final String? categoryId;
  final String name;
  final String? barcode;
  final double sellingPrice;
  final double? costPrice; // null for Staff — never sent from product_public_view
  final int stockQuantity;
  final int reorderLevel;
  final String? imageUrl;
  final String status;
  final DateTime createdAt;
  final DateTime updatedAt;

  // Populated via join
  final String? categoryName;

  const ProductModel({
    required this.id,
    this.categoryId,
    required this.name,
    this.barcode,
    required this.sellingPrice,
    this.costPrice,
    required this.stockQuantity,
    required this.reorderLevel,
    this.imageUrl,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.categoryName,
  });

  bool get isActive => status == 'Active';
  bool get isLowStock => stockQuantity <= reorderLevel;
  bool get isOutOfStock => stockQuantity <= 0;

  factory ProductModel.fromJson(Map<String, dynamic> json) => ProductModel(
        id: json['id'] as String,
        categoryId: json['category_id'] as String?,
        name: json['name'] as String,
        barcode: json['barcode'] as String?,
        sellingPrice: (json['selling_price'] as num).toDouble(),
        costPrice: json['cost_price'] != null
            ? (json['cost_price'] as num).toDouble()
            : null,
        stockQuantity: json['stock_quantity'] as int,
        reorderLevel: json['reorder_level'] as int,
        imageUrl: json['image_url'] as String?,
        status: json['status'] as String,
        createdAt: DateTime.parse(json['created_at'] as String),
        updatedAt: DateTime.parse(json['updated_at'] as String),
        categoryName: json['categories'] != null
            ? (json['categories'] as Map<String, dynamic>)['name'] as String?
            : null,
      );

  Map<String, dynamic> toInsertJson() => {
        'category_id': categoryId,
        'name': name,
        'barcode': barcode,
        'selling_price': sellingPrice,
        'cost_price': costPrice,
        'stock_quantity': stockQuantity,
        'reorder_level': reorderLevel,
        'image_url': imageUrl,
        'status': status,
      };
}
