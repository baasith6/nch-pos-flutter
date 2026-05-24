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
          productUnitId: product.baseUnitId ?? 'unknown',
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
        SnackBar(content: Text('Failed to load quotation: \$e', style: const TextStyle(color: AppTheme.danger))),
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
    _showSnack('Cart held. Start new sale.');
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
          _showSnack('Cart restored.');
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

  // ── Discount dialog ───────────────────────────────────────────────────────
  void _showDiscountDialog(double subtotal) {
    _discountCtrl.text = ref.read(_billDiscountProvider) == 0
        ? ''
        : ref.read(_billDiscountProvider).toStringAsFixed(2);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: const Text('Bill Discount',
            style: TextStyle(color: AppTheme.textPrimary)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Max allowed: ${subtotal.toCurrency()}',
              style:
                  const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _discountCtrl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              autofocus: true,
              style: const TextStyle(color: AppTheme.textPrimary),
              decoration: const InputDecoration(
                labelText: 'Discount Amount',
                labelStyle: TextStyle(color: AppTheme.textSecondary),
                prefixIcon: Icon(Icons.discount_outlined,
                    color: AppTheme.textHint, size: 18),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              ref.read(_billDiscountProvider.notifier).state = 0;
              _discountCtrl.clear();
              Navigator.pop(ctx);
            },
            child: const Text('Clear'),
          ),
          ElevatedButton(
            onPressed: () {
              final val = double.tryParse(_discountCtrl.text) ?? 0.0;
              final clamped =
                  val >= subtotal ? (subtotal > 0 ? subtotal - 0.01 : 0.0) : val;
              if (val >= subtotal) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text(
                      'Discount clamped to ${clamped.toCurrency()} (cannot equal or exceed subtotal)'),
                  backgroundColor: AppTheme.warning,
                ));
              }
              ref.read(_billDiscountProvider.notifier).state = clamped;
              Navigator.pop(ctx);
            },
            child: const Text('Apply'),
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
    final payment = ref.watch(_selectedPaymentProvider);
    final billDiscount = ref.watch(_billDiscountProvider);
    final isLoading = ref.watch(_checkoutLoadingProvider);
    final parkedCount = ref.watch(parkedCartsProvider).length;
    final settingsAsync = ref.watch(shopSettingsProvider);
    final settings = settingsAsync.value;

    final subtotal = ref.read(cartProvider.notifier).subtotal;
    final taxAmount = settings?.taxAmountFor(subtotal) ?? 0;
    final grandTotal = subtotal - billDiscount + taxAmount;

    final cashTendered = ref.watch(_cashTenderedProvider);
    final changeDue = cashTendered - grandTotal;
    final isCashShort = payment == AppConstants.paymentCash &&
        cashTendered < grandTotal &&
        cart.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Point of Sale'),
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
        actions: [
          // Parked carts badge
          if (parkedCount > 0)
            Stack(
              alignment: Alignment.topRight,
              children: [
                IconButton(
                  icon: const Icon(Icons.pause_circle_outline_rounded),
                  tooltip: 'Parked Sales',
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
            IconButton(
              icon: const Icon(Icons.pause_outlined),
              tooltip: 'Hold Sale',
              onPressed: _holdCart,
            ),
          if (cart.isNotEmpty)
            TextButton.icon(
              onPressed: () {
                ref.read(cartProvider.notifier).clearCart();
                ref.read(_billDiscountProvider.notifier).state = 0;
                ref.read(_cashTenderedProvider.notifier).state = 0;
                _discountCtrl.clear();
                _tenderedCtrl.clear();
              },
              icon: const Icon(Icons.delete_sweep_outlined, size: 18),
              label: const Text('Clear'),
              style:
                  TextButton.styleFrom(foregroundColor: AppTheme.danger),
            ),
        ],
      ),
      body: Column(
        children: [
          // ─── Search + Scanner Bar ────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchCtrl,
                    style: const TextStyle(color: AppTheme.slateText),
                    decoration: InputDecoration(
                      hintText: 'Search product or type barcode…',
                      prefixIcon: const Icon(Icons.search, color: AppTheme.mutedText, size: 20),
                      suffixIcon: _searchCtrl.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, color: AppTheme.mutedText, size: 18),
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
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: _openBarcodeScanner,
                  child: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.primary.withValues(alpha: 0.2)),
                    ),
                    child: const Icon(Icons.qr_code_scanner_rounded, color: AppTheme.primary, size: 22),
                  ),
                ),
              ],
            ),
          ),

          // ─── Products List / Grid ────────────────────────────────────
          Expanded(
            child: searchResults.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e', style: const TextStyle(color: AppTheme.danger))),
              data: (products) {
                if (products.isEmpty && _searchCtrl.text.isNotEmpty) {
                  return const Center(child: Text('No products found', style: TextStyle(color: AppTheme.mutedText)));
                }
                if (products.isEmpty) {
                   return const Center(child: Text('Search to add products', style: TextStyle(color: AppTheme.mutedText)));
                }
                return ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: products.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, i) {
                    final p = products[i];
                    return GestureDetector(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        ref.read(cartProvider.notifier).addItem(p);
                        _searchCtrl.clear();
                        ref.read(_searchQueryProvider.notifier).state = '';
                      },
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppTheme.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppTheme.border),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(p.name, style: const TextStyle(color: AppTheme.slateText, fontSize: 14, fontWeight: FontWeight.w600)),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      if (p.sku != null && p.sku!.isNotEmpty) ...[
                                        Text('SKU: ${p.sku}', style: const TextStyle(color: AppTheme.mutedText, fontSize: 11, fontFamily: 'monospace')),
                                        const SizedBox(width: 8),
                                      ],
                                      Text(p.categoryName ?? '', style: const TextStyle(color: AppTheme.mutedText, fontSize: 11)),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(p.sellingPriceBase.toCurrency(), style: const TextStyle(color: AppTheme.slateText, fontSize: 15, fontWeight: FontWeight.w700)),
                                const SizedBox(height: 2),
                                Text(
                                  'Stock: ${p.baseStockQuantity} ${p.baseUnitName ?? ''}',
                                  style: TextStyle(color: p.isLowStock ? AppTheme.danger : AppTheme.success, fontSize: 11, fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                            const SizedBox(width: 12),
                            Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: AppTheme.primary,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(Icons.add, color: Colors.white, size: 18),
                            ),
                          ],
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
      bottomNavigationBar: cart.isEmpty ? const SizedBox.shrink() : SafeArea(
        child: InkWell(
          onTap: () {
            showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              backgroundColor: AppTheme.background,
              shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
              builder: (context) => _CartBottomSheet(
                onCheckout: () {
                  Navigator.pop(context); // Close sheet
                  _openCheckoutDialog(); // Open payment dialog
                },
              ),
            );
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AppTheme.primary,
              boxShadow: [
                BoxShadow(color: AppTheme.primary.withValues(alpha: 0.3), blurRadius: 10, offset: const Offset(0, -2))
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(8)),
                  child: Text('${cart.length} items', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                ),
                const SizedBox(width: 12),
                Text(grandTotal.toCurrency(), style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
                const Spacer(),
                const Text('View Cart', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600)),
                const SizedBox(width: 4),
                const Icon(Icons.keyboard_arrow_up_rounded, color: Colors.white),
              ],
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
    
    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Column(
        children: [
          Container(width: 40, height: 4, decoration: BoxDecoration(color: AppTheme.border, borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Current Cart', style: TextStyle(color: AppTheme.slateText, fontSize: 20, fontWeight: FontWeight.w700)),
              IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
            ],
          ),
          const Divider(),
          Expanded(
            child: cart.isEmpty
                ? const Center(child: Text('Cart is empty', style: TextStyle(color: AppTheme.mutedText)))
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: cart.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
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
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: AppTheme.surface,
              border: Border(top: BorderSide(color: AppTheme.border)),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Subtotal', style: TextStyle(color: AppTheme.mutedText, fontSize: 14)),
                    Text(subtotal.toCurrency(), style: const TextStyle(color: AppTheme.slateText, fontSize: 16, fontWeight: FontWeight.w600)),
                  ],
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: cart.isEmpty ? null : onCheckout,
                  icon: const Icon(Icons.shopping_cart_checkout),
                  label: const Text('Proceed to Checkout'),
                ),
                const SizedBox(height: 16),
              ],
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
                  fontSize: 16,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 14),
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
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.border),
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
                                  fontWeight: FontWeight.w600)),
                          Text(
                              '${cart.length} items · ${total.toCurrency()}',
                              style: const TextStyle(
                                  color: AppTheme.textSecondary,
                                  fontSize: 12)),
                        ],
                      ),
                    ),
                    TextButton(
                      onPressed: () => onDiscard(i),
                      style: TextButton.styleFrom(
                          foregroundColor: AppTheme.danger),
                      child: const Text('Discard'),
                    ),
                    const SizedBox(width: 4),
                    ElevatedButton(
                      onPressed: () => onRestore(i),
                      child: const Text('Restore'),
                    ),
                  ],
                ),
              );
            }),
          const SizedBox(height: 8),
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
              fontSize: isBold ? 18 : 13,
              fontWeight: isBold ? FontWeight.w700 : FontWeight.normal,
            )),
        Text(value,
            style: TextStyle(
              color: valueColor ?? AppTheme.textPrimary,
              fontSize: isBold ? 20 : 13,
              fontWeight: isBold ? FontWeight.w700 : FontWeight.normal,
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
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border, width: 1),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.productName,
                    style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w500),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Text(item.unitPrice.toCurrency(),
                    style: const TextStyle(
                        color: AppTheme.textSecondary, fontSize: 12)),
              ],
            ),
          ),
          Row(
            children: [
              _QtyBtn(icon: Icons.remove, onTap: onDecrease, color: AppTheme.danger),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text('${item.quantity}',
                    style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w600)),
              ),
              _QtyBtn(icon: Icons.add, onTap: onIncrease, color: AppTheme.accent),
            ],
          ),
          const SizedBox(width: 12),
          Text(item.lineTotal.toCurrency(),
              style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w600)),
          const SizedBox(width: 8),
          IconButton(
            onPressed: onRemove,
            icon: const Icon(Icons.close, size: 18, color: AppTheme.textHint),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
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
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Icon(icon, size: 16, color: color),
      ),
    );
  }
}
