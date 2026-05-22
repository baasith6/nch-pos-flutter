import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../app/theme.dart';
import '../../../products/data/models/product_model.dart';
import '../../../products/data/repositories/product_repository.dart';
import '../../../customers/data/models/customer_model.dart';
import '../../../customers/data/repositories/customer_repository.dart';
import '../../data/repositories/quotation_repository.dart';
import '../../../sales/data/models/sale_model.dart'; // For CartItem

final quotationCartProvider = StateNotifierProvider.autoDispose<QuotationCartNotifier, List<CartItem>>((ref) {
  return QuotationCartNotifier();
});

class QuotationCartNotifier extends StateNotifier<List<CartItem>> {
  QuotationCartNotifier() : super([]);

  void addItem(ProductModel product) {
    final existing = state.indexWhere((e) => e.productId == product.id);
    if (existing >= 0) {
      final updated = [...state];
      updated[existing] = CartItem(
        productId: updated[existing].productId,
        productName: updated[existing].productName,
        productUnitId: updated[existing].productUnitId,
        unitName: updated[existing].unitName,
        unitPrice: updated[existing].unitPrice,
        quantity: updated[existing].quantity + 1,
        discount: updated[existing].discount,
      );
      state = updated;
    } else {
      state = [
        ...state,
        CartItem(
          productId: product.id,
          productName: product.name,
          productUnitId: product.baseUnitId ?? 'unknown',
          unitName: product.baseUnitName ?? 'Unit',
          unitPrice: product.sellingPriceBase,
          quantity: 1,
          discount: 0,
        )
      ];
    }
  }

  void updateQuantity(String productId, int delta) {
    state = state.map((item) {
      if (item.productId == productId) {
        final newQuantity = item.quantity + delta;
        return newQuantity > 0 ? CartItem(
          productId: item.productId,
          productName: item.productName,
          productUnitId: item.productUnitId,
          unitName: item.unitName,
          unitPrice: item.unitPrice,
          quantity: newQuantity,
          discount: item.discount,
        ) : item;
      }
      return item;
    }).toList();
  }

  void removeItem(String productId) {
    state = state.where((item) => item.productId != productId).toList();
  }

  void clear() => state = [];

  double get subtotal => state.fold(0, (sum, item) => sum + (item.unitPrice * item.quantity));
  double get totalDiscount => state.fold(0, (sum, item) => sum + item.discount);
  double get grandTotal => subtotal - totalDiscount;
}

final _productsSearchProvider = FutureProvider.autoDispose.family<List<ProductModel>, String>((ref, query) async {
  if (query.isEmpty) return [];
  return ref.read(productRepositoryProvider).searchProducts(query);
});

final _customersProvider = FutureProvider.autoDispose<List<CustomerModel>>((ref) {
  return ref.read(customerRepositoryProvider).getActive();
});

class CreateQuotationScreen extends ConsumerStatefulWidget {
  const CreateQuotationScreen({super.key});

  @override
  ConsumerState<CreateQuotationScreen> createState() => _CreateQuotationScreenState();
}

class _CreateQuotationScreenState extends ConsumerState<CreateQuotationScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';
  String? _selectedCustomerId;
  bool _isLoading = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _saveQuotation() async {
    final cart = ref.read(quotationCartProvider);
    if (cart.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cart is empty!')));
      return;
    }

    setState(() => _isLoading = true);
    try {
      final cartNotifier = ref.read(quotationCartProvider.notifier);
      final items = cart.map((item) => {
        'product_id': item.productId,
        'product_unit_id': item.productUnitId,
        'quantity': item.quantity,
        'unit_price': item.unitPrice,
        'discount': item.discount,
        'line_total': (item.unitPrice * item.quantity) - item.discount,
      }).toList();

      await ref.read(quotationRepositoryProvider).createQuotation(
        customerId: _selectedCustomerId,
        subtotal: cartNotifier.subtotal,
        discount: cartNotifier.totalDiscount,
        taxAmount: 0,
        grandTotal: cartNotifier.grandTotal,
        items: items,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Quotation Saved Successfully')));
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: \$e', style: const TextStyle(color: AppTheme.danger))));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cart = ref.watch(quotationCartProvider);
    final cartNotifier = ref.read(quotationCartProvider.notifier);
    final customersAsync = ref.watch(_customersProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Quotation'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      body: Row(
        children: [
          // Left Side: Product Search
          Expanded(
            flex: 2,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: TextField(
                    controller: _searchController,
                    style: const TextStyle(color: AppTheme.textPrimary),
                    decoration: InputDecoration(
                      hintText: 'Search products by name or barcode...',
                      prefixIcon: const Icon(Icons.search, color: AppTheme.textSecondary),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, color: AppTheme.textSecondary),
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _searchQuery = '');
                              },
                            )
                          : null,
                    ),
                    onChanged: (value) => setState(() => _searchQuery = value),
                  ),
                ),
                Expanded(
                  child: _searchQuery.isEmpty
                      ? const Center(child: Text('Type to search products', style: TextStyle(color: AppTheme.textHint)))
                      : Consumer(
                          builder: (context, ref, _) {
                            final searchResults = ref.watch(_productsSearchProvider(_searchQuery));
                            return searchResults.when(
                              loading: () => const Center(child: CircularProgressIndicator()),
                              error: (e, _) => Center(child: Text('Error: \$e', style: const TextStyle(color: AppTheme.danger))),
                              data: (products) {
                                if (products.isEmpty) {
                                  return const Center(child: Text('No products found', style: TextStyle(color: AppTheme.textHint)));
                                }
                                return ListView.builder(
                                  padding: const EdgeInsets.symmetric(horizontal: 16),
                                  itemCount: products.length,
                                  itemBuilder: (context, index) {
                                    final p = products[index];
                                    return Card(
                                      color: AppTheme.cardDark,
                                      child: ListTile(
                                        title: Text(p.name, style: const TextStyle(color: AppTheme.textPrimary)),
                                        subtitle: Text('\${p.baseStockQuantity} in stock', style: const TextStyle(color: AppTheme.textSecondary)),
                                        trailing: const Icon(Icons.add_shopping_cart, color: AppTheme.primary),
                                        onTap: () {
                                          ref.read(quotationCartProvider.notifier).addItem(p);
                                          _searchController.clear();
                                          setState(() => _searchQuery = '');
                                        },
                                      ),
                                    );
                                  },
                                );
                              },
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
          
          // Right Side: Quotation Cart
          Container(
            width: 380,
            color: AppTheme.elevatedDark,
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  color: AppTheme.cardDark,
                  child: customersAsync.when(
                    loading: () => const CircularProgressIndicator(),
                    error: (e, _) => const Text('Error loading customers'),
                    data: (customers) => DropdownButtonFormField<String>(
                      value: _selectedCustomerId,
                      dropdownColor: AppTheme.elevatedDark,
                      style: const TextStyle(color: AppTheme.textPrimary),
                      decoration: const InputDecoration(labelText: 'Customer (Optional)', labelStyle: TextStyle(color: AppTheme.textSecondary)),
                      items: customers.map((c) => DropdownMenuItem(value: c.id, child: Text(c.name))).toList(),
                      onChanged: (v) => setState(() => _selectedCustomerId = v),
                    ),
                  ),
                ),
                
                Expanded(
                  child: cart.isEmpty
                      ? const Center(
                          child: Text(
                            'Quotation is empty',
                            style: TextStyle(color: AppTheme.textSecondary),
                          ),
                        )
                      : ListView.builder(
                          itemCount: cart.length,
                          itemBuilder: (context, index) {
                            final item = cart[index];
                            return ListTile(
                              title: Text(item.productName, style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14)),
                              subtitle: Text('\$\${item.unitPrice} x \${item.quantity}', style: const TextStyle(color: AppTheme.accent, fontSize: 12)),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.remove_circle_outline, color: AppTheme.danger, size: 20),
                                    onPressed: () => ref.read(quotationCartProvider.notifier).updateQuantity(item.productId, -1),
                                  ),
                                  Text('\${item.quantity}', style: const TextStyle(color: AppTheme.textPrimary, fontSize: 16)),
                                  IconButton(
                                    icon: const Icon(Icons.add_circle_outline, color: AppTheme.accent, size: 20),
                                    onPressed: () => ref.read(quotationCartProvider.notifier).updateQuantity(item.productId, 1),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                ),
                
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: const BoxDecoration(
                    color: AppTheme.bgDark,
                    border: Border(top: BorderSide(color: AppTheme.borderDark)),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Total:', style: TextStyle(color: AppTheme.textSecondary, fontSize: 18)),
                          Text('\$\${cartNotifier.grandTotal.toStringAsFixed(2)}', style: const TextStyle(color: AppTheme.accent, fontSize: 24, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _saveQuotation,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primary,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: _isLoading 
                              ? const CircularProgressIndicator(color: Colors.white) 
                              : const Text('Save Quotation', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
