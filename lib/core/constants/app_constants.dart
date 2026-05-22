class AppConstants {
  AppConstants._();

  static const String appName = 'NCH POS';
  static const String currency = 'LKR';

  // Roles
  static const String roleAdmin = 'Admin';
  static const String roleStaff = 'Staff';

  // User status
  static const String statusActive = 'Active';
  static const String statusInactive = 'Inactive';

  // Product/Category status
  static const String statusActiveProduct = 'Active';
  static const String statusInactiveProduct = 'Inactive';

  // Sale status
  static const String saleCompleted = 'Completed';
  static const String saleCancelled = 'Cancelled';
  static const String saleRefunded = 'Refunded';

  // Payment methods
  static const String paymentCash = 'Cash';
  static const String paymentCard = 'Card';
  static const String paymentTransfer = 'Bank Transfer';

  // Storage buckets
  static const String bucketProductImages = 'product-images';

  // Edge function names
  static const String fnCreateStaffUser = 'create-staff-user';

  // RPC function names
  static const String rpcCreateSale = 'create_sale';
}
