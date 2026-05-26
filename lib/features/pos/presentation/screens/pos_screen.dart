import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../../../app/router.dart';
import '../../../../app/theme.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/extensions/extensions.dart';
import '../../../../core/services/auth_session_service.dart';
import '../../../products/data/models/product_model.dart';
import '../../../products/data/repositories/product_repository.dart';
import '../../../sales/data/models/sale_model.dart';
import '../../../sales/data/repositories/sales_repository.dart';
import '../../../quotations/data/repositories/quotation_repository.dart';
import '../../../settings/data/repositories/payment_method_repository.dart';
import '../../../settings/data/repositories/settings_repository.dart';

// ─── Cart Provider ────────────────────────────────────────────────────────────
final cartProvider = StateNotifierProvider<CartNotifier, List<CartItem>>((ref) {
  return CartNotifier();
});

class CartNotifier extends StateNotifier<List<CartItem>> {
  CartNotifier() : super([]);

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
          productUnitId: product.baseUnitId,
          unitName: product.baseUnitName ?? 'Unit',
          unitPrice: product.sellingPriceBase,
        ),
      ];
    }
  }

  void updateQuantity(String productId, int qty) {
    if (qty <= 0) {
      removeItem(productId);
      return;
    }
    state = state.map((e) {
      if (e.productId == productId) {
        return CartItem(
          productId: e.productId,
          productName: e.productName,
          productUnitId: e.productUnitId,
          unitName: e.unitName,
          unitPrice: e.unitPrice,
          quantity: qty,
          discount: e.discount,
        );
      }
      return e;
    }).toList();
  }

  void removeItem(String productId) {
    state = state.where((e) => e.productId != productId).toList();
  }

  void clearCart() => state = [];
  void loadCart(List<CartItem> items) => state = List.from(items);

  double get subtotal => state.fold(0, (sum, e) => sum + e.lineTotal);
}

// ─── Parked Carts Provider ────────────────────────────────────────────────────
final parkedCartsProvider =
    StateNotifierProvider<ParkedCartsNotifier, List<List<CartItem>>>((ref) {
  return ParkedCartsNotifier();
});

class ParkedCartsNotifier extends StateNotifier<List<List<CartItem>>> {
  ParkedCartsNotifier() : super([]);

  void park(List<CartItem> cart) {
    if (cart.isEmpty) return;
    state = [...state, List.from(cart)];
  }

  List<CartItem> restore(int index) {
    final cart = state[index];
    final updated = [...state]..removeAt(index);
    state = updated;
    return cart;
  }

  void remove(int index) {
    final updated = [...state]..removeAt(index);
    state = updated;
  }
}

// ─── Other Providers ─────────────────────────────────────────────────────────
final _searchQueryProvider = StateProvider<String>((ref) => '');
final _selectedPaymentProvider =
    StateProvider<String>((ref) => AppConstants.paymentCash);
final _billDiscountProvider = StateProvider<double>((ref) => 0);
final _checkoutLoadingProvider = StateProvider<bool>((ref) => false);
final _cashTenderedProvider = StateProvider<double>((ref) => 0);

final _productSearchProvider = FutureProvider<List<ProductModel>>((ref) async {
  final query = ref.watch(_searchQueryProvider);
  if (query.isEmpty) return [];
  final profile = await ref.watch(currentProfileProvider.future);
  final repo = ref.read(productRepositoryProvider);
  return repo.searchProducts(query, isAdmin: profile?.isAdmin ?? false);
});

// ─── POS Screen ──────────────────────────────────────────────────────────────
class PosScreen extends ConsumerStatefulWidget {
  final String? quotationId;
  const PosScreen({super.key, this.quotationId});

  @override
  ConsumerState<PosScreen> createState() => _PosScreenState();
}

class _PosScreenState extends ConsumerState<PosScreen> {
  final _searchCtrl = TextEditingController();
  final _discountCtrl = TextEditingController();
  final _tenderedCtrl = TextEditingController();
  MobileScannerController? _scannerController;
  
  String _selectedCategory = 'All';
  final List<String> _categories = ['All', 'Tools', 'Electrical', 'Plumbing', 'Paint', 'Fasteners'];

  @override
  void initState() {
    super.initState();
    if (widget.quotationId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _loadQuotation(widget.quotationId!);
      });
    }
  }

  Future<void> _loadQuotation(String id) async {
    try {
      final details = await ref.read(quotationRepositoryProvider).getQuotationDetails(id);
      final items = details['quotation_items'] as List;
      
      final cartItems = items.map((item) {
        return CartItem(
          productId: item['product_id'],
          productName: item['products']['name'],
          productUnitId: item['product_unit_id'],
          unitName: item['product_units']['name'],
          unitPrice: (item['unit_price'] as num).toDouble(),
          quantity: item['quantity'],
          discount: (item['discount'] as num).toDouble(),
        );
      }).toList();

      ref.read(cartProvider.notifier).loadCart(cartItems);
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Loaded Quotation ${details["invoice_no"]}')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load quotation: $e', style: const TextStyle(color: AppTheme.danger))),
      );
    }
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _discountCtrl.dispose();
    _tenderedCtrl.dispose();
    _scannerController?.dispose();
    super.dispose();
  }

  // ── Checkout ──────────────────────────────────────────────────────────────
  void _openCheckoutDialog() {
    final cart = ref.read(cartProvider);
    if (cart.isEmpty) {
      _showSnack('Cart is empty', isError: true);
      return;
    }

    final settings = ref.read(shopSettingsProvider).value;
    final subtotal = ref.read(cartProvider.notifier).subtotal;
    final billDiscount = ref.read(_billDiscountProvider);
    final taxAmount = settings?.taxAmountFor(subtotal) ?? 0;
    final grandTotal = subtotal - billDiscount + taxAmount;

    context.push(
      AppRoutes.checkout,
      extra: {
        'subtotal': subtotal,
        'discount': billDiscount,
        'taxAmount': taxAmount,
        'grandTotal': grandTotal,
      },
    ).then((success) {
      if (success == true) {
        ref.read(_searchQueryProvider.notifier).state = '';
        ref.read(_billDiscountProvider.notifier).state = 0;
        ref.read(_cashTenderedProvider.notifier).state = 0;
        _searchCtrl.clear();
        _discountCtrl.clear();
        _tenderedCtrl.clear();
      }
    });
  }

  // ── Hold / Park current cart ──────────────────────────────────────────────
  void _holdCart() {
    final cart = ref.read(cartProvider);
    if (cart.isEmpty) return;
    ref.read(parkedCartsProvider.notifier).park(cart);
    ref.read(cartProvider.notifier).clearCart();
    ref.read(_billDiscountProvider.notifier).state = 0;
    ref.read(_cashTenderedProvider.notifier).state = 0;
    _discountCtrl.clear();
    _tenderedCtrl.clear();
    _showSnack('Sale held. Start new sale.');
  }

  // ── Show parked carts bottom sheet ────────────────────────────────────────
  void _showParkedCarts() {
    final parked = ref.read(parkedCartsProvider);
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _ParkedCartsSheet(
        parkedCarts: parked,
        onRestore: (index) {
          final cart =
              ref.read(parkedCartsProvider.notifier).restore(index);
          ref.read(cartProvider.notifier).loadCart(cart);
          Navigator.pop(context);
          _showSnack('Sale restored.');
        },
        onDiscard: (index) {
          ref.read(parkedCartsProvider.notifier).remove(index);
          Navigator.pop(context);
          _showParkedCarts(); // refresh sheet
        },
      ),
    );
  }

  // ── Barcode scanner ───────────────────────────────────────────────────────
  void _openBarcodeScanner() {
    _scannerController = MobileScannerController(
      detectionSpeed: DetectionSpeed.noDuplicates,
    );

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.black,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SizedBox(
        height: MediaQuery.of(context).size.height * 0.55,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Scan Barcode',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600)),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () {
                      _scannerController?.dispose();
                      Navigator.pop(context);
                    },
                  ),
                ],
              ),
            ),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: MobileScanner(
                  controller: _scannerController!,
                  onDetect: (capture) {
                    final barcode =
                        capture.barcodes.firstOrNull?.rawValue;
                    if (barcode != null && barcode.isNotEmpty) {
                      _scannerController?.dispose();
                      Navigator.pop(context);
                      _searchCtrl.text = barcode;
                      ref.read(_searchQueryProvider.notifier).state =
                          barcode;
                    }
                  },
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Point camera at a product barcode',
                style: TextStyle(color: Colors.white60, fontSize: 13),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    ).then((_) => _scannerController?.dispose());
  }

  void _confirmClearCart() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Clear Cart'),
        content: const Text('Are you sure you want to remove all items from the current sale?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: AppTheme.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.danger),
            onPressed: () {
              ref.read(cartProvider.notifier).clearCart();
              ref.read(_billDiscountProvider.notifier).state = 0;
              ref.read(_cashTenderedProvider.notifier).state = 0;
              _discountCtrl.clear();
              _tenderedCtrl.clear();
              Navigator.pop(ctx);
            },
            child: const Text('Clear'),
          ),
        ],
      ),
    );
  }

  void _showSnack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? AppTheme.danger : AppTheme.accent,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cart = ref.watch(cartProvider);
    final searchResults = ref.watch(_productSearchProvider);
    final billDiscount = ref.watch(_billDiscountProvider);
    final parkedCount = ref.watch(parkedCartsProvider).length;
    final settingsAsync = ref.watch(shopSettingsProvider);
    final settings = settingsAsync.value;

    final subtotal = ref.read(cartProvider.notifier).subtotal;
    final taxAmount = settings?.taxAmountFor(subtotal) ?? 0;
    final grandTotal = subtotal - billDiscount + taxAmount;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Point of Sale', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 18)),
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
          if (parkedCount > 0)
            Stack(
              alignment: Alignment.topRight,
              children: [
                IconButton(
                  icon: const Icon(Icons.pause_circle_outline_rounded),
                  tooltip: 'Held Sales',
                  onPressed: _showParkedCarts,
                ),
                Positioned(
                  right: 6,
                  top: 6,
                  child: Container(
                    width: 16,
                    height: 16,
                    decoration: const BoxDecoration(
                      color: AppTheme.warning,
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '$parkedCount',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ],
            ),
          if (cart.isNotEmpty)
            TextButton(
              onPressed: _holdCart,
              style: TextButton.styleFrom(foregroundColor: AppTheme.textPrimary),
              child: const Text('Hold Sale', style: TextStyle(fontWeight: FontWeight.w600)),
            ),
          if (cart.isNotEmpty)
            TextButton(
              onPressed: _confirmClearCart,
              style: TextButton.styleFrom(foregroundColor: AppTheme.textSecondary),
              child: const Text('Clear'),
            ),
        ],
      ),
      body: Column(
        children: [
          // ─── Search + Scanner Bar ────────────────────────────────────
          Container(
            color: AppTheme.surface,
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchCtrl,
                    style: const TextStyle(color: AppTheme.textPrimary, fontSize: 15),
                    decoration: InputDecoration(
                      hintText: 'Search product or scan barcode',
                      hintStyle: const TextStyle(color: AppTheme.textHint, fontSize: 14),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      fillColor: AppTheme.background,
                      filled: true,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      prefixIcon: const Icon(Icons.search_rounded, color: AppTheme.textHint, size: 22),
                      suffixIcon: _searchCtrl.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.cancel_rounded, color: AppTheme.textHint, size: 20),
                              onPressed: () {
                                _searchCtrl.clear();
                                ref.read(_searchQueryProvider.notifier).state = '';
                              },
                            )
                          : null,
                    ),
                    onChanged: (v) => ref.read(_searchQueryProvider.notifier).state = v,
                  ),
                ),
                const SizedBox(width: 12),
                Material(
                  color: AppTheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: _openBarcodeScanner,
                    child: Container(
                      width: 48,
                      height: 48,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        border: Border.all(color: AppTheme.primary.withValues(alpha: 0.2)),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.qr_code_scanner_rounded, color: AppTheme.primary, size: 24),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ─── Categories ────────────────────────────────────
          Container(
            color: AppTheme.surface,
            padding: const EdgeInsets.fromLTRB(20, 0, 0, 12),
            child: SizedBox(
              height: 36,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _categories.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, i) {
                  final cat = _categories[i];
                  final isSelected = _selectedCategory == cat;
                  return ChoiceChip(
                    label: Text(cat),
                    selected: isSelected,
                    onSelected: (val) {
                      setState(() => _selectedCategory = cat);
                      // In a real scenario, this would filter the search results too.
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
          Container(height: 1, color: AppTheme.border), // Divider

          // ─── Main Content Area ────────────────────────────────────
          Expanded(
            child: _searchCtrl.text.isNotEmpty
                // 1. Search Results State
                ? searchResults.when(
                    loading: () => const Center(child: CircularProgressIndicator()),
                    error: (e, _) => Center(child: Text('Error: $e', style: const TextStyle(color: AppTheme.danger))),
                    data: (products) {
                      if (products.isEmpty) {
                        return const Center(child: Text('No products found', style: TextStyle(color: AppTheme.textHint)));
                      }
                      return ListView.separated(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                        itemCount: products.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (context, i) {
                          final p = products[i];
                          return Material(
                            color: AppTheme.surface,
                            borderRadius: BorderRadius.circular(16),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(16),
                              onTap: () {
                                HapticFeedback.lightImpact();
                                ref.read(cartProvider.notifier).addItem(p);
                                _searchCtrl.clear();
                                ref.read(_searchQueryProvider.notifier).state = '';
                              },
                              child: Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: AppTheme.border, width: 0.5),
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(p.name, style: const TextStyle(color: AppTheme.textPrimary, fontSize: 15, fontWeight: FontWeight.w600)),
                                          const SizedBox(height: 6),
                                          Row(
                                            children: [
                                              if (p.sku != null && p.sku!.isNotEmpty) ...[
                                                Text('SKU: ${p.sku}', style: const TextStyle(color: AppTheme.textHint, fontSize: 12)),
                                                const SizedBox(width: 12),
                                              ],
                                              Text(p.categoryName ?? '', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        Text(p.sellingPriceBase.toCurrency(), style: const TextStyle(color: AppTheme.textPrimary, fontSize: 15, fontWeight: FontWeight.w700)),
                                        const SizedBox(height: 4),
                                        Text(
                                          'Stock: ${p.baseStockQuantity}',
                                          style: TextStyle(color: p.isLowStock ? AppTheme.danger : AppTheme.success, fontSize: 12, fontWeight: FontWeight.w600),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(width: 16),
                                    Container(
                                      width: 36,
                                      height: 36,
                                      decoration: BoxDecoration(color: AppTheme.primary, borderRadius: BorderRadius.circular(10)),
                                      child: const Icon(Icons.add, color: Colors.white, size: 20),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      );
                    },
                  )
                // 2. Empty Cart State
                : cart.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(24),
                              decoration: BoxDecoration(
                                color: AppTheme.primary.withValues(alpha: 0.05),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.shopping_cart_outlined, size: 48, color: AppTheme.primary),
                            ),
                            const SizedBox(height: 24),
                            const Text(
                              'No products added yet',
                              style: TextStyle(color: AppTheme.textPrimary, fontSize: 18, fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Search or scan barcode to start billing',
                              style: TextStyle(color: AppTheme.textSecondary, fontSize: 14),
                            ),
                          ],
                        ),
                      )
                    // 3. Cart Preview State
                    : ListView(
                        padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
                        children: [
                          const Text('Current Sale', style: TextStyle(color: AppTheme.textPrimary, fontSize: 16, fontWeight: FontWeight.w700)),
                          const SizedBox(height: 12),
                          ...cart.take(4).map((item) {
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: _CartItemTile(
                                item: item,
                                onIncrease: () {
                                  HapticFeedback.lightImpact();
                                  ref.read(cartProvider.notifier).updateQuantity(item.productId, item.quantity + 1);
                                },
                                onDecrease: () {
                                  HapticFeedback.lightImpact();
                                  ref.read(cartProvider.notifier).updateQuantity(item.productId, item.quantity - 1);
                                },
                                onRemove: () => ref.read(cartProvider.notifier).removeItem(item.productId),
                              ),
                            );
                          }),
                          if (cart.length > 4)
                            Center(
                              child: TextButton(
                                onPressed: () {
                                  // This could open the bottom sheet directly
                                },
                                child: Text('View all ${cart.length} items', style: const TextStyle(fontWeight: FontWeight.w600)),
                              ),
                            )
                        ],
                      ),
          ),
        ],
      ),
      bottomNavigationBar: cart.isEmpty
          ? const SizedBox.shrink()
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                child: Material(
                  color: AppTheme.primary,
                  borderRadius: BorderRadius.circular(18),
                  elevation: 6,
                  shadowColor: AppTheme.primary.withValues(alpha: 0.4),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(18),
                    onTap: () {
                      showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        backgroundColor: AppTheme.background,
                        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
                        builder: (context) => _CartBottomSheet(
                          onCheckout: () {
                            Navigator.pop(context); // Close sheet
                            _openCheckoutDialog(); // Open payment dialog
                          },
                        ),
                      );
                    },
                    child: Container(
                      height: 68,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(10)),
                            child: Text('${cart.length}', style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Total', style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w500)),
                                Text(grandTotal.toCurrency(), style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
                              ],
                            ),
                          ),
                          const Text('Review & Checkout', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600)),
                          const SizedBox(width: 6),
                          const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white, size: 16),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
    );
  }
}

class _CartBottomSheet extends ConsumerWidget {
  final VoidCallback onCheckout;
  const _CartBottomSheet({required this.onCheckout});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cart = ref.watch(cartProvider);
    final subtotal = ref.read(cartProvider.notifier).subtotal;
    final billDiscount = ref.read(_billDiscountProvider);
    final settingsAsync = ref.watch(shopSettingsProvider);
    final settings = settingsAsync.value;
    final taxAmount = settings?.taxAmountFor(subtotal) ?? 0;
    final grandTotal = subtotal - billDiscount + taxAmount;
    
    // Dynamic height based on items
    final double sheetHeight = cart.length <= 3 
      ? MediaQuery.of(context).size.height * 0.55 
      : MediaQuery.of(context).size.height * 0.85;

    return Container(
      height: sheetHeight,
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Column(
        children: [
          Container(width: 48, height: 5, decoration: BoxDecoration(color: AppTheme.border, borderRadius: BorderRadius.circular(3))),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Text('Current Sale', style: TextStyle(color: AppTheme.textPrimary, fontSize: 20, fontWeight: FontWeight.w700)),
                  const SizedBox(width: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(color: AppTheme.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                    child: Text('${cart.length} items', style: const TextStyle(color: AppTheme.primary, fontSize: 12, fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
              IconButton(icon: const Icon(Icons.close_rounded, color: AppTheme.textHint), onPressed: () => Navigator.pop(context)),
            ],
          ),
          const SizedBox(height: 8),
          const Divider(color: AppTheme.border, height: 1),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 16),
              itemCount: cart.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, i) => _CartItemTile(
                item: cart[i],
                onIncrease: () {
                  HapticFeedback.lightImpact();
                  ref.read(cartProvider.notifier).updateQuantity(cart[i].productId, cart[i].quantity + 1);
                },
                onDecrease: () {
                  HapticFeedback.lightImpact();
                  ref.read(cartProvider.notifier).updateQuantity(cart[i].productId, cart[i].quantity - 1);
                },
                onRemove: () => ref.read(cartProvider.notifier).removeItem(cart[i].productId),
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(0, 16, 0, 24),
            decoration: const BoxDecoration(
              color: AppTheme.background,
              border: Border(top: BorderSide(color: AppTheme.border)),
            ),
            child: SafeArea(
              child: Column(
                children: [
                  _TotalRow(label: 'Subtotal', value: subtotal.toCurrency()),
                  const SizedBox(height: 8),
                  if (billDiscount > 0) ...[
                    _TotalRow(label: 'Discount', value: '-${billDiscount.toCurrency()}', valueColor: AppTheme.success),
                    const SizedBox(height: 8),
                  ],
                  if (taxAmount > 0) ...[
                    _TotalRow(label: 'Tax', value: taxAmount.toCurrency()),
                    const SizedBox(height: 8),
                  ],
                  const Divider(color: AppTheme.border, height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Total', style: TextStyle(color: AppTheme.textPrimary, fontSize: 18, fontWeight: FontWeight.w700)),
                      Text(grandTotal.toCurrency(), style: const TextStyle(color: AppTheme.primary, fontSize: 22, fontWeight: FontWeight.w800)),
                    ],
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: cart.isEmpty ? null : onCheckout,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      minimumSize: const Size(double.infinity, 56),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 0,
                    ),
                    child: const Text('Proceed to Checkout', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Parked Carts Bottom Sheet ────────────────────────────────────────────────
class _ParkedCartsSheet extends StatelessWidget {
  final List<List<CartItem>> parkedCarts;
  final void Function(int) onRestore;
  final void Function(int) onDiscard;

  const _ParkedCartsSheet({
    required this.parkedCarts,
    required this.onRestore,
    required this.onDiscard,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Held Sales',
              style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 16),
          if (parkedCarts.isEmpty)
            const Center(
              child: Text('No held sales',
                  style: TextStyle(color: AppTheme.textSecondary)),
            )
          else
            ...parkedCarts.asMap().entries.map((entry) {
              final i = entry.key;
              final cart = entry.value;
              final total = cart.fold<double>(0, (s, e) => s + e.lineTotal);
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.border, width: 0.5),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Sale #${i + 1}',
                              style: const TextStyle(
                                  color: AppTheme.textPrimary,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600)),
                          const SizedBox(height: 4),
                          Text(
                              '${cart.length} items · ${total.toCurrency()}',
                              style: const TextStyle(
                                  color: AppTheme.textSecondary,
                                  fontSize: 13)),
                        ],
                      ),
                    ),
                    TextButton(
                      onPressed: () => onDiscard(i),
                      style: TextButton.styleFrom(
                          foregroundColor: AppTheme.danger),
                      child: const Text('Discard'),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () => onRestore(i),
                      style: ElevatedButton.styleFrom(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: const Text('Restore'),
                    ),
                  ],
                ),
              );
            }),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

// ─── Total Row Helper ─────────────────────────────────────────────────────────
class _TotalRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isBold;
  final Color? color;
  final Color? valueColor;

  const _TotalRow({
    required this.label,
    required this.value,
    this.isBold = false,
    this.color,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: TextStyle(
              color: color ?? AppTheme.textSecondary,
              fontSize: isBold ? 16 : 14,
              fontWeight: isBold ? FontWeight.w700 : FontWeight.w500,
            )),
        Text(value,
            style: TextStyle(
              color: valueColor ?? AppTheme.textPrimary,
              fontSize: isBold ? 18 : 15,
              fontWeight: isBold ? FontWeight.w700 : FontWeight.w600,
            )),
      ],
    );
  }
}

// ─── Cart Item Tile ───────────────────────────────────────────────────────────
class _CartItemTile extends StatelessWidget {
  final CartItem item;
  final VoidCallback onIncrease;
  final VoidCallback onDecrease;
  final VoidCallback onRemove;

  const _CartItemTile({
    required this.item,
    required this.onIncrease,
    required this.onDecrease,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border, width: 0.5),
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
                    Text(item.productName,
                        style: const TextStyle(
                            color: AppTheme.textPrimary,
                            fontSize: 15,
                            fontWeight: FontWeight.w600),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 4),
                    Text(item.unitPrice.toCurrency(),
                        style: const TextStyle(
                            color: AppTheme.textSecondary, fontSize: 13, fontWeight: FontWeight.w500)),
                  ],
                ),
              ),
              IconButton(
                onPressed: onRemove,
                icon: const Icon(Icons.delete_outline_rounded, size: 20, color: AppTheme.danger),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  _QtyBtn(icon: Icons.remove, onTap: onDecrease, color: AppTheme.textSecondary),
                  Container(
                    width: 40,
                    alignment: Alignment.center,
                    child: Text('${item.quantity}',
                        style: const TextStyle(
                            color: AppTheme.textPrimary,
                            fontSize: 16,
                            fontWeight: FontWeight.w600)),
                  ),
                  _QtyBtn(icon: Icons.add, onTap: onIncrease, color: AppTheme.primary),
                ],
              ),
              Text(item.lineTotal.toCurrency(),
                  style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w700)),
            ],
          ),
        ],
      ),
    );
  }
}

class _QtyBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final Color color;
  const _QtyBtn({required this.icon, required this.onTap, required this.color});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Icon(icon, size: 18, color: color),
      ),
    );
  }
}
