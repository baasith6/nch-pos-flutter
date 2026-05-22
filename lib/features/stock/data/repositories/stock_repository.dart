import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/services/supabase_service.dart';

class StockRepository {
  final SupabaseClient _client;

  StockRepository(this._client);

  Future<List<Map<String, dynamic>>> getAdjustments({String? productId}) async {
    var builder = _client
        .from('stock_adjustments')
        .select('*, products(name), profiles(full_name)');

    if (productId != null) {
      builder = builder.eq('product_id', productId);
    }

    final data = await builder.order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(data as List);
  }

  Future<void> adjustStock({
    required String productId,
    required int oldQuantity,
    required int newQuantity,
    required String reason,
  }) async {
    final user = SupabaseService.currentUser;
    if (user == null) throw Exception('Not authenticated');

    await _client.from('stock_adjustments').insert({
      'product_id': productId,
      'old_quantity': oldQuantity,
      'new_quantity': newQuantity,
      'reason': reason,
      'adjusted_by': user.id,
    });

    await _client.from('products').update({
      'stock_quantity': newQuantity,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', productId);
  }
}

final stockRepositoryProvider = Provider<StockRepository>((ref) {
  return StockRepository(SupabaseService.client);
});
