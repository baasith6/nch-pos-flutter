import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/services/supabase_service.dart';
import '../models/customer_model.dart';

class CustomerRepository {
  final SupabaseClient _client;

  CustomerRepository(this._client);

  Future<List<CustomerModel>> getActive() async {
    final data = await _client
        .from('customers')
        .select('*')
        .order('name');
    return (data as List)
        .map((e) => CustomerModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<CustomerModel>> getAll() async {
    final data = await _client
        .from('customers')
        .select('*')
        .order('name');
    return (data as List)
        .map((e) => CustomerModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> create(CustomerModel customer) async {
    await _client.from('customers').insert(customer.toInsertJson());
  }

  Future<void> update(CustomerModel customer) async {
    await _client
        .from('customers')
        .update(customer.toInsertJson())
        .eq('id', customer.id);
  }
}

final customerRepositoryProvider = Provider<CustomerRepository>((ref) {
  return CustomerRepository(SupabaseService.client);
});
