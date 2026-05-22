import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/services/supabase_service.dart';
import '../models/supplier_model.dart';

class SupplierRepository {
  final SupabaseClient _client;

  SupplierRepository(this._client);

  Future<List<SupplierModel>> getActive() async {
    final data = await _client
        .from('suppliers')
        .select('*')
        .eq('status', 'Active')
        .order('name');
    return (data as List)
        .map((e) => SupplierModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<SupplierModel>> getAll() async {
    final data = await _client
        .from('suppliers')
        .select('*')
        .order('name');
    return (data as List)
        .map((e) => SupplierModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> create(SupplierModel supplier) async {
    await _client.from('suppliers').insert(supplier.toInsertJson());
  }

  Future<void> update(SupplierModel supplier) async {
    await _client
        .from('suppliers')
        .update(supplier.toInsertJson())
        .eq('id', supplier.id);
  }
}

final supplierRepositoryProvider = Provider<SupplierRepository>((ref) {
  return SupplierRepository(SupabaseService.client);
});
