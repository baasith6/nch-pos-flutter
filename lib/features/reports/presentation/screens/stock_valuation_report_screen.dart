import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../app/theme.dart';
import '../../../../core/extensions/extensions.dart';
import '../../data/repositories/report_repository.dart';

final _stockValuationProvider = FutureProvider((ref) {
  return ref.read(reportRepositoryProvider).getStockValuation();
});

class StockValuationReportScreen extends ConsumerWidget {
  const StockValuationReportScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final valuationAsync = ref.watch(_stockValuationProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Stock Valuation'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      body: valuationAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: \$e', style: const TextStyle(color: AppTheme.danger))),
        data: (data) {
          final totalValue = data['total_value'] as double;
          final items = data['items'] as List<Map<String, dynamic>>;

          return Column(
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                margin: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: AppTheme.primaryGradient,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    const Text('Total Stock Value', style: TextStyle(color: Colors.white70, fontSize: 16)),
                    const SizedBox(height: 8),
                    Text('\$\${totalValue.toStringAsFixed(2)}', style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
              
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final item = items[index];
                    return Card(
                      color: AppTheme.cardDark,
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        title: Text(item['name'], style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold)),
                        subtitle: Text('SKU: ${item["sku"]} | Qty: ${item["qty"]} | WAC: ${(item["cost"] as num).toCurrency()}', style: const TextStyle(color: AppTheme.textSecondary)),
                        trailing: Text((item["value"] as num).toCurrency(), style: const TextStyle(color: AppTheme.accent, fontWeight: FontWeight.bold, fontSize: 16)),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
