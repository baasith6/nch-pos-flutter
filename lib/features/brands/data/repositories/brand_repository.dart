import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/services/supabase_service.dart';
import '../models/brand_model.dart';

class BrandRepository {
  final SupabaseClient _client;

  BrandRepository(this._client);

  Future<List<BrandModel>> getActive() async {
    final data = await _client
        .from('brands')
        .select('*')
        .eq('is_active', true)
        .order('name');
    return (data as List)
        .map((e) => BrandModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}

final brandRepositoryProvider = Provider<BrandRepository>((ref) {
  return BrandRepository(SupabaseService.client);
});
