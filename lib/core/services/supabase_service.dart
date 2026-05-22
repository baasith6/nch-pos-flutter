import 'package:supabase_flutter/supabase_flutter.dart';
import '../errors/app_exceptions.dart';

/// Central Supabase client accessor.
/// Initialize via Supabase.initialize() in main.dart.
class SupabaseService {
  SupabaseService._();

  static SupabaseClient get client => Supabase.instance.client;

  static User? get currentUser => client.auth.currentUser;

  static Session? get currentSession => client.auth.currentSession;

  static bool get isLoggedIn => currentUser != null;

  /// Maps raw Supabase/Postgres error messages to typed [AppException].
  static AppException mapError(dynamic error) {
    if (error is AuthException) {
      return AppAuthException(error.message, code: error.statusCode);
    }
    if (error is PostgrestException) {
      final msg = error.message;
      if (msg.contains('insufficient_stock')) {
        return const InsufficientStockException('product');
      }
      if (msg.contains('permission denied') || error.code == '42501') {
        return const PermissionException(
            'You do not have permission to perform this action.');
      }
      return AppException(msg, code: error.code);
    }
    return AppException(error.toString());
  }
}
