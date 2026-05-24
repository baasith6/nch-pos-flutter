import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../app/router.dart';
import '../../../../app/theme.dart';
import '../../../../core/extensions/extensions.dart';
import '../../data/models/product_model.dart';
import '../../data/repositories/product_repository.dart';
import '../../../../core/services/auth_session_service.dart';

final _productListProvider = FutureProvider<List<ProductModel>>((ref) async {
  final profile = await ref.watch(currentProfileProvider.future);
  final repo = ref.read(productRepositoryProvider);
  if (profile?.isAdmin == true) return repo.getAllForAdmin();
  return repo.getAllForStaff();
});

class ProductListScreen extends ConsumerWidget {
  const ProductListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final productsAsync = ref.watch(_productListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Products'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              final profile = ref.read(currentProfileProvider).value;
              if (profile?.isAdmin == true) {
                context.go(AppRoutes.adminDashboard);
              } else {
                context.go(AppRoutes.staffDashboard);
              }
            }
          },
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push(AppRoutes.addProduct).then((_) => ref.invalidate(_productListProvider)),
        icon: const Icon(Icons.add),
        label: const Text('Add Product'),
      ),
      body: productsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e', style: const TextStyle(color: AppTheme.danger))),
        data: (products) => products.isEmpty
            ? const Center(child: Text('No products yet', style: TextStyle(color: AppTheme.textSecondary)))
            : ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: products.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, i) {
                  final p = products[i];
                  return Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppTheme.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.border, width: 1),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.03),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    p.name,
                                    style: const TextStyle(color: AppTheme.slateText, fontSize: 16, fontWeight: FontWeight.w600),
                                  ),
                                  const SizedBox(height: 6),
                                  Row(
                                    children: [
                                      if (p.sku != null && p.sku!.isNotEmpty) ...[
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: AppTheme.background,
                                            borderRadius: BorderRadius.circular(4),
                                            border: Border.all(color: AppTheme.border),
                                          ),
                                          child: Text('SKU: ${p.sku}', style: const TextStyle(color: AppTheme.mutedText, fontSize: 11, fontFamily: 'monospace')),
                                        ),
                                        const SizedBox(width: 8),
                                      ],
                                      if (p.categoryName != null && p.categoryName!.isNotEmpty)
                                        Text(p.categoryName!, style: const TextStyle(color: AppTheme.mutedText, fontSize: 12)),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.edit_outlined, size: 20, color: AppTheme.mutedText),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              onPressed: () => context
                                  .push(AppRoutes.editProduct.replaceAll(':id', p.id))
                                  .then((_) => ref.invalidate(_productListProvider)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        const Divider(height: 1),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Price (${p.baseUnitName ?? 'Unit'})', style: const TextStyle(color: AppTheme.mutedText, fontSize: 11)),
                                const SizedBox(height: 2),
                                Text(
                                  p.sellingPriceBase.toCurrency(),
                                  style: const TextStyle(color: AppTheme.slateText, fontSize: 16, fontWeight: FontWeight.w700),
                                ),
                              ],
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                const Text('In Stock', style: TextStyle(color: AppTheme.mutedText, fontSize: 11)),
                                const SizedBox(height: 2),
                                Row(
                                  children: [
                                    if (p.isLowStock)
                                      Container(
                                        margin: const EdgeInsets.only(right: 6),
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: AppTheme.danger.withValues(alpha: 0.1),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: const Text('Low', style: TextStyle(color: AppTheme.danger, fontSize: 10, fontWeight: FontWeight.bold)),
                                      ),
                                    Text(
                                      '${p.baseStockQuantity} ${p.baseUnitName ?? ''}',
                                      style: TextStyle(
                                        color: p.isLowStock ? AppTheme.danger : AppTheme.success,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
      ),
    );
  }
}
