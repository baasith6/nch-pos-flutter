class ShopSettings {
  final String shopName;
  final String? address;
  final String? phone;
  final String? email;
  final String currency;
  final String? receiptFooter;
  final bool taxEnabled;
  final double taxPercentage;

  const ShopSettings({
    required this.shopName,
    this.address,
    this.phone,
    this.email,
    required this.currency,
    this.receiptFooter,
    required this.taxEnabled,
    required this.taxPercentage,
  });

  factory ShopSettings.fromJson(Map<String, dynamic> json) => ShopSettings(
        shopName: json['shop_name'] as String? ?? 'My Shop',
        address: json['address'] as String?,
        phone: json['phone'] as String?,
        email: json['email'] as String?,
        currency: json['currency'] as String? ?? 'LKR',
        receiptFooter: json['receipt_footer'] as String?,
        taxEnabled: json['tax_enabled'] as bool? ?? false,
        taxPercentage: (json['tax_percentage'] as num?)?.toDouble() ?? 0,
      );

  /// Returns the tax amount for a given subtotal
  double taxAmountFor(double subtotal) {
    if (!taxEnabled || taxPercentage <= 0) return 0;
    return subtotal * taxPercentage / 100;
  }

  static ShopSettings get defaults => const ShopSettings(
        shopName: 'My Shop',
        currency: 'LKR',
        taxEnabled: false,
        taxPercentage: 0,
      );
}
