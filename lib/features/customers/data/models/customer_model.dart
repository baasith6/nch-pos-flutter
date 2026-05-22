class CustomerModel {
  final String id;
  final String name;
  final String? phone;
  final String? address;
  final double creditLimit;
  final DateTime createdAt;
  final DateTime updatedAt;

  // View fields (if fetching from customer_ledger_view)
  final double? invoiceTotal;
  final double? paymentTotal;
  final double? balance;

  const CustomerModel({
    required this.id,
    required this.name,
    this.phone,
    this.address,
    required this.creditLimit,
    required this.createdAt,
    required this.updatedAt,
    this.invoiceTotal,
    this.paymentTotal,
    this.balance,
  });

  factory CustomerModel.fromJson(Map<String, dynamic> json) => CustomerModel(
        id: json['id'] ?? json['customer_id'] as String,
        name: json['name'] as String,
        phone: json['phone'] as String?,
        address: json['address'] as String?,
        creditLimit: json['credit_limit'] != null ? (json['credit_limit'] as num).toDouble() : 0.0,
        createdAt: json['created_at'] != null ? DateTime.parse(json['created_at'] as String) : DateTime.now(),
        updatedAt: json['updated_at'] != null ? DateTime.parse(json['updated_at'] as String) : DateTime.now(),
        invoiceTotal: json['invoice_total'] != null ? (json['invoice_total'] as num).toDouble() : null,
        paymentTotal: json['payment_total'] != null ? (json['payment_total'] as num).toDouble() : null,
        balance: json['balance'] != null ? (json['balance'] as num).toDouble() : null,
      );

  Map<String, dynamic> toInsertJson() => {
        'name': name,
        'phone': phone,
        'address': address,
        'credit_limit': creditLimit,
      };
}
