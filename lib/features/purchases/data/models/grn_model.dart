class GrnItemModel {
  final String id;
  final String grnId;
  final String purchaseOrderItemId;
  final String productId;
  final String productUnitId;
  final int receivedQty;
  final int receivedQtyBase;
  final double unitCost;
  final double unitCostBase;

  // Populated via join
  final String? productName;
  final String? unitName;

  const GrnItemModel({
    required this.id,
    required this.grnId,
    required this.purchaseOrderItemId,
    required this.productId,
    required this.productUnitId,
    required this.receivedQty,
    required this.receivedQtyBase,
    required this.unitCost,
    required this.unitCostBase,
    this.productName,
    this.unitName,
  });

  factory GrnItemModel.fromJson(Map<String, dynamic> json) => GrnItemModel(
        id: json['id'] as String,
        grnId: json['grn_id'] as String,
        purchaseOrderItemId: json['purchase_order_item_id'] as String,
        productId: json['product_id'] as String,
        productUnitId: json['product_unit_id'] as String,
        receivedQty: json['received_qty'] as int,
        receivedQtyBase: json['received_qty_base'] as int,
        unitCost: (json['unit_cost'] as num).toDouble(),
        unitCostBase: (json['unit_cost_base'] as num).toDouble(),
        productName: json['products'] != null ? (json['products'] as Map)['name'] as String? : null,
        unitName: json['product_units'] != null && (json['product_units'] as Map)['units'] != null
            ? ((json['product_units'] as Map)['units'] as Map)['name'] as String?
            : null,
      );
}

class GrnModel {
  final String id;
  final String purchaseOrderId;
  final String grnNo;
  final String status;
  final DateTime receivedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  // Populated via join
  final String? poNo;
  final List<GrnItemModel> items;

  const GrnModel({
    required this.id,
    required this.purchaseOrderId,
    required this.grnNo,
    required this.status,
    required this.receivedAt,
    required this.createdAt,
    required this.updatedAt,
    this.poNo,
    this.items = const [],
  });

  factory GrnModel.fromJson(Map<String, dynamic> json) => GrnModel(
        id: json['id'] as String,
        purchaseOrderId: json['purchase_order_id'] as String,
        grnNo: json['grn_no'] as String,
        status: json['status'] as String,
        receivedAt: DateTime.parse(json['received_at'] as String),
        createdAt: DateTime.parse(json['created_at'] as String),
        updatedAt: DateTime.parse(json['updated_at'] as String),
        poNo: json['purchase_orders'] != null ? (json['purchase_orders'] as Map)['po_no'] as String? : null,
        items: json['goods_received_note_items'] != null
            ? (json['goods_received_note_items'] as List)
                .map((e) => GrnItemModel.fromJson(e as Map<String, dynamic>))
                .toList()
            : [],
      );
}
