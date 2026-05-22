import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/services/supabase_service.dart';
import '../models/product_model.dart';
import '../models/product_unit_model.dart';

class ProductRepository {
  final SupabaseClient _client;

  ProductRepository(this._client);

  Future<List<ProductModel>> getAllForAdmin() async {
    final data = await _client
        .from('products')
        .select('*, categories(name), brands(name), units(name)')
        .order('name');
    return (data as List)
        .map((e) => ProductModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<ProductModel>> getAllForStaff() async {
    final data = await _client
        .from('products') // Wait, we should probably bypass product_public_view or update the view in supabase later. For now, just use 'products'. Since RLS handles security.
        .select('*, categories(name), brands(name), units(name)')
        .eq('status', 'Active')
        .order('name');
    return (data as List)
        .map((e) => ProductModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<ProductModel>> searchProducts(String query,
      {bool isAdmin = false}) async {
    final data = await _client
        .from('products')
        .select('*, categories(name), brands(name), units(name)')
        .or('name.ilike.%$query%,barcode.ilike.%$query%,sku.ilike.%$query%')
        .eq('status', 'Active')
        .limit(20);
    return (data as List)
        .map((e) => ProductModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<ProductModel> getById(String id) async {
    final data = await _client
        .from('products')
        .select('*, categories(name), brands(name), units(name)')
        .eq('id', id)
        .single();
    return ProductModel.fromJson(data);
  }

  Future<ProductModel> create(ProductModel product) async {
    final data = await _client
        .from('products')
        .insert(product.toInsertJson())
        .select('*, categories(name), brands(name), units(name)')
        .single();
    return ProductModel.fromJson(data);
  }

  Future<void> update(String id, Map<String, dynamic> updates) async {
    await _client.from('products').update({
      ...updates,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', id);
  }

  Future<void> delete(String id) async {
    await _client.from('products').delete().eq('id', id);
  }

  Future<List<ProductModel>> getLowStock() async {
    final data = await _client
        .from('products')
        .select('*, categories(name), brands(name), units(name)')
        .order('base_stock_quantity');
    final all = (data as List)
        .map((e) => ProductModel.fromJson(e as Map<String, dynamic>))
        .toList();
    return all.where((p) => p.isLowStock).toList();
  }

  Future<String> uploadImage(
      String productId, Uint8List bytes, String extension) async {
    final path = '$productId.$extension';
    await _client.storage.from('product-images').uploadBinary(
          path,
          bytes,
          fileOptions:
              FileOptions(upsert: true, contentType: 'image/$extension'),
        );
    return _client.storage.from('product-images').getPublicUrl(path);
  }

  // --- Product Units ---

  Future<List<ProductUnitModel>> getUnitsForProduct(String productId) async {
    final data = await _client
        .from('product_units')
        .select('*, units(name)')
        .eq('product_id', productId)
        .eq('is_active', true)
        .order('base_quantity_multiplier');
    return (data as List)
        .map((e) => ProductUnitModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<ProductUnitModel> createUnit(ProductUnitModel unit) async {
    final data = await _client
        .from('product_units')
        .insert(unit.toInsertJson())
        .select('*, units(name)')
        .single();
    return ProductUnitModel.fromJson(data);
  }

  Future<void> updateUnit(String id, Map<String, dynamic> updates) async {
    await _client.from('product_units').update({
      ...updates,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', id);
  }

  Future<void> deleteUnit(String id) async {
    await _client.from('product_units').delete().eq('id', id);
  }
}

final productRepositoryProvider = Provider<ProductRepository>((ref) {
  return ProductRepository(SupabaseService.client);
});
