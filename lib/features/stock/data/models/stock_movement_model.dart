class StockMovementModel {
  final String id;
  final String productId;
  final String movementType; // 'Sale', 'GRN', 'Return', 'Adjustment', 'Opening'
  final String referenceType;
  final String? referenceId;
  final int qtyChangeBase;
  final int stockBeforeBase;
  final int stockAfterBase;
  final double costPriceSnapshot;
  final DateTime createdAt;

  // Populated via join
  final String? productName;
  final String? createdByName;

  const StockMovementModel({
    required this.id,
    required this.productId,
    required this.movementType,
    required this.referenceType,
    this.referenceId,
    required this.qtyChangeBase,
    required this.stockBeforeBase,
    required this.stockAfterBase,
    required this.costPriceSnapshot,
    required this.createdAt,
    this.productName,
    this.createdByName,
  });

  factory StockMovementModel.fromJson(Map<String, dynamic> json) => StockMovementModel(
        id: json['id'] as String,
        productId: json['product_id'] as String,
        movementType: json['movement_type'] as String,
        referenceType: json['reference_type'] as String,
        referenceId: json['reference_id'] as String?,
        qtyChangeBase: json['qty_change_base'] as int,
        stockBeforeBase: json['stock_before_base'] as int,
        stockAfterBase: json['stock_after_base'] as int,
        costPriceSnapshot: (json['cost_price_snapshot'] as num).toDouble(),
        createdAt: DateTime.parse(json['created_at'] as String),
        productName: json['products'] != null ? (json['products'] as Map)['name'] as String? : null,
        createdByName: json['profiles'] != null ? (json['profiles'] as Map)['full_name'] as String? : null,
      );
}
