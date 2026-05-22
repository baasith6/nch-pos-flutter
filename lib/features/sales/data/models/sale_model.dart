class SaleItemModel {
  final String id;
  final String saleId;
  final String productId;
  final String productName;
  final int quantity;
  final double unitPrice;
  final double discount;
  final double lineTotal;

  const SaleItemModel({
    required this.id,
    required this.saleId,
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.unitPrice,
    required this.discount,
    required this.lineTotal,
  });

  factory SaleItemModel.fromJson(Map<String, dynamic> json) => SaleItemModel(
        id: json['id'] as String,
        saleId: json['sale_id'] as String,
        productId: json['product_id'] as String,
        productName: json['product_name'] as String,
        quantity: json['quantity'] as int,
        unitPrice: (json['unit_price'] as num).toDouble(),
        discount: (json['discount'] as num).toDouble(),
        lineTotal: (json['line_total'] as num).toDouble(),
      );
}

class SaleModel {
  final String id;
  final String invoiceNo;
  final String staffId;
  final double subtotal;
  final double discount;
  final double taxAmount;
  final double grandTotal;
  final String paymentMethod;
  final String status;
  final DateTime createdAt;

  // Populated via join
  final String? staffName;
  final List<SaleItemModel> items;

  const SaleModel({
    required this.id,
    required this.invoiceNo,
    required this.staffId,
    required this.subtotal,
    required this.discount,
    this.taxAmount = 0,
    required this.grandTotal,
    required this.paymentMethod,
    required this.status,
    required this.createdAt,
    this.staffName,
    this.items = const [],
  });

  factory SaleModel.fromJson(Map<String, dynamic> json) => SaleModel(
        id: json['id'] as String,
        invoiceNo: json['invoice_no'] as String,
        staffId: json['staff_id'] as String,
        subtotal: (json['subtotal'] as num).toDouble(),
        discount: (json['discount'] as num).toDouble(),
        taxAmount: (json['tax_amount'] as num?)?.toDouble() ?? 0,
        grandTotal: (json['grand_total'] as num).toDouble(),
        paymentMethod: json['payment_method'] as String,
        status: json['status'] as String,
        createdAt: DateTime.parse(json['created_at'] as String),
        staffName: json['profiles'] != null
            ? (json['profiles'] as Map<String, dynamic>)['full_name'] as String?
            : null,
        items: json['sale_items'] != null
            ? (json['sale_items'] as List)
                .map((e) => SaleItemModel.fromJson(e as Map<String, dynamic>))
                .toList()
            : [],
      );
}

/// Cart item — only exists locally before checkout
class CartItem {
  final String productId;
  final String productName;
  final double unitPrice;
  int quantity;
  double discount;

  CartItem({
    required this.productId,
    required this.productName,
    required this.unitPrice,
    this.quantity = 1,
    this.discount = 0,
  });

  double get lineTotal => (unitPrice * quantity) - discount;

  Map<String, dynamic> toRpcJson() => {
        'product_id': productId,
        'quantity': quantity,
        'discount': discount,
      };
}
