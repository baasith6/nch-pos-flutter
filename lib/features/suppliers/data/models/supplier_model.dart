class SupplierModel {
  final String id;
  final String name;
  final String? contactName;
  final String? phone;
  final double creditLimit;
  final DateTime createdAt;
  final DateTime updatedAt;

  // View fields (if fetching from supplier_ledger_view)
  final double? invoiceTotal;
  final double? paymentTotal;
  final double? balance;

  const SupplierModel({
    required this.id,
    required this.name,
    this.contactName,
    this.phone,
    required this.creditLimit,
    required this.createdAt,
    required this.updatedAt,
    this.invoiceTotal,
    this.paymentTotal,
    this.balance,
  });

  factory SupplierModel.fromJson(Map<String, dynamic> json) => SupplierModel(
        id: json['id'] ?? json['supplier_id'] as String,
        name: json['name'] as String,
        contactName: json['contact_name'] as String?,
        phone: json['phone'] as String?,
        creditLimit: json['credit_limit'] != null ? (json['credit_limit'] as num).toDouble() : 0.0,
        createdAt: json['created_at'] != null ? DateTime.parse(json['created_at'] as String) : DateTime.now(),
        updatedAt: json['updated_at'] != null ? DateTime.parse(json['updated_at'] as String) : DateTime.now(),
        invoiceTotal: json['invoice_total'] != null ? (json['invoice_total'] as num).toDouble() : null,
        paymentTotal: json['payment_total'] != null ? (json['payment_total'] as num).toDouble() : null,
        balance: json['balance'] != null ? (json['balance'] as num).toDouble() : null,
      );

  Map<String, dynamic> toInsertJson() => {
        'name': name,
        'contact_name': contactName,
        'phone': phone,
        'credit_limit': creditLimit,
      };
}
