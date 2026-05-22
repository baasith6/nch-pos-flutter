class PurchaseOrderItemModel {
  final String id;
  final String purchaseOrderId;
  final String productId;
  final String productUnitId;
  final int orderedQty;
  final int orderedQtyBase;
  final double unitCost;
  final double unitCostBase;
  final double lineTotal;

  // Populated via join
  final String? productName;
  final String? unitName;

  const PurchaseOrderItemModel({
    required this.id,
    required this.purchaseOrderId,
    required this.productId,
    required this.productUnitId,
    required this.orderedQty,
    required this.orderedQtyBase,
    required this.unitCost,
    required this.unitCostBase,
    required this.lineTotal,
    this.productName,
    this.unitName,
  });

  factory PurchaseOrderItemModel.fromJson(Map<String, dynamic> json) => PurchaseOrderItemModel(
        id: json['id'] as String,
        purchaseOrderId: json['purchase_order_id'] as String,
        productId: json['product_id'] as String,
        productUnitId: json['product_unit_id'] as String,
        orderedQty: json['ordered_qty'] as int,
        orderedQtyBase: json['ordered_qty_base'] as int,
        unitCost: (json['unit_cost'] as num).toDouble(),
        unitCostBase: (json['unit_cost_base'] as num).toDouble(),
        lineTotal: (json['line_total'] as num).toDouble(),
        productName: json['products'] != null ? (json['products'] as Map)['name'] as String? : null,
        unitName: json['product_units'] != null && (json['product_units'] as Map)['units'] != null
            ? ((json['product_units'] as Map)['units'] as Map)['name'] as String?
            : null,
      );
}

class PurchaseOrderModel {
  final String id;
  final String supplierId;
  final String poNo;
  final String poStatus;
  final String receivingStatus;
  final double subtotal;
  final double tax;
  final double grandTotal;
  final DateTime createdAt;
  final DateTime updatedAt;

  // Populated via join
  final String? supplierName;
  final List<PurchaseOrderItemModel> items;

  const PurchaseOrderModel({
    required this.id,
    required this.supplierId,
    required this.poNo,
    required this.poStatus,
    required this.receivingStatus,
    required this.subtotal,
    required this.tax,
    required this.grandTotal,
    required this.createdAt,
    required this.updatedAt,
    this.supplierName,
    this.items = const [],
  });

  factory PurchaseOrderModel.fromJson(Map<String, dynamic> json) => PurchaseOrderModel(
        id: json['id'] as String,
        supplierId: json['supplier_id'] as String,
        poNo: json['po_no'] as String,
        poStatus: json['po_status'] as String,
        receivingStatus: json['receiving_status'] as String,
        subtotal: (json['subtotal'] as num).toDouble(),
        tax: (json['tax'] as num).toDouble(),
        grandTotal: (json['grand_total'] as num).toDouble(),
        createdAt: DateTime.parse(json['created_at'] as String),
        updatedAt: DateTime.parse(json['updated_at'] as String),
        supplierName: json['suppliers'] != null ? (json['suppliers'] as Map)['name'] as String? : null,
        items: json['purchase_order_items'] != null
            ? (json['purchase_order_items'] as List)
                .map((e) => PurchaseOrderItemModel.fromJson(e as Map<String, dynamic>))
                .toList()
            : [],
      );
}
