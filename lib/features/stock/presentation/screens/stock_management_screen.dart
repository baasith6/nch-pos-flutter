import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../app/theme.dart';
import '../../../products/data/models/product_model.dart';
import '../../../products/data/repositories/product_repository.dart';
import '../../data/repositories/stock_repository.dart';
import 'stock_adjustment_history_screen.dart';

final _stockProductsProvider = FutureProvider<List<ProductModel>>((ref) {
  return ref.read(productRepositoryProvider).getAllForAdmin();
});

class StockManagementScreen extends ConsumerWidget {
  const StockManagementScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final productsAsync = ref.watch(_stockProductsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Stock Management'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => context.pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.history_rounded),
            tooltip: 'Adjustment History',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const StockAdjustmentHistoryScreen(),
              ),
            ),
          ),
        ],
      ),
      body: productsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (products) => ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: products.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, i) {
            final p = products[i];
            return Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppTheme.cardDark,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: p.isLowStock ? AppTheme.warning.withValues(alpha: 0.5) : AppTheme.borderDark,
                  width: p.isLowStock ? 1 : 0.5,
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(p.name, style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Text('Stock: ${p.stockQuantity}',
                                style: TextStyle(
                                  color: p.isLowStock ? AppTheme.warning : AppTheme.textSecondary,
                                  fontSize: 12,
                                  fontWeight: p.isLowStock ? FontWeight.w600 : FontWeight.normal,
                                )),
                            const SizedBox(width: 8),
                            Text('Reorder: ${p.reorderLevel}',
                                style: const TextStyle(color: AppTheme.textHint, fontSize: 11)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (p.isLowStock)
                    const Icon(Icons.warning_amber_rounded, color: AppTheme.warning, size: 18),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () => _showAdjustDialog(context, ref, p),
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(0, 36),
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                    ),
                    child: const Text('Adjust', style: TextStyle(fontSize: 12)),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  void _showAdjustDialog(BuildContext context, WidgetRef ref, ProductModel p) {
    final ctrl = TextEditingController(text: '${p.stockQuantity}');
    final reasonCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Adjust: ${p.name}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Current: ${p.stockQuantity}', style: const TextStyle(color: AppTheme.textSecondary)),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: AppTheme.textPrimary),
              decoration: const InputDecoration(labelText: 'New Quantity'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: reasonCtrl,
              style: const TextStyle(color: AppTheme.textPrimary),
              decoration: const InputDecoration(labelText: 'Reason'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final newQty = int.tryParse(ctrl.text) ?? p.stockQuantity;
              if (reasonCtrl.text.trim().isEmpty) return;
              await ref.read(stockRepositoryProvider).adjustStock(
                productId: p.id,
                oldQuantity: p.stockQuantity,
                newQuantity: newQty,
                reason: reasonCtrl.text.trim(),
              );
              ref.invalidate(_stockProductsProvider);
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
  }
}
