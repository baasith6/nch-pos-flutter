import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../features/auth/data/models/profile_model.dart';
import 'supabase_service.dart';

/// Watches the Supabase auth state and exposes the current [AuthState].
final authStateProvider = StreamProvider<AuthState>((ref) {
  return SupabaseService.client.auth.onAuthStateChange;
});

/// Exposes the current authenticated [User] or null.
final currentUserProvider = Provider<User?>((ref) {
  return SupabaseService.currentUser;
});

/// Fetches and caches the current user's [ProfileModel].
final currentProfileProvider = FutureProvider<ProfileModel?>((ref) async {
  final user = SupabaseService.currentUser;
  if (user == null) return null;

  final data = await SupabaseService.client
      .from('profiles')
      .select()
      .eq('id', user.id)
      .single();

  return ProfileModel.fromJson(data);
});
