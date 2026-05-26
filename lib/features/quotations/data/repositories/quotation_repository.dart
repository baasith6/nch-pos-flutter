import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/services/supabase_service.dart';

class QuotationRepository {
  final SupabaseClient _client;

  QuotationRepository(this._client);

  Future<List<Map<String, dynamic>>> getQuotations() async {
    final data = await _client
        .from('quotations')
        .select('*, customers(name)')
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(data as List);
  }

  Future<int> getPendingQuotationsCount() async {
    final res = await _client
        .from('quotations')
        .select('id')
        .eq('status', 'Pending')
        .count(CountOption.exact);
    return res.count;
  }

  Future<Map<String, dynamic>> getQuotationDetails(String id) async {
    final data = await _client
        .from('quotations')
        .select('*, customers(name), quotation_items(*, products(name), product_units(name))')
        .eq('id', id)
        .single();
    return data as Map<String, dynamic>;
  }

  Future<void> createQuotation({
    String? customerId,
    required double subtotal,
    required double discount,
    required double taxAmount,
    required double grandTotal,
    required List<Map<String, dynamic>> items,
  }) async {
    final userId = _client.auth.currentUser!.id;

    // Use RPC if we need idempotency and invoice_no generation.
    // Wait, we don't have an RPC for quotations. I will generate one in the migration.
    // For now, I'll write the RPC call, and then I'll add the RPC to the migration file!
    await _client.rpc('create_quotation', params: {
      'p_customer_id': customerId,
      'p_subtotal': subtotal,
      'p_discount': discount,
      'p_tax_amount': taxAmount,
      'p_grand_total': grandTotal,
      'p_items': items,
      'p_user_id': userId,
    });
  }

  Future<void> updateQuotationStatus(String id, String status) async {
    await _client.from('quotations').update({'status': status}).eq('id', id);
  }
}

final quotationRepositoryProvider = Provider<QuotationRepository>((ref) {
  return QuotationRepository(SupabaseService.client);
});
