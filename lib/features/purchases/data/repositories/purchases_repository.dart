import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/services/supabase_service.dart';
import '../models/purchase_order_model.dart';
import '../models/grn_model.dart';

class PurchasesRepository {
  final SupabaseClient _client;

  PurchasesRepository(this._client);

  Future<List<PurchaseOrderModel>> getAllPurchaseOrders() async {
    final data = await _client
        .from('purchase_orders')
        .select('*, suppliers(name), purchase_order_items(*, products(name), product_units(units(name)))')
        .order('created_at', ascending: false);
    return (data as List)
        .map((e) => PurchaseOrderModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<PurchaseOrderModel> getPurchaseOrderById(String id) async {
    final data = await _client
        .from('purchase_orders')
        .select('*, suppliers(name), purchase_order_items(*, products(name), product_units(units(name)))')
        .eq('id', id)
        .single();
    return PurchaseOrderModel.fromJson(data);
  }

  Future<List<GrnModel>> getGrnsForPo(String poId) async {
    final data = await _client
        .from('goods_received_notes')
        .select('*, purchase_orders(po_no), goods_received_note_items(*, products(name), product_units(units(name)))')
        .eq('purchase_order_id', poId)
        .order('received_at', ascending: false);
    return (data as List)
        .map((e) => GrnModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<Map<String, dynamic>> receiveGrn(String grnId) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw Exception('Must be logged in to receive GRN');

    try {
      final result = await _client.rpc('receive_grn', params: {
        'p_grn_id': grnId,
        'p_user_id': userId,
      });
      return result as Map<String, dynamic>;
    } on PostgrestException catch (e) {
      throw SupabaseService.mapError(e);
    }
  }

  Future<void> createPurchaseOrder({
    required String supplierId,
    required String poNo,
    required double subtotal,
    required double tax,
    required double grandTotal,
    required List<Map<String, dynamic>> items,
  }) async {
    try {
      final po = await _client.from('purchase_orders').insert({
        'supplier_id': supplierId,
        'po_no': poNo,
        'po_status': 'Draft',
        'receiving_status': 'Pending',
        'subtotal': subtotal,
        'tax': tax,
        'grand_total': grandTotal,
      }).select('id').single();

      final poId = po['id'] as String;

      final itemsToInsert = items.map((i) => {
        ...i,
        'purchase_order_id': poId,
      }).toList();

      await _client.from('purchase_order_items').insert(itemsToInsert);
    } on PostgrestException catch (e) {
      throw SupabaseService.mapError(e);
    }
  }

  Future<void> createGrnAndReceive({
    required String poId,
    required String grnNo,
    required String supplierReference,
    required List<Map<String, dynamic>> items,
  }) async {
    try {
      final grn = await _client.from('goods_received_notes').insert({
        'purchase_order_id': poId,
        'grn_no': grnNo,
        'supplier_reference': supplierReference,
        'status': 'Pending', // Will be updated by RPC
      }).select('id').single();

      final grnId = grn['id'] as String;

      final itemsToInsert = items.map((i) => {
        ...i,
        'goods_received_note_id': grnId,
      }).toList();

      await _client.from('goods_received_note_items').insert(itemsToInsert);

      // Now invoke RPC
      await receiveGrn(grnId);
      
    } on PostgrestException catch (e) {
      throw SupabaseService.mapError(e);
    }
  }
}

final purchasesRepositoryProvider = Provider<PurchasesRepository>((ref) {
  return PurchasesRepository(SupabaseService.client);
});
