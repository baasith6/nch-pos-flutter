import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/services/supabase_service.dart';
import '../models/product_model.dart';

class ProductRepository {
  final SupabaseClient _client;

  ProductRepository(this._client);

  Future<List<ProductModel>> getAllForAdmin() async {
    final data = await _client
        .from('products')
        .select('*, categories(name)')
        .order('name');
    return (data as List)
        .map((e) => ProductModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<ProductModel>> getAllForStaff() async {
    final data = await _client
        .from('product_public_view')
        .select('*, categories(name)')
        .eq('status', 'Active')
        .order('name');
    return (data as List)
        .map((e) => ProductModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<ProductModel>> searchProducts(String query,
      {bool isAdmin = false}) async {
    final table = isAdmin ? 'products' : 'product_public_view';
    final data = await _client
        .from(table)
        .select('*, categories(name)')
        .or('name.ilike.%$query%,barcode.eq.$query')
        .eq('status', 'Active')
        .limit(20);
    return (data as List)
        .map((e) => ProductModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<ProductModel> getById(String id) async {
    final data = await _client
        .from('products')
        .select('*, categories(name)')
        .eq('id', id)
        .single();
    return ProductModel.fromJson(data);
  }

  Future<ProductModel> create(ProductModel product) async {
    final data = await _client
        .from('products')
        .insert(product.toInsertJson())
        .select('*, categories(name)')
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
        .select('*, categories(name)')
        .order('stock_quantity');
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
}

final productRepositoryProvider = Provider<ProductRepository>((ref) {
  return ProductRepository(SupabaseService.client);
});
