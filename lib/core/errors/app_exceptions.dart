/// Represents a typed application error.
class AppException implements Exception {
  final String message;
  final String? code;

  const AppException(this.message, {this.code});

  @override
  String toString() => 'AppException: $message (code: $code)';
}

/// Auth-specific errors.
class AppAuthException extends AppException {
  const AppAuthException(super.message, {super.code});
}

/// Network-specific errors.
class NetworkException extends AppException {
  const NetworkException(super.message, {super.code});
}

/// Insufficient stock error during checkout.
class InsufficientStockException extends AppException {
  final String productName;
  const InsufficientStockException(this.productName)
      : super('Insufficient stock for $productName');
}

/// Permission denied — used when RLS blocks an action.
class PermissionException extends AppException {
  const PermissionException(super.message, {super.code});
}
