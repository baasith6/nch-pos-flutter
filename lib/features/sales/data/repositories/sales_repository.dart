import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/services/supabase_service.dart';
import '../models/sale_model.dart';

class SalesRepository {
  final SupabaseClient _client;
  final _uuid = const Uuid();

  SalesRepository(this._client);

  Future<Map<String, dynamic>> createSale({
    String? saleId,
    String? customerId,
    required List<CartItem> items,
    required List<CheckoutPayment> payments,
    required double subtotal,
    double discount = 0,
    double taxAmount = 0,
    required double grandTotal,
    bool syncedFromOffline = false,
  }) async {
    final finalSaleId = saleId ?? _uuid.v4();
    final userId = _client.auth.currentUser?.id;

    if (userId == null) {
      throw Exception('User must be logged in to create a sale.');
    }

    try {
      final result = await _client.rpc('create_sale', params: {
        'p_sale_id': finalSaleId,
        'p_customer_id': customerId,
        'p_items': items.map((e) => e.toRpcJson()).toList(),
        'p_payments': payments.map((e) => e.toRpcJson()).toList(),
        'p_subtotal': subtotal,
        'p_discount': discount,
        'p_tax_amount': taxAmount,
        'p_grand_total': grandTotal,
        'p_synced_from_offline': syncedFromOffline,
        'p_user_id': userId,
      });
      return result as Map<String, dynamic>;
    } on PostgrestException catch (e) {
      throw SupabaseService.mapError(e);
    }
  }

  Future<void> cancelSale(String saleId) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      throw Exception('User must be logged in to cancel a sale.');
    }
    try {
      await _client.rpc('cancel_sale', params: {
        'p_sale_id': saleId,
        'p_user_id': userId,
      });
    } on PostgrestException catch (e) {
      throw SupabaseService.mapError(e);
    }
  }

  Future<List<SaleModel>> getAllSales({DateTime? from, DateTime? to}) async {
    var builder = _client
        .from('sales')
        .select('*, profiles(full_name), customers(name), sale_items(*, product_units(units(name))), sale_payments(*, payment_methods(name))');

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
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return [];

    final data = await _client
        .from('sales')
        .select('*, profiles(full_name), customers(name), sale_items(*, product_units(units(name))), sale_payments(*, payment_methods(name))')
        .eq('staff_id', userId)
        .order('created_at', ascending: false);
    return (data as List)
        .map((e) => SaleModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<SaleModel> getSaleById(String id) async {
    final data = await _client
        .from('sales')
        .select('*, profiles(full_name), customers(name), sale_items(*, product_units(units(name))), sale_payments(*, payment_methods(name))')
        .eq('id', id)
        .single();
    return SaleModel.fromJson(data);
  }

  Future<Map<String, dynamic>> getTodaySummary() async {
    final today = DateTime.now();
    final startOfDay = DateTime(today.year, today.month, today.day);
    final data = await _client
        .from('sales')
        .select('grand_total, sale_status')
        .gte('created_at', startOfDay.toIso8601String())
        .eq('sale_status', 'Completed');

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
