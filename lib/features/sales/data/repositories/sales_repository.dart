import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/services/supabase_service.dart';
import '../models/sale_model.dart';

class SalesRepository {
  final SupabaseClient _client;

  SalesRepository(this._client);

  Future<Map<String, dynamic>> createSale({
    required List<CartItem> items,
    required String paymentMethod,
    double billDiscount = 0,
    double taxAmount = 0,
  }) async {
    // Try new function signature (with tax_amount) first
    try {
      final result = await _client.rpc(AppConstants.rpcCreateSale, params: {
        'items': items.map((e) => e.toRpcJson()).toList(),
        'payment_method': paymentMethod,
        'bill_discount': billDiscount,
        'tax_amount': taxAmount,
      });
      return result as Map<String, dynamic>;
    } on PostgrestException catch (e) {
      // PGRST202 = function not found with those params in schema cache
      // → Migration not yet run; fall back to old function signature
      if (e.code == 'PGRST202') {
        try {
          final result = await _client.rpc(AppConstants.rpcCreateSale, params: {
            'items': items.map((e) => e.toRpcJson()).toList(),
            'payment_method': paymentMethod,
            'bill_discount': billDiscount,
          });
          // Inject tax_amount = 0 into result so the receipt screen doesn't crash
          final map = Map<String, dynamic>.from(result as Map<String, dynamic>);
          map['tax_amount'] ??= 0;
          return map;
        } on PostgrestException catch (inner) {
          throw SupabaseService.mapError(inner);
        }
      }
      throw SupabaseService.mapError(e);
    }
  }

  Future<List<SaleModel>> getAllSales({DateTime? from, DateTime? to}) async {
    // Use a string filter approach to avoid type mismatch on builder chain
    var builder = _client
        .from('sales')
        .select('*, profiles(full_name), sale_items(*)');

    if (from != null) {
      builder = builder.gte('created_at', from.toIso8601String());
    }
    if (to != null) {
      builder = builder.lte('created_at', to.toIso8601String());
    }

    final data = await builder.order('created_at', ascending: false);
    return (data as List)
        .map((e) => SaleModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<SaleModel>> getOwnSales() async {
    final data = await _client
        .from('sales')
        .select('*, sale_items(*)')
        .order('created_at', ascending: false);
    return (data as List)
        .map((e) => SaleModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<SaleModel> getSaleById(String id) async {
    final data = await _client
        .from('sales')
        .select('*, profiles(full_name), sale_items(*)')
        .eq('id', id)
        .single();
    return SaleModel.fromJson(data);
  }

  Future<void> updateSaleStatus(String saleId, String status) async {
    await _client
        .from('sales')
        .update({'status': status})
        .eq('id', saleId);
  }

  Future<Map<String, dynamic>> getTodaySummary() async {
    final today = DateTime.now();
    final startOfDay = DateTime(today.year, today.month, today.day);
    final data = await _client
        .from('sales')
        .select('grand_total, payment_method, status')
        .gte('created_at', startOfDay.toIso8601String())
        .eq('status', 'Completed');

    final list = data as List;
    double total = 0;
    for (final s in list) {
      total += (s['grand_total'] as num).toDouble();
    }
    return {'count': list.length, 'total': total};
  }
}

final salesRepositoryProvider = Provider<SalesRepository>((ref) {
  return SalesRepository(SupabaseService.client);
});
