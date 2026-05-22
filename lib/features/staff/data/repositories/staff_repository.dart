import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/services/supabase_service.dart';
import '../../../auth/data/models/profile_model.dart';

class StaffRepository {
  final SupabaseClient _client;

  StaffRepository(this._client);

  Future<List<ProfileModel>> getAllStaff() async {
    final data = await _client
        .from('profiles')
        .select()
        .order('full_name');
    return (data as List)
        .map((e) => ProfileModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> createStaffUser({
    required String email,
    required String password,
    required String fullName,
    String? phone,
    String? username,
  }) async {
    final response = await _client.functions.invoke(
      AppConstants.fnCreateStaffUser,
      body: {
        'email': email,
        'password': password,
        'full_name': fullName,
        'phone': phone,
        'username': username,
        'role': AppConstants.roleStaff,
      },
    );

    if (response.status != 200) {
      final error = response.data?['error'] ?? 'Failed to create staff user';
      throw Exception(error.toString());
    }
  }

  Future<void> updateStatus({
    required String staffId,
    required String status,
  }) async {
    await _client.from('profiles').update({
      'status': status,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', staffId);
  }

  Future<void> updateStaff({
    required String staffId,
    String? fullName,
    String? phone,
    String? username,
  }) async {
    await _client.from('profiles').update({
      if (fullName != null) 'full_name': fullName,
      if (phone != null) 'phone': phone,
      if (username != null) 'username': username,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', staffId);
  }
}

final staffRepositoryProvider = Provider<StaffRepository>((ref) {
  return StaffRepository(SupabaseService.client);
});
