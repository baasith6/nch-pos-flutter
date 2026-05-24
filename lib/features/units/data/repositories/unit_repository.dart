import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/services/supabase_service.dart';
import '../models/unit_model.dart';

class UnitRepository {
  final SupabaseClient _client;

  UnitRepository(this._client);

  Future<List<UnitModel>> getActive() async {
    final data = await _client
        .from('units')
        .select('*')
        .order('name');
    return (data as List)
        .map((e) => UnitModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}

final unitRepositoryProvider = Provider<UnitRepository>((ref) {
  return UnitRepository(SupabaseService.client);
});
