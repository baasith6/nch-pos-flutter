import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/services/supabase_service.dart';

class PaymentMethodRepository {
  final SupabaseClient _client;

  PaymentMethodRepository(this._client);

  Future<List<String>> getActivePaymentMethods() async {
    try {
      final data = await _client
          .from('payment_methods')
          .select('name')
          .eq('status', 'Active')
          .order('name');
      return (data as List)
          .map((e) => e['name'] as String)
          .toList();
    } catch (_) {
      return ['Cash', 'Card', 'Bank Transfer'];
    }
  }

  Future<List<Map<String, dynamic>>> getAllPaymentMethodsWithStatus() async {
    try {
      final data = await _client
          .from('payment_methods')
          .select('name, status')
          .order('name');
      return List<Map<String, dynamic>>.from(data as List);
    } catch (_) {
      return [
        {'name': 'Cash', 'status': 'Active'},
        {'name': 'Card', 'status': 'Active'},
        {'name': 'Bank Transfer', 'status': 'Active'},
      ];
    }
  }

  Future<void> addPaymentMethod(String name) async {
    await _client.from('payment_methods').insert({
      'name': name,
      'status': 'Active',
    });
  }

  Future<void> setStatus(String name, String status) async {
    await _client
        .from('payment_methods')
        .update({'status': status})
        .eq('name', name);
  }
}

final paymentMethodRepositoryProvider =
    Provider<PaymentMethodRepository>((ref) {
  return PaymentMethodRepository(SupabaseService.client);
});

/// All active payment method names — falls back to defaults if DB unreachable.
final paymentMethodsProvider = FutureProvider<List<String>>((ref) {
  return ref.read(paymentMethodRepositoryProvider).getActivePaymentMethods();
});
