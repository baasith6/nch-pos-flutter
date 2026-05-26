import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../app/router.dart';
import '../../../../app/theme.dart';
import '../../../../core/services/auth_session_service.dart';
import '../../../products/data/models/product_model.dart';
import '../../../products/data/repositories/product_repository.dart';
import '../../data/repositories/stock_repository.dart';
import 'stock_adjustment_history_screen.dart';

final _stockProductsProvider = FutureProvider<List<ProductModel>>((ref) {
  return ref.read(productRepositoryProvider).getAllForAdmin();
});

class StockManagementScreen extends ConsumerStatefulWidget {
  const StockManagementScreen({super.key});

  @override
  ConsumerState<StockManagementScreen> createState() => _StockManagementScreenState();
}

class _StockManagementScreenState extends ConsumerState<StockManagementScreen> {
  String _searchQuery = '';
  String _selectedFilter = 'All'; // All, In Stock, Low Stock, Out of Stock

  List<ProductModel> _filterProducts(List<ProductModel> products) {
    return products.where((p) {
      // 1. Search Query
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final matchName = p.name.toLowerCase().contains(q);
        final matchSku = p.sku.toLowerCase().contains(q);
        final matchBarcode = p.barcode?.toLowerCase().contains(q) ?? false;
        if (!matchName && !matchSku && !matchBarcode) return false;
      }
      // 2. Filter Chips
      if (_selectedFilter == 'In Stock') {
        if (p.baseStockQuantity <= p.reorderLevelBase || p.baseStockQuantity == 0) return false;
      } else if (_selectedFilter == 'Low Stock') {
        if (!p.isLowStock || p.baseStockQuantity == 0) return false;
      } else if (_selectedFilter == 'Out of Stock') {
        if (p.baseStockQuantity > 0) return false;
      }
      return true;
    }).toList();
  }

  void _onBackPressed() {
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
  }

  @override
  Widget build(BuildContext context) {
    final productsAsync = ref.watch(_stockProductsProvider);

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Stock Management', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 18)),
        backgroundColor: AppTheme.surface,
        elevation: 0,
        centerTitle: false,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: _onBackPressed,
        ),
        actions: [
          TextButton.icon(
            icon: const Icon(Icons.history_rounded, size: 20, color: AppTheme.primary),
            label: const Text('History', style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.w600)),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const StockAdjustmentHistoryScreen()),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: productsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _buildErrorState(e.toString()),
        data: (allProducts) {
          final filteredProducts = _filterProducts(allProducts);

          return Column(
            children: [
              Container(
                color: AppTheme.surface,
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                child: Column(
                  children: [
                    _buildSummarySection(allProducts),
                    const SizedBox(height: 20),
                    _buildSearchBar(),
                    const SizedBox(height: 16),
                    _buildFilterChips(),
                  ],
                ),
              ),
              Expanded(
                child: allProducts.isEmpty
                    ? _buildEmptyState()
                    : filteredProducts.isEmpty
                        ? _buildNoResultsState()
                        : ListView.separated(
                            padding: const EdgeInsets.only(left: 20, right: 20, top: 16, bottom: 40),
                            itemCount: filteredProducts.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 12),
                            itemBuilder: (context, i) => _buildStockCard(filteredProducts[i]),
                          ),
              ),
            ],
          );
        },
      ),
    );
  }

  // ─── Sections ───────────────────────────────────────────────────────────────

  Widget _buildSummarySection(List<ProductModel> products) {
    final total = products.length;
    final outOfStock = products.where((p) => p.baseStockQuantity == 0).length;
    final lowStock = products.where((p) => p.isLowStock && p.baseStockQuantity > 0).length;

    return Row(
      children: [
        Expanded(child: _summaryCard('Total Products', total.toString(), AppTheme.primary)),
        const SizedBox(width: 12),
        Expanded(child: _summaryCard('Low Stock', lowStock.toString(), AppTheme.warning)),
        const SizedBox(width: 12),
        Expanded(child: _summaryCard('Out of Stock', outOfStock.toString(), AppTheme.danger)),
      ],
    );
  }

  Widget _summaryCard(String title, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        children: [
          Text(value, style: TextStyle(color: color, fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(title, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11, fontWeight: FontWeight.w500), textAlign: TextAlign.center),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      height: 52,
      decoration: BoxDecoration(
        color: AppTheme.background,
        borderRadius: BorderRadius.circular(14),
      ),
      child: TextField(
        onChanged: (val) => setState(() => _searchQuery = val),
        style: const TextStyle(fontSize: 15, color: AppTheme.textPrimary),
        decoration: InputDecoration(
          hintText: 'Search product, SKU, barcode',
          hintStyle: const TextStyle(color: AppTheme.textHint, fontSize: 14),
          prefixIcon: const Icon(Icons.search_rounded, color: AppTheme.mutedText),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      ),
    );
  }

  Widget _buildFilterChips() {
    final filters = ['All', 'In Stock', 'Low Stock', 'Out of Stock'];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: filters.map((f) {
          final isSelected = _selectedFilter == f;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(f),
              selected: isSelected,
              onSelected: (_) => setState(() => _selectedFilter = f),
              backgroundColor: AppTheme.background,
              selectedColor: AppTheme.primary,
              labelStyle: TextStyle(
                color: isSelected ? Colors.white : AppTheme.textSecondary,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                fontSize: 13,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(color: isSelected ? AppTheme.primary : AppTheme.border),
              ),
              showCheckmark: false,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildStockCard(ProductModel p) {
    Color statusColor;
    String statusText;
    if (p.baseStockQuantity == 0) {
      statusColor = AppTheme.danger;
      statusText = 'Out of Stock';
    } else if (p.isLowStock) {
      statusColor = AppTheme.warning;
      statusText = 'Low Stock';
    } else {
      statusColor = AppTheme.accent;
      statusText = 'In Stock';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.border),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      p.name,
                      style: const TextStyle(color: AppTheme.textPrimary, fontSize: 15, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'SKU: ${p.sku}  •  ${p.categoryId ?? 'Uncategorized'}',
                      style: const TextStyle(color: AppTheme.textHint, fontSize: 12),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(statusText, style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Divider(height: 1, color: AppTheme.border),
          ),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Stock: ${p.baseStockQuantity} Units', style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 2),
                    Text('Reorder Level: ${p.reorderLevelBase}', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                  ],
                ),
              ),
              FilledButton.icon(
                onPressed: () => _showAdjustBottomSheet(context, ref, p),
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.primary.withValues(alpha: 0.1),
                  foregroundColor: AppTheme.primary,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                icon: const Icon(Icons.tune_rounded, size: 16),
                label: const Text('Adjust Stock', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showAdjustBottomSheet(BuildContext context, WidgetRef ref, ProductModel p) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: _AdjustStockForm(product: p),
      ),
    );
  }

  // ─── States ─────────────────────────────────────────────────────────────────

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.inventory_2_outlined, size: 60, color: AppTheme.textHint),
          const SizedBox(height: 16),
          const Text('No stock items found', style: TextStyle(color: AppTheme.textPrimary, fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          const Text('Add products first to manage stock', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () => context.push(AppRoutes.addProduct),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            child: const Text('Go to Products', style: TextStyle(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  Widget _buildNoResultsState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off_rounded, size: 50, color: AppTheme.border),
          SizedBox(height: 16),
          Text('No matching stock items', style: TextStyle(color: AppTheme.textPrimary, fontSize: 15, fontWeight: FontWeight.w600)),
          SizedBox(height: 8),
          Text('Try another product name, SKU, or barcode', style: TextStyle(color: AppTheme.textHint, fontSize: 13)),
        ],
      ),
    );
  }

  Widget _buildErrorState(String error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline_rounded, size: 50, color: AppTheme.danger),
          const SizedBox(height: 16),
          const Text('Unable to load stock', style: TextStyle(color: AppTheme.textPrimary, fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          const Text('Please try again', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
          const SizedBox(height: 24),
          OutlinedButton(
            onPressed: () => ref.invalidate(_stockProductsProvider),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}

class _AdjustStockForm extends ConsumerStatefulWidget {
  final ProductModel product;
  const _AdjustStockForm({required this.product});

  @override
  ConsumerState<_AdjustStockForm> createState() => _AdjustStockFormState();
}

class _AdjustStockFormState extends ConsumerState<_AdjustStockForm> {
  final _qtyCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  bool _isAdd = true;
  bool _isLoading = false;

  int get _newStock {
    final adj = int.tryParse(_qtyCtrl.text) ?? 0;
    return _isAdd ? widget.product.baseStockQuantity + adj : widget.product.baseStockQuantity - adj;
  }

  bool get _isValid {
    final adj = int.tryParse(_qtyCtrl.text) ?? 0;
    if (adj <= 0) return false;
    if (!_isAdd && adj > widget.product.baseStockQuantity) return false;
    if (_noteCtrl.text.trim().isEmpty) return false;
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.product;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Adjust Stock', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: AppTheme.textSecondary),
                  onPressed: () => Navigator.pop(context),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Text(p.name, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
            const SizedBox(height: 4),
            Text('Current Stock: ${p.baseStockQuantity} Units', style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
            const SizedBox(height: 24),
            Container(
              decoration: BoxDecoration(color: AppTheme.background, borderRadius: BorderRadius.circular(12)),
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _isAdd = true),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: _isAdd ? AppTheme.primary : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        alignment: Alignment.center,
                        child: Text('Add Stock', style: TextStyle(color: _isAdd ? Colors.white : AppTheme.textSecondary, fontWeight: FontWeight.w600, fontSize: 13)),
                      ),
                    ),
                  ),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _isAdd = false),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: !_isAdd ? AppTheme.danger : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        alignment: Alignment.center,
                        child: Text('Remove Stock', style: TextStyle(color: !_isAdd ? Colors.white : AppTheme.textSecondary, fontWeight: FontWeight.w600, fontSize: 13)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _qtyCtrl,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      labelText: 'Quantity',
                      filled: true,
                      fillColor: AppTheme.background,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: AppTheme.background,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('New Stock', style: TextStyle(fontSize: 11, color: AppTheme.textHint)),
                        const SizedBox(height: 2),
                        Text('$_newStock', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: _newStock < 0 ? AppTheme.danger : AppTheme.textPrimary)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            if (!_isAdd && _newStock < 0)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text('Cannot remove more than current stock', style: TextStyle(color: AppTheme.danger, fontSize: 12)),
              ),
            const SizedBox(height: 16),
            TextField(
              controller: _noteCtrl,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                labelText: 'Reason / Note *',
                filled: true,
                fillColor: AppTheme.background,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isValid && !_isLoading
                    ? () async {
                        setState(() => _isLoading = true);
                        try {
                          await ref.read(stockRepositoryProvider).adjustStock(
                            productId: p.id,
                            oldQuantity: p.baseStockQuantity,
                            newQuantity: _newStock,
                            reason: _noteCtrl.text.trim(),
                          );
                          ref.invalidate(_stockProductsProvider);
                          if (!context.mounted) return;
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Stock updated successfully'), backgroundColor: AppTheme.accent),
                          );
                        } catch (e) {
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.danger),
                          );
                        } finally {
                          if (mounted) setState(() => _isLoading = false);
                        }
                      }
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
                child: _isLoading
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Save Adjustment', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
