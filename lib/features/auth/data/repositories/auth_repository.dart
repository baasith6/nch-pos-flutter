import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/errors/app_exceptions.dart';
import '../../../../core/services/supabase_service.dart';
import '../models/profile_model.dart';

class AuthRepository {
  final SupabaseClient _client;

  AuthRepository(this._client);

  Future<ProfileModel> signIn({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _client.auth.signInWithPassword(
        email: email,
        password: password,
      );

      if (response.user == null) {
        throw const AppAuthException('Login failed. Please try again.');
      }

      final profileData = await _client
          .from('profiles')
          .select()
          .eq('id', response.user!.id)
          .single();

      final profile = ProfileModel.fromJson(profileData);

      if (!profile.isActive) {
        await _client.auth.signOut();
        throw const AppAuthException(
            'Your account has been deactivated. Contact Admin.');
      }

      return profile;
    } on AppAuthException {
      rethrow;
    } on AuthException catch (e) {
      throw AppAuthException(e.message);
    } on PostgrestException catch (e) {
      throw AppException('Failed to load profile: ${e.message}');
    } catch (e) {
      throw AppAuthException(e.toString());
    }
  }

  Future<void> signOut() async {
    await _client.auth.signOut();
  }

  Future<ProfileModel?> getCurrentProfile() async {
    final user = _client.auth.currentUser;
    if (user == null) return null;

    try {
      final data = await _client
          .from('profiles')
          .select()
          .eq('id', user.id)
          .single();
      return ProfileModel.fromJson(data);
    } catch (_) {
      return null;
    }
  }

  Future<void> updateProfile({
    required String userId,
    String? fullName,
    String? phone,
    String? username,
  }) async {
    await _client.from('profiles').update({
      'updated_at': DateTime.now().toIso8601String(),
      if (fullName != null) 'full_name': fullName,
      if (phone != null) 'phone': phone,
      if (username != null) 'username': username,
    }).eq('id', userId);
  }

  Future<void> changePassword(String newPassword) async {
    await _client.auth.updateUser(UserAttributes(password: newPassword));
  }
}

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(SupabaseService.client);
});
