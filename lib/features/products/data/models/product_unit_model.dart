class ProductUnitModel {
  final String id;
  final String productId;
  final String unitId;
  final int baseQuantityMultiplier;
  final String? barcode;
  final double sellingPrice;
  final bool isDefaultSalesUnit;
  final bool isDefaultPurchaseUnit;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  // Populated via join
  final String? unitName;

  const ProductUnitModel({
    required this.id,
    required this.productId,
    required this.unitId,
    required this.baseQuantityMultiplier,
    this.barcode,
    required this.sellingPrice,
    required this.isDefaultSalesUnit,
    required this.isDefaultPurchaseUnit,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
    this.unitName,
  });

  factory ProductUnitModel.fromJson(Map<String, dynamic> json) => ProductUnitModel(
        id: json['id'] as String,
        productId: json['product_id'] as String,
        unitId: json['unit_id'] as String,
        baseQuantityMultiplier: json['base_quantity_multiplier'] as int,
        barcode: json['barcode'] as String?,
        sellingPrice: (json['selling_price'] as num).toDouble(),
        isDefaultSalesUnit: json['is_default_sales_unit'] as bool,
        isDefaultPurchaseUnit: json['is_default_purchase_unit'] as bool,
        isActive: json['is_active'] as bool,
        createdAt: DateTime.parse(json['created_at'] as String),
        updatedAt: DateTime.parse(json['updated_at'] as String),
        unitName: json['units'] != null 
            ? (json['units'] as Map<String, dynamic>)['name'] as String? 
            : null,
      );

  Map<String, dynamic> toInsertJson() => {
        'product_id': productId,
        'unit_id': unitId,
        'base_quantity_multiplier': baseQuantityMultiplier,
        'barcode': barcode,
        'selling_price': sellingPrice,
        'is_default_sales_unit': isDefaultSalesUnit,
        'is_default_purchase_unit': isDefaultPurchaseUnit,
        'is_active': isActive,
      };
}
