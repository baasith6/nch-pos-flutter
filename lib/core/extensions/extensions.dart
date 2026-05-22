import 'package:intl/intl.dart' as intl;
import '../constants/app_constants.dart';

extension CurrencyFormat on num {
  String toCurrency() {
    final formatter = intl.NumberFormat.currency(
      symbol: '${AppConstants.currency} ',
      decimalDigits: 2,
    );
    return formatter.format(this);
  }

  String toCompactCurrency() {
    final formatter = intl.NumberFormat.compactCurrency(
      symbol: '${AppConstants.currency} ',
      decimalDigits: 0,
    );
    return formatter.format(this);
  }
}

extension DateTimeFormat on DateTime {
  String toDisplayDate() => intl.DateFormat('dd MMM yyyy').format(this);
  String toDisplayDateTime() => intl.DateFormat('dd MMM yyyy, hh:mm a').format(this);
  String toInvoiceDate() => intl.DateFormat('yyyyMMdd').format(this);
  String toTimeOnly() => intl.DateFormat('hh:mm a').format(this);
}

extension StringExtension on String {
  String capitalize() =>
      isEmpty ? this : '${this[0].toUpperCase()}${substring(1).toLowerCase()}';

  bool get isValidEmail =>
      RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$')
          .hasMatch(this);

  bool get isValidPhone => RegExp(r'^\+?[\d\s-]{7,15}$').hasMatch(this);
}
