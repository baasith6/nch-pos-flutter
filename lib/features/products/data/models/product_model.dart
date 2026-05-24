class ProductModel {
  final String id;
  final String sku;
  final String? categoryId;
  final String? brandId;
  final String? baseUnitId;
  final String name;
  final String? barcode;
  final double sellingPriceBase;
  final double? costPrice; // null for Staff — never sent from product_public_view
  final int baseStockQuantity;
  final int reorderLevelBase;
  final Map<String, dynamic> attributes;
  final String? imageUrl;
  final String status;
  final DateTime createdAt;
  final DateTime updatedAt;

  // Populated via join
  final String? categoryName;
  final String? brandName;
  final String? baseUnitName;

  const ProductModel({
    required this.id,
    required this.sku,
    this.categoryId,
    this.brandId,
    this.baseUnitId,
    required this.name,
    this.barcode,
    required this.sellingPriceBase,
    this.costPrice,
    required this.baseStockQuantity,
    required this.reorderLevelBase,
    this.attributes = const {},
    this.imageUrl,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.categoryName,
    this.brandName,
    this.baseUnitName,
  });

  bool get isActive => status == 'Active';
  bool get isLowStock => baseStockQuantity <= reorderLevelBase;
  bool get isOutOfStock => baseStockQuantity <= 0;

  factory ProductModel.fromJson(Map<String, dynamic> json) => ProductModel(
        id: json['id'] as String? ?? '',
        sku: json['sku'] as String? ?? '',
        categoryId: json['category_id'] as String?,
        brandId: json['brand_id'] as String?,
        baseUnitId: json['base_unit_id'] as String?,
        name: json['name'] as String? ?? 'Unknown',
        barcode: json['barcode'] as String?,
        sellingPriceBase: (json['selling_price_base'] as num?)?.toDouble() ?? 0.0,
        costPrice: json['cost_price'] != null
            ? (json['cost_price'] as num).toDouble()
            : null,
        baseStockQuantity: json['base_stock_quantity'] as int? ?? 0,
        reorderLevelBase: json['reorder_level_base'] as int? ?? 0,
        attributes: json['attributes'] != null 
            ? Map<String, dynamic>.from(json['attributes'] as Map)
            : const {},
        imageUrl: json['image_url'] as String?,
        status: json['status'] as String? ?? 'Active',
        createdAt: json['created_at'] != null ? DateTime.parse(json['created_at'].toString()) : DateTime.now(),
        updatedAt: json['updated_at'] != null ? DateTime.parse(json['updated_at'].toString()) : DateTime.now(),
        categoryName: json['categories'] != null
            ? (json['categories'] as Map<String, dynamic>)['name'] as String?
            : null,
        brandName: json['brands'] != null
            ? (json['brands'] as Map<String, dynamic>)['name'] as String?
            : null,
        baseUnitName: json['units'] != null
            ? (json['units'] as Map<String, dynamic>)['name'] as String?
            : null,
      );

  Map<String, dynamic> toInsertJson() => {
        'id': id,
        'sku': sku,
        'category_id': categoryId,
        'brand_id': brandId,
        'base_unit_id': baseUnitId,
        'name': name,
        'barcode': barcode,
        'selling_price_base': sellingPriceBase,
        'selling_price': sellingPriceBase, // Legacy column
        'cost_price': costPrice ?? 0,
        'base_stock_quantity': baseStockQuantity,
        'reorder_level_base': reorderLevelBase,
        'reorder_level': reorderLevelBase, // Legacy column
        'attributes': attributes,
        'image_url': imageUrl,
        'status': status,
      };
}
