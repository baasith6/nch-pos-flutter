import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

class ProductListScreen extends ConsumerStatefulWidget {
  const ProductListScreen({super.key});

  @override
  ConsumerState<ProductListScreen> createState() => _ProductListScreenState();
}

class _ProductListScreenState extends ConsumerState<ProductListScreen> {
  final _searchCtrl = TextEditingController();
  String _searchQuery = '';
  String _activeFilter = 'All'; // All, In Stock, Low Stock, Out of Stock
  final List<String> _filters = ['All', 'In Stock', 'Low Stock', 'Out of Stock'];

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _confirmDelete(ProductModel product) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete this product?'),
        content: const Text(
          'This action cannot be undone. Existing sales records will not be affected.',
          style: TextStyle(color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: AppTheme.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.danger),
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await ref.read(productRepositoryProvider).delete(product.id);
                ref.invalidate(_productListProvider);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text('Product deleted successfully'),
                      backgroundColor: AppTheme.accent,
                      action: SnackBarAction(
                        label: 'Undo',
                        textColor: Colors.white,
                        onPressed: () async {
                           await ref.read(productRepositoryProvider).update(product.id, {'status': 'Active'});
                           ref.invalidate(_productListProvider);
                        },
                      ),
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to delete product: $e'), backgroundColor: AppTheme.danger),
                  );
                }
              }
            },
            child: const Text('Delete Product'),
          ),
        ],
      ),
    );
  }

  List<ProductModel> _getFilteredProducts(List<ProductModel> products) {
    var filtered = products.where((p) => p.isActive).toList();

    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      filtered = filtered.where((p) {
        final matchesName = p.name.toLowerCase().contains(q);
        final matchesSku = p.sku.toLowerCase().contains(q);
        final matchesBarcode = p.barcode?.toLowerCase().contains(q) ?? false;
        final matchesCat = p.categoryName?.toLowerCase().contains(q) ?? false;
        return matchesName || matchesSku || matchesBarcode || matchesCat;
      }).toList();
    }

    if (_activeFilter == 'In Stock') {
      filtered = filtered.where((p) => !p.isOutOfStock).toList();
    } else if (_activeFilter == 'Low Stock') {
      filtered = filtered.where((p) => p.isLowStock && !p.isOutOfStock).toList();
    } else if (_activeFilter == 'Out of Stock') {
      filtered = filtered.where((p) => p.isOutOfStock).toList();
    }

    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    final productsAsync = ref.watch(_productListProvider);

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Products', style: TextStyle(fontWeight: FontWeight.w600)),
        backgroundColor: AppTheme.surface,
        elevation: 0,
        centerTitle: false,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
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
        actions: [
          TextButton.icon(
            onPressed: () {
              context.push(AppRoutes.addProduct).then((_) => ref.invalidate(_productListProvider));
            },
            icon: const Icon(Icons.add_rounded, size: 20),
            label: const Text('Add', style: TextStyle(fontWeight: FontWeight.w600)),
            style: TextButton.styleFrom(foregroundColor: AppTheme.primary),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          // ─── Search Bar ────────────────────────────────────
          Container(
            color: AppTheme.surface,
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
            child: TextField(
              controller: _searchCtrl,
              style: const TextStyle(color: AppTheme.textPrimary, fontSize: 15),
              decoration: InputDecoration(
                hintText: 'Search products, SKU, barcode',
                hintStyle: const TextStyle(color: AppTheme.textHint, fontSize: 14),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                fillColor: AppTheme.background,
                filled: true,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                prefixIcon: const Icon(Icons.search_rounded, color: AppTheme.textHint, size: 22),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.cancel_rounded, color: AppTheme.textHint, size: 20),
                        onPressed: () {
                          _searchCtrl.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
              ),
              onChanged: (v) => setState(() => _searchQuery = v),
            ),
          ),

          // ─── Filter Chips ────────────────────────────────────
          Container(
            color: AppTheme.surface,
            padding: const EdgeInsets.fromLTRB(20, 0, 0, 12),
            child: SizedBox(
              height: 36,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _filters.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, i) {
                  final filter = _filters[i];
                  final isSelected = _activeFilter == filter;
                  return ChoiceChip(
                    label: Text(filter),
                    selected: isSelected,
                    onSelected: (val) {
                      setState(() => _activeFilter = filter);
                    },
                    selectedColor: AppTheme.primary,
                    backgroundColor: AppTheme.background,
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.white : AppTheme.textSecondary,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                      fontSize: 13,
                    ),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                    side: isSelected ? BorderSide.none : const BorderSide(color: AppTheme.border),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                  );
                },
              ),
            ),
          ),
          Container(height: 1, color: AppTheme.border),

          // ─── Product List ────────────────────────────────────
          Expanded(
            child: productsAsync.when(
              loading: () => ListView.separated(
                padding: const EdgeInsets.all(20),
                itemCount: 5,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (_, __) => _SkeletonCard(),
              ),
              error: (e, _) => Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline_rounded, color: AppTheme.danger, size: 48),
                    const SizedBox(height: 16),
                    const Text('Unable to load products', style: TextStyle(color: AppTheme.textPrimary, fontSize: 16, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    Text('Error: $e', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13), textAlign: TextAlign.center),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () => ref.invalidate(_productListProvider),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
              data: (products) {
                final filtered = _getFilteredProducts(products);

                if (products.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(color: AppTheme.primary.withValues(alpha: 0.05), shape: BoxShape.circle),
                          child: const Icon(Icons.inventory_2_outlined, size: 48, color: AppTheme.primary),
                        ),
                        const SizedBox(height: 24),
                        const Text('No products added yet', style: TextStyle(color: AppTheme.textPrimary, fontSize: 18, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 8),
                        const Text('Add your first product to start managing inventory', style: TextStyle(color: AppTheme.textSecondary, fontSize: 14)),
                        const SizedBox(height: 24),
                        ElevatedButton.icon(
                          onPressed: () => context.push(AppRoutes.addProduct).then((_) => ref.invalidate(_productListProvider)),
                          icon: const Icon(Icons.add),
                          label: const Text('Add Product'),
                        ),
                      ],
                    ),
                  );
                }

                if (filtered.isEmpty) {
                  return const Center(
                    child: Text('No products match your search or filters.', style: TextStyle(color: AppTheme.textSecondary, fontSize: 15)),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, i) {
                    final p = filtered[i];
                    final skuText = (p.sku.isNotEmpty) ? p.sku : 'Not added';
                    final catText = (p.categoryName != null && p.categoryName!.isNotEmpty) ? p.categoryName! : 'Uncategorized';

                    // Stock Status Logic
                    Color stockColor = AppTheme.textSecondary;
                    String stockStatus = 'Unknown';
                    if (p.isOutOfStock) {
                      stockColor = AppTheme.danger;
                      stockStatus = 'Out of Stock';
                    } else if (p.isLowStock) {
                      stockColor = AppTheme.warning;
                      stockStatus = 'Low Stock';
                    } else {
                      stockColor = AppTheme.success;
                      stockStatus = 'In Stock';
                    }

                    return Material(
                      color: AppTheme.surface,
                      borderRadius: BorderRadius.circular(18),
                      elevation: 0,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(18),
                        onTap: () {}, // Could open product details
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: AppTheme.border, width: 0.5),
                            boxShadow: [
                              BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10, offset: const Offset(0, 4)),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Top Row: Name, SKU, Category
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(p.name, style: const TextStyle(color: AppTheme.textPrimary, fontSize: 16, fontWeight: FontWeight.w600)),
                                        const SizedBox(height: 4),
                                        Text('SKU: $skuText · $catText', style: const TextStyle(color: AppTheme.textHint, fontSize: 13)),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  // Stock Status
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(stockStatus, style: TextStyle(color: stockColor, fontSize: 12, fontWeight: FontWeight.w600)),
                                      const SizedBox(height: 2),
                                      Text('${p.baseStockQuantity} ${p.baseUnitName ?? 'Pieces'}', style: TextStyle(color: stockColor, fontSize: 14, fontWeight: FontWeight.w700)),
                                    ],
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              const Divider(color: AppTheme.border, height: 1),
                              const SizedBox(height: 12),
                              // Bottom Row: Price & Actions
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text('Price', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                                      const SizedBox(height: 2),
                                      Text('${p.sellingPriceBase.toCurrency()} / ${p.baseUnitName ?? 'Piece'}', style: const TextStyle(color: AppTheme.textPrimary, fontSize: 15, fontWeight: FontWeight.w600)),
                                    ],
                                  ),
                                  Row(
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.edit_outlined, size: 20, color: AppTheme.textSecondary),
                                        tooltip: 'Edit',
                                        onPressed: () {
                                          context.push(AppRoutes.editProduct.replaceAll(':id', p.id)).then((_) => ref.invalidate(_productListProvider));
                                        },
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.delete_outline_rounded, size: 20, color: AppTheme.danger),
                                        tooltip: 'Delete',
                                        onPressed: () => _confirmDelete(p),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Skeleton Loading Card ──────────────────────────────────────────────────
class _SkeletonCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.border, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _skel(width: 140, height: 18),
                  const SizedBox(height: 8),
                  _skel(width: 100, height: 12),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _skel(width: 60, height: 12),
                  const SizedBox(height: 6),
                  _skel(width: 40, height: 16),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          _skel(width: double.infinity, height: 1),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _skel(width: 120, height: 16),
              Row(
                children: [
                  _skel(width: 32, height: 32, radius: 8),
                  const SizedBox(width: 8),
                  _skel(width: 32, height: 32, radius: 8),
                ],
              )
            ],
          )
        ],
      ),
    );
  }

  Widget _skel({required double width, required double height, double radius = 4}) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: AppTheme.border.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}
