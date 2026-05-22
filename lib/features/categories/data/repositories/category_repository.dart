import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/services/supabase_service.dart';
import '../models/category_model.dart';

class CategoryRepository {
  final SupabaseClient _client;

  CategoryRepository(this._client);

  Future<List<CategoryModel>> getAll() async {
    final data = await _client
        .from('categories')
        .select()
        .order('name');
    return (data as List)
        .map((e) => CategoryModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<CategoryModel>> getActive() async {
    final data = await _client
        .from('categories')
        .select()
        .eq('status', 'Active')
        .order('name');
    return (data as List)
        .map((e) => CategoryModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<CategoryModel> create({required String name}) async {
    final data = await _client
        .from('categories')
        .insert({'name': name, 'status': 'Active'})
        .select()
        .single();
    return CategoryModel.fromJson(data);
  }

  Future<void> update({
    required String id,
    String? name,
    String? status,
  }) async {
    await _client.from('categories').update({
      if (name != null) 'name': name,
      if (status != null) 'status': status,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', id);
  }

  Future<void> delete(String id) async {
    await _client.from('categories').delete().eq('id', id);
  }
}

final categoryRepositoryProvider = Provider<CategoryRepository>((ref) {
  return CategoryRepository(SupabaseService.client);
});
