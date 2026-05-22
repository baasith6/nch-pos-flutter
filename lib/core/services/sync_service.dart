import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'local_db_service.dart';
import '../../features/sales/data/repositories/sales_repository.dart';
import '../../features/products/data/repositories/product_repository.dart';

class SyncService {
  final SalesRepository _salesRepo;
  final ProductRepository _productRepo;
  final LocalDbService _localDb = LocalDbService();
  bool _isSyncing = false;

  SyncService(this._salesRepo, this._productRepo) {
    _initConnectivityListener();
  }

  void _initConnectivityListener() {
    Connectivity().onConnectivityChanged.listen((List<ConnectivityResult> results) {
      if (results.isNotEmpty && results.first != ConnectivityResult.none) {
        syncOfflineSales();
      }
    });
  }

  // ==========================================
  // Master Data Downsync
  // ==========================================

  Future<void> syncMasterDataDown() async {
    final connectivity = await Connectivity().checkConnectivity();
    if (connectivity.contains(ConnectivityResult.none)) return;

    try {
      // Fetch from Supabase
      final products = await _productRepo.getAllForAdmin(); // Using admin to get all stock
      
      // We would also need to fetch all ProductUnits, but for now we'll fetch them per product 
      // or we can add a getAllProductUnits() to ProductRepository. 
      // This is a simplified downsync.
      
      await _localDb.clearAndInsertProducts(products);
      
      // TODO: Fetch and insert ProductUnits, Brands, Categories, Customers
      debugPrint('Master data downsync complete.');
    } catch (e) {
      debugPrint('Error syncing master data down: \$e');
    }
  }

  // ==========================================
  // Sales Queue Upsync
  // ==========================================

  Future<void> syncOfflineSales() async {
    if (_isSyncing) return;
    
    final connectivity = await Connectivity().checkConnectivity();
    if (connectivity.contains(ConnectivityResult.none)) return;

    _isSyncing = true;
    try {
      final pendingSales = await _localDb.getPendingSales();
      
      for (final saleRecord in pendingSales) {
        final saleId = saleRecord['id'] as String;
        final payloadStr = saleRecord['payload'] as String;
        final payload = jsonDecode(payloadStr) as Map<String, dynamic>;

        try {
          // Push to Supabase via SalesRepository
          // Note: Since we need to call the RPC with all params, we construct it.
          // Wait, createSale takes Dart objects in the Repository. 
          // We can either bypass the repository and call the RPC directly, 
          // or reconstruct the objects.
          
          // Reconstruct CartItems
          final items = (payload['items'] as List).map((i) => CartItem(
            productId: i['product_id'],
            productName: i['product_name'] ?? 'Unknown',
            productUnitId: i['product_unit_id'],
            unitName: i['unit_name'] ?? 'Unit',
            unitPrice: i['unit_price']?.toDouble() ?? 0.0,
            quantity: i['quantity'],
            discount: i['discount']?.toDouble() ?? 0.0,
          )).toList();

          // Reconstruct Payments
          final payments = (payload['payments'] as List).map((p) => CheckoutPayment(
            paymentMethodId: p['payment_method_id'],
            paymentMethodName: 'Offline Payment',
            amount: p['amount']?.toDouble() ?? 0.0,
          )).toList();

          await _salesRepo.createSale(
            saleId: saleId,
            customerId: payload['customer_id'],
            items: items,
            payments: payments,
            subtotal: payload['subtotal']?.toDouble() ?? 0.0,
            discount: payload['discount']?.toDouble() ?? 0.0,
            taxAmount: payload['tax_amount']?.toDouble() ?? 0.0,
            grandTotal: payload['grand_total']?.toDouble() ?? 0.0,
            syncedFromOffline: true, // FLAG SET TO TRUE TO ALLOW NEGATIVE STOCK CONFLICTS
          );

          // Success: Remove from local queue
          await _localDb.deleteFromQueue(saleId);
          debugPrint('Synced sale \$saleId successfully.');
        } catch (e) {
          debugPrint('Failed to sync sale \$saleId: \$e');
          await _localDb.updateQueueStatus(saleId, 'Failed', errorMessage: e.toString());
        }
      }
    } finally {
      _isSyncing = false;
    }
  }
}

final syncServiceProvider = Provider<SyncService>((ref) {
  final salesRepo = ref.watch(salesRepositoryProvider);
  final productRepo = ref.watch(productRepositoryProvider);
  return SyncService(salesRepo, productRepo);
});
