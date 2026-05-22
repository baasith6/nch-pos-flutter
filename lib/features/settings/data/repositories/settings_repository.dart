import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/services/supabase_service.dart';
import '../models/shop_settings_model.dart';

class SettingsRepository {
  final SupabaseClient _client;

  SettingsRepository(this._client);

  Future<Map<String, dynamic>?> getSettings() async {
    final data = await _client
        .from('shop_settings')
        .select()
        .limit(1)
        .maybeSingle();
    return data;
  }

  /// Returns a typed [ShopSettings] object. Falls back to defaults if none saved.
  Future<ShopSettings> getShopSettings() async {
    final data = await getSettings();
    if (data == null) return ShopSettings.defaults;
    return ShopSettings.fromJson(data);
  }

  Future<void> updateSettings(Map<String, dynamic> updates) async {
    final existing = await getSettings();
    if (existing == null) {
      await _client.from('shop_settings').insert({
        ...updates,
        'updated_at': DateTime.now().toIso8601String(),
      });
    } else {
      await _client.from('shop_settings').update({
        ...updates,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', existing['id'] as String);
    }
  }
}

final settingsRepositoryProvider = Provider<SettingsRepository>((ref) {
  return SettingsRepository(SupabaseService.client);
});

/// Provides typed ShopSettings, refreshed when settings are saved.
final shopSettingsProvider = FutureProvider<ShopSettings>((ref) {
  return ref.read(settingsRepositoryProvider).getShopSettings();
});
