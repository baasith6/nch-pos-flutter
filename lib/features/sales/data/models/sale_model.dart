class SaleItemModel {
  final String id;
  final String saleId;
  final String productId;
  final String productName;
  final String? productUnitId;
  final int quantity;
  final int baseQuantityMultiplierSnapshot;
  final int quantityBase;
  final double unitPrice;
  final double discount;
  final double lineTotal;

  // Populated via join
  final String? unitName;

  const SaleItemModel({
    required this.id,
    required this.saleId,
    required this.productId,
    required this.productName,
    this.productUnitId,
    required this.quantity,
    required this.baseQuantityMultiplierSnapshot,
    required this.quantityBase,
    required this.unitPrice,
    required this.discount,
    required this.lineTotal,
    this.unitName,
  });

  factory SaleItemModel.fromJson(Map<String, dynamic> json) => SaleItemModel(
        id: json['id'] as String,
        saleId: json['sale_id'] as String,
        productId: json['product_id'] as String,
        productName: json['product_name'] as String,
        productUnitId: json['product_unit_id'] as String?,
        quantity: json['quantity'] as int,
        baseQuantityMultiplierSnapshot: json['base_quantity_multiplier_snapshot'] as int,
        quantityBase: json['quantity_base'] as int,
        unitPrice: (json['unit_price'] as num).toDouble(),
        discount: (json['discount'] as num).toDouble(),
        lineTotal: (json['line_total'] as num).toDouble(),
        unitName: json['product_units'] != null && (json['product_units'] as Map)['units'] != null
            ? ((json['product_units'] as Map)['units'] as Map)['name'] as String?
            : null,
      );
}

class SalePaymentModel {
  final String id;
  final String saleId;
  final String paymentMethodId;
  final double amount;
  final DateTime createdAt;

  // Populated via join
  final String? paymentMethodName;

  const SalePaymentModel({
    required this.id,
    required this.saleId,
    required this.paymentMethodId,
    required this.amount,
    required this.createdAt,
    this.paymentMethodName,
  });

  factory SalePaymentModel.fromJson(Map<String, dynamic> json) => SalePaymentModel(
        id: json['id'] as String,
        saleId: json['sale_id'] as String,
        paymentMethodId: json['payment_method_id'] as String,
        amount: (json['amount'] as num).toDouble(),
        createdAt: DateTime.parse(json['created_at'] as String),
        paymentMethodName: json['payment_methods'] != null
            ? (json['payment_methods'] as Map<String, dynamic>)['name'] as String?
            : null,
      );
}

class SaleModel {
  final String id;
  final String invoiceNo;
  final String staffId;
  final String? customerId;
  final double subtotal;
  final double discount;
  final double taxAmount;
  final double grandTotal;
  final double amountPaid;
  final double balanceDue;
  final String paymentStatus;
  final String saleStatus;
  final bool stockConflict;
  final String? conflictReason;
  final bool syncedFromOffline;
  final DateTime createdAt;
  final DateTime updatedAt;

  // Populated via join
  final String? staffName;
  final String? customerName;
  final List<SaleItemModel> items;
  final List<SalePaymentModel> payments;

  const SaleModel({
    required this.id,
    required this.invoiceNo,
    required this.staffId,
    this.customerId,
    required this.subtotal,
    required this.discount,
    this.taxAmount = 0,
    required this.grandTotal,
    required this.amountPaid,
    required this.balanceDue,
    required this.paymentStatus,
    required this.saleStatus,
    required this.stockConflict,
    this.conflictReason,
    required this.syncedFromOffline,
    required this.createdAt,
    required this.updatedAt,
    this.staffName,
    this.customerName,
    this.items = const [],
    this.payments = const [],
  });

  factory SaleModel.fromJson(Map<String, dynamic> json) => SaleModel(
        id: json['id'] as String,
        invoiceNo: json['invoice_no'] as String,
        staffId: json['staff_id'] as String,
        customerId: json['customer_id'] as String?,
        subtotal: (json['subtotal'] as num).toDouble(),
        discount: (json['discount'] as num).toDouble(),
        taxAmount: (json['tax_amount'] as num?)?.toDouble() ?? 0,
        grandTotal: (json['grand_total'] as num).toDouble(),
        amountPaid: (json['amount_paid'] as num).toDouble(),
        balanceDue: (json['balance_due'] as num).toDouble(),
        paymentStatus: json['payment_status'] as String,
        saleStatus: json['sale_status'] as String,
        stockConflict: json['stock_conflict'] as bool,
        conflictReason: json['conflict_reason'] as String?,
        syncedFromOffline: json['synced_from_offline'] as bool,
        createdAt: DateTime.parse(json['created_at'] as String),
        updatedAt: DateTime.parse(json['updated_at'] as String),
        staffName: json['profiles'] != null
            ? (json['profiles'] as Map<String, dynamic>)['full_name'] as String?
            : null,
        customerName: json['customers'] != null
            ? (json['customers'] as Map<String, dynamic>)['name'] as String?
            : null,
        items: json['sale_items'] != null
            ? (json['sale_items'] as List)
                .map((e) => SaleItemModel.fromJson(e as Map<String, dynamic>))
                .toList()
            : [],
        payments: json['sale_payments'] != null
            ? (json['sale_payments'] as List)
                .map((e) => SalePaymentModel.fromJson(e as Map<String, dynamic>))
                .toList()
            : [],
      );
}

/// Cart item — only exists locally before checkout
class CartItem {
  final String productId;
  final String productName;
  final String? productUnitId;
  final String unitName;
  final double unitPrice;
  int quantity;
  double discount;

  CartItem({
    required this.productId,
    required this.productName,
    this.productUnitId,
    required this.unitName,
    required this.unitPrice,
    this.quantity = 1,
    this.discount = 0,
  });

  double get lineTotal => (unitPrice * quantity) - discount;

  Map<String, dynamic> toRpcJson() => {
        'product_id': productId,
        'product_unit_id': productUnitId,
        'quantity': quantity,
        'unit_price': unitPrice,
        'discount': discount,
        'line_total': lineTotal,
      };
}

/// Helper model for checkout payments
class CheckoutPayment {
  String paymentMethodId;
  String paymentMethodName;
  double amount;

  CheckoutPayment({
    required this.paymentMethodId,
    required this.paymentMethodName,
    required this.amount,
  });

  Map<String, dynamic> toRpcJson() => {
        'payment_method_id': paymentMethodId,
        'amount': amount,
      };
}
