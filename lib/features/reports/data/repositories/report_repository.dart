import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/services/supabase_service.dart';

class ReportRepository {
  final SupabaseClient _client;

  ReportRepository(this._client);

  Future<List<Map<String, dynamic>>> getSalesByDateRange({
    required DateTime from,
    required DateTime to,
  }) async {
    final data = await _client
        .from('sales')
        .select('*, profiles(full_name), sale_items(*)')
        .gte('created_at', from.toIso8601String())
        .lte('created_at', to.toIso8601String())
        .eq('sale_status', 'Completed')
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(data as List);
  }

  Future<List<Map<String, dynamic>>> getProductSalesReport({
    DateTime? from,
    DateTime? to,
  }) async {
    final data = await _client
        .from('sale_items')
        .select('product_id, product_name, quantity, line_total, sales(status)');

    final Map<String, Map<String, dynamic>> aggregated = {};
    for (final item in (data as List)) {
      final saleMap = item['sales'];
      if (saleMap == null || saleMap['sale_status'] != 'Completed') continue;
      final id = item['product_id'] as String;
      if (!aggregated.containsKey(id)) {
        aggregated[id] = {
          'product_id': id,
          'product_name': item['product_name'],
          'total_quantity': 0,
          'total_revenue': 0.0,
        };
      }
      aggregated[id]!['total_quantity'] =
          (aggregated[id]!['total_quantity'] as int) + (item['quantity'] as int);
      aggregated[id]!['total_revenue'] =
          (aggregated[id]!['total_revenue'] as double) +
              (item['line_total'] as num).toDouble();
    }
    final result = aggregated.values.toList();
    result.sort((a, b) =>
        (b['total_revenue'] as double).compareTo(a['total_revenue'] as double));
    return result;
  }

  Future<List<Map<String, dynamic>>> getStaffSalesReport({
    DateTime? from,
    DateTime? to,
  }) async {
    final data = await _client
        .from('sales')
        .select('staff_id, grand_total, profiles(full_name)')
        .eq('sale_status', 'Completed');

    final Map<String, Map<String, dynamic>> aggregated = {};
    for (final sale in (data as List)) {
      final id = sale['staff_id'] as String;
      final profileMap = sale['profiles'] as Map<String, dynamic>?;
      final name = profileMap?['full_name'] as String? ?? 'Unknown';
      if (!aggregated.containsKey(id)) {
        aggregated[id] = {
          'staff_id': id,
          'staff_name': name,
          'total_sales': 0,
          'total_revenue': 0.0,
        };
      }
      aggregated[id]!['total_sales'] =
          (aggregated[id]!['total_sales'] as int) + 1;
      aggregated[id]!['total_revenue'] =
          (aggregated[id]!['total_revenue'] as double) +
              (sale['grand_total'] as num).toDouble();
    }
    final result = aggregated.values.toList();
    result.sort((a, b) =>
        (b['total_revenue'] as double).compareTo(a['total_revenue'] as double));
    return result;
  }

  Future<Map<String, dynamic>> getProfitReport({
    DateTime? from,
    DateTime? to,
  }) async {
    final data = await _client
        .from('sale_items')
        .select('quantity, unit_price, line_total, product_id, products(cost_price), sales(sale_status, created_at)');

    double totalRevenue = 0;
    double totalCost = 0;

    for (final item in (data as List)) {
      final saleMap = item['sales'];
      if (saleMap == null || saleMap['sale_status'] != 'Completed') continue;
      final qty = item['quantity'] as int;
      final revenue = (item['line_total'] as num).toDouble();
      final productMap = item['products'] as Map<String, dynamic>?;
      final costPrice = (productMap?['cost_price'] as num?)?.toDouble() ?? 0;
      totalRevenue += revenue;
      totalCost += costPrice * qty;
    }

    return {
      'total_revenue': totalRevenue,
      'total_cost': totalCost,
      'gross_profit': totalRevenue - totalCost,
      'margin_percent': totalRevenue > 0
          ? ((totalRevenue - totalCost) / totalRevenue) * 100
          : 0,
    };
  }

  Future<List<Map<String, dynamic>>> getPaymentMethodReport({
    DateTime? from,
    DateTime? to,
  }) async {
    final data = await _client
        .from('sales')
        .select('payment_method, grand_total')
        .eq('sale_status', 'Completed');

    final Map<String, Map<String, dynamic>> aggregated = {};
    for (final sale in (data as List)) {
      final method = sale['payment_method'] as String? ?? 'Cash'; // Fallback for old schema
      if (!aggregated.containsKey(method)) {
        aggregated[method] = {
          'payment_method': method,
          'count': 0,
          'total': 0.0,
        };
      }
      aggregated[method]!['count'] = (aggregated[method]!['count'] as int) + 1;
      aggregated[method]!['total'] =
          (aggregated[method]!['total'] as double) +
              (sale['grand_total'] as num).toDouble();
    }
    return aggregated.values.toList();
  }

  // --- Phase 4 Reports ---

  Future<Map<String, dynamic>> getStockValuation() async {
    final data = await _client.from('products').select('name, sku, base_stock_quantity, cost_price');
    
    double totalValue = 0;
    final List<Map<String, dynamic>> items = [];
    
    for (final p in (data as List)) {
      final qty = p['base_stock_quantity'] as int;
      final cost = (p['cost_price'] as num?)?.toDouble() ?? 0;
      final value = qty * cost;
      
      totalValue += value;
      items.add({
        'name': p['name'],
        'sku': p['sku'],
        'qty': qty,
        'cost': cost,
        'value': value,
      });
    }
    
    items.sort((a, b) => (b['value'] as double).compareTo(a['value'] as double));
    
    return {
      'total_value': totalValue,
      'items': items,
    };
  }

  Future<List<Map<String, dynamic>>> getCustomerLedger(String customerId) async {
    // For V1, we just fetch all sales for this customer and order by date.
    // We could union with customer_payments for a true running ledger, but 
    // listing the sales and their balances is sufficient for Phase 4.
    final data = await _client
        .from('sales')
        .select('invoice_no, created_at, grand_total, amount_paid, balance_due, payment_status')
        .eq('customer_id', customerId)
        .order('created_at');
        
    return List<Map<String, dynamic>>.from(data as List);
  }

  Future<List<Map<String, dynamic>>> getSupplierLedger(String supplierId) async {
    final data = await _client
        .from('purchase_orders')
        .select('po_number, created_at, grand_total, amount_paid, balance_due, payment_status')
        .eq('supplier_id', supplierId)
        .order('created_at');
        
    return List<Map<String, dynamic>>.from(data as List);
  }
}

final reportRepositoryProvider = Provider<ReportRepository>((ref) {
  return ReportRepository(SupabaseService.client);
});
