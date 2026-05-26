import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../app/theme.dart';
import '../../../../core/extensions/extensions.dart';
import '../../../products/data/models/product_model.dart';
import '../../../products/data/repositories/product_repository.dart';
import '../../../customers/data/models/customer_model.dart';
import '../../../customers/data/repositories/customer_repository.dart';
import '../../data/repositories/quotation_repository.dart';
import '../../../sales/data/models/sale_model.dart';

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
    if (cart.isEmpty) return;

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
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Quotation saved successfully')));
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e', style: const TextStyle(color: AppTheme.danger))));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isSearching = _searchQuery.isNotEmpty;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Row(
          children: [
            const Text('Create Quotation', style: TextStyle(color: AppTheme.textPrimary, fontSize: 18, fontWeight: FontWeight.w600)),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: const BoxDecoration(
                color: Color(0xFFFDE68A),
                borderRadius: BorderRadius.all(Radius.circular(6)),
              ),
              child: const Text('Draft', style: TextStyle(color: Color(0xFF92400E), fontSize: 10, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppTheme.textPrimary, size: 20),
          onPressed: () => context.pop(),
        ),
        backgroundColor: AppTheme.surface,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppTheme.textPrimary),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: isSearching ? _buildSearchResults() : _buildQuotationForm(),
            ),
            if (!isSearching) _buildBottomSummary(),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchResults() {
    return Column(
      children: [
        _buildSearchBar(),
        Expanded(
          child: Consumer(
            builder: (context, ref, _) {
              final searchResults = ref.watch(_productsSearchProvider(_searchQuery));
              return searchResults.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('Error: $e', style: const TextStyle(color: AppTheme.danger))),
                data: (products) {
                  if (products.isEmpty) {
                    return const Center(child: Text('No products found', style: TextStyle(color: AppTheme.textHint)));
                  }
                  return ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: products.length,
                    itemBuilder: (context, index) {
                      final p = products[index];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(
                          color: AppTheme.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppTheme.border),
                        ),
                        child: ListTile(
                          title: Text(p.name, style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w600)),
                          subtitle: Text('${p.baseStockQuantity} in stock · ${p.sellingPriceBase.toCurrency()}', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                          trailing: const Icon(Icons.add_circle_rounded, color: AppTheme.primary),
                          onTap: () {
                            ref.read(quotationCartProvider.notifier).addItem(p);
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                            FocusScope.of(context).unfocus();
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
    );
  }

  Widget _buildQuotationForm() {
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(child: _buildSearchBar()),
        
        // Customer Section
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Customer', style: TextStyle(color: AppTheme.textPrimary, fontSize: 14, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: Consumer(
                        builder: (context, ref, _) {
                          final customersAsync = ref.watch(_customersProvider);
                          return Container(
                            height: 56,
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            decoration: BoxDecoration(
                              color: AppTheme.surface,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppTheme.border),
                            ),
                            child: customersAsync.when(
                              loading: () => const Align(alignment: Alignment.centerLeft, child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))),
                              error: (e, _) => const Text('Error loading customers'),
                              data: (customers) => DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  value: _selectedCustomerId,
                                  isExpanded: true,
                                  hint: const Text('Walk-in Customer', style: TextStyle(color: AppTheme.textPrimary, fontSize: 15, fontWeight: FontWeight.w500)),
                                  icon: const Icon(Icons.keyboard_arrow_down_rounded, color: AppTheme.textSecondary),
                                  items: [
                                    const DropdownMenuItem<String>(
                                      value: null,
                                      child: Text('Walk-in Customer', style: TextStyle(color: AppTheme.textPrimary, fontSize: 15, fontWeight: FontWeight.w500)),
                                    ),
                                    ...customers.map((c) => DropdownMenuItem(
                                      value: c.id,
                                      child: Text(c.name, style: const TextStyle(color: AppTheme.textPrimary, fontSize: 15, fontWeight: FontWeight.w500)),
                                    )),
                                  ],
                                  onChanged: (v) => setState(() => _selectedCustomerId = v),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      height: 56,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      alignment: Alignment.center,
                      child: const Row(
                        children: [
                          Icon(Icons.add_rounded, color: AppTheme.primary, size: 20),
                          SizedBox(width: 4),
                          Text('New', style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),

        // Quotation Items Header
        const SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(20, 24, 20, 12),
            child: Text('Quotation Items', style: TextStyle(color: AppTheme.textPrimary, fontSize: 16, fontWeight: FontWeight.w700)),
          ),
        ),

        // Cart Items
        Consumer(
          builder: (context, ref, _) {
            final cart = ref.watch(quotationCartProvider);
            
            if (cart.isEmpty) {
              return SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
                  child: Container(
                    padding: const EdgeInsets.all(32),
                    decoration: BoxDecoration(
                      color: AppTheme.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppTheme.border, style: BorderStyle.solid),
                    ),
                    child: Column(
                      children: [
                        const Icon(Icons.receipt_long_rounded, size: 48, color: AppTheme.border),
                        const SizedBox(height: 16),
                        const Text('No items added yet', style: TextStyle(color: AppTheme.textPrimary, fontSize: 16, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 8),
                        const Text('Search or scan products to create a quotation', textAlign: TextAlign.center, style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                        const SizedBox(height: 24),
                        OutlinedButton.icon(
                          onPressed: () {}, // Focus search
                          icon: const Icon(Icons.search_rounded, size: 18),
                          label: const Text('Add Product'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppTheme.primary,
                            side: const BorderSide(color: AppTheme.primary),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }

            return SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final item = cart[index];
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppTheme.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppTheme.border),
                        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 4, offset: const Offset(0, 2))],
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
                                    Text(item.productName, style: const TextStyle(color: AppTheme.textPrimary, fontSize: 15, fontWeight: FontWeight.w600)),
                                    const SizedBox(height: 4),
                                    Text(item.unitPrice.toCurrency(), style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline_rounded, color: AppTheme.danger, size: 20),
                                onPressed: () => ref.read(quotationCartProvider.notifier).removeItem(item.productId),
                                constraints: const BoxConstraints(),
                                padding: EdgeInsets.zero,
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Container(
                                decoration: BoxDecoration(
                                  border: Border.all(color: AppTheme.border),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  children: [
                                    InkWell(
                                      onTap: () => ref.read(quotationCartProvider.notifier).updateQuantity(item.productId, -1),
                                      borderRadius: const BorderRadius.horizontal(left: Radius.circular(8)),
                                      child: const Padding(padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8), child: Icon(Icons.remove, size: 16, color: AppTheme.textPrimary)),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                      color: AppTheme.background,
                                      child: Text('${item.quantity}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                    ),
                                    InkWell(
                                      onTap: () => ref.read(quotationCartProvider.notifier).updateQuantity(item.productId, 1),
                                      borderRadius: const BorderRadius.horizontal(right: Radius.circular(8)),
                                      child: const Padding(padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8), child: Icon(Icons.add, size: 16, color: AppTheme.textPrimary)),
                                    ),
                                  ],
                                ),
                              ),
                              Text((item.unitPrice * item.quantity).toCurrency(), style: const TextStyle(color: AppTheme.primary, fontSize: 16, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
                childCount: cart.length,
              ),
            );
          },
        ),

        // Quotation Details
        const SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(20, 24, 20, 12),
            child: Text('Quotation Details', style: TextStyle(color: AppTheme.textPrimary, fontSize: 16, fontWeight: FontWeight.w700)),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
            child: Container(
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.border),
              ),
              child: Column(
                children: [
                  ListTile(
                    title: const Text('Valid Until', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                    trailing: const Text('7 Days', style: TextStyle(color: AppTheme.textSecondary, fontSize: 14)),
                    onTap: () {},
                  ),
                  const Divider(height: 1, color: AppTheme.border),
                  ListTile(
                    title: const Text('Notes', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                    trailing: const Icon(Icons.chevron_right_rounded, size: 20, color: AppTheme.textSecondary),
                    onTap: () {},
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 56,
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.border),
              ),
              child: TextField(
                controller: _searchController,
                style: const TextStyle(color: AppTheme.textPrimary, fontSize: 15),
                decoration: InputDecoration(
                  hintText: 'Search product, SKU, barcode',
                  hintStyle: const TextStyle(color: AppTheme.textHint, fontSize: 15),
                  prefixIcon: const Icon(Icons.search_rounded, color: AppTheme.textSecondary, size: 22),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded, color: AppTheme.textSecondary, size: 20),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                            FocusScope.of(context).unfocus();
                          },
                        )
                      : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 16),
                ),
                onChanged: (value) => setState(() => _searchQuery = value),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Container(
            height: 56,
            width: 56,
            decoration: BoxDecoration(
              color: AppTheme.primary,
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              icon: const Icon(Icons.qr_code_scanner_rounded, color: Colors.white),
              onPressed: () {},
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomSummary() {
    return Consumer(
      builder: (context, ref, _) {
        final cart = ref.watch(quotationCartProvider);
        final cartNotifier = ref.read(quotationCartProvider.notifier);
        
        return Container(
          decoration: BoxDecoration(
            color: AppTheme.surface,
            border: const Border(top: BorderSide(color: AppTheme.border)),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, -4))],
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildSummaryRow('Subtotal', cartNotifier.subtotal.toCurrency()),
              const SizedBox(height: 8),
              _buildSummaryRow('Discount', cartNotifier.totalDiscount.toCurrency()),
              const SizedBox(height: 8),
              _buildSummaryRow('Tax', (0.0).toCurrency()),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Divider(height: 1, color: AppTheme.border),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Total', style: TextStyle(color: AppTheme.textPrimary, fontSize: 16, fontWeight: FontWeight.bold)),
                  Text(cartNotifier.grandTotal.toCurrency(), style: const TextStyle(color: AppTheme.primary, fontSize: 20, fontWeight: FontWeight.w800)),
                ],
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: cart.isEmpty || _isLoading ? null : _saveQuotation,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    disabledBackgroundColor: AppTheme.border,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 0,
                  ),
                  child: _isLoading
                      ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : Text(cart.isEmpty ? 'Add items to continue' : 'Save Quotation', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: cart.isEmpty ? AppTheme.textHint : Colors.white)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSummaryRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 14)),
        Text(value, style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14, fontWeight: FontWeight.w500)),
      ],
    );
  }
}
