import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/services/supabase_service.dart';

class PaymentRepository {
  final SupabaseClient _client;

  PaymentRepository(this._client);

  Future<void> processCustomerPayment({
    required String customerId,
    required String paymentMethodId,
    required double amount,
    String? note,
  }) async {
    final userId = _client.auth.currentUser!.id;
    await _client.rpc('process_customer_payment', params: {
      'p_customer_id': customerId,
      'p_payment_method_id': paymentMethodId,
      'p_amount': amount,
      'p_note': note,
      'p_user_id': userId,
    });
  }

  Future<void> processSupplierPayment({
    required String supplierId,
    required String paymentMethodId,
    required double amount,
    String? note,
  }) async {
    final userId = _client.auth.currentUser!.id;
    await _client.rpc('process_supplier_payment', params: {
      'p_supplier_id': supplierId,
      'p_payment_method_id': paymentMethodId,
      'p_amount': amount,
      'p_note': note,
      'p_user_id': userId,
    });
  }

  Future<List<Map<String, dynamic>>> getPaymentMethods() async {
    final data = await _client.from('payment_methods').select('id, name').order('name');
    return List<Map<String, dynamic>>.from(data as List);
  }
}

final paymentRepositoryProvider = Provider<PaymentRepository>((ref) {
  return PaymentRepository(SupabaseService.client);
});
