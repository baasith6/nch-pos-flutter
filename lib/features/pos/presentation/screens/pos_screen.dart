import 'package:flutter/material.dart';
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
          unitPrice: product.sellingPrice,
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
  const PosScreen({super.key});

  @override
  ConsumerState<PosScreen> createState() => _PosScreenState();
}

class _PosScreenState extends ConsumerState<PosScreen> {
  final _searchCtrl = TextEditingController();
  final _discountCtrl = TextEditingController();
  final _tenderedCtrl = TextEditingController();
  MobileScannerController? _scannerController;

  @override
  void dispose() {
    _searchCtrl.dispose();
    _discountCtrl.dispose();
    _tenderedCtrl.dispose();
    _scannerController?.dispose();
    super.dispose();
  }

  // ── Checkout ──────────────────────────────────────────────────────────────
  Future<void> _checkout() async {
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

    if (billDiscount >= subtotal) {
      _showSnack('Discount cannot exceed subtotal', isError: true);
      return;
    }

    final payment = ref.read(_selectedPaymentProvider);
    if (payment == AppConstants.paymentCash) {
      final tendered = ref.read(_cashTenderedProvider);
      if (tendered < grandTotal) {
        _showSnack('Cash tendered is less than grand total', isError: true);
        return;
      }
    }

    ref.read(_checkoutLoadingProvider.notifier).state = true;
    try {
      final result = await ref.read(salesRepositoryProvider).createSale(
            items: cart,
            paymentMethod: payment,
            billDiscount: billDiscount,
            taxAmount: taxAmount,
          );

      ref.read(cartProvider.notifier).clearCart();
      ref.read(_searchQueryProvider.notifier).state = '';
      ref.read(_billDiscountProvider.notifier).state = 0;
      ref.read(_cashTenderedProvider.notifier).state = 0;
      _searchCtrl.clear();
      _discountCtrl.clear();
      _tenderedCtrl.clear();

      if (!mounted) return;
      context.push(
        AppRoutes.receipt.replaceAll(':saleId', result['sale_id'] as String),
        extra: result,
      );
    } catch (e) {
      _showSnack(e.toString().replaceAll('Exception:', '').trim(),
          isError: true);
    } finally {
      if (mounted) ref.read(_checkoutLoadingProvider.notifier).state = false;
    }
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
      backgroundColor: AppTheme.cardDark,
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
        backgroundColor: AppTheme.cardDark,
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
          onPressed: () => context.pop(),
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
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchCtrl,
                    style: const TextStyle(color: AppTheme.textPrimary),
                    decoration: InputDecoration(
                      hintText: 'Search product or type barcode…',
                      prefixIcon: const Icon(Icons.search,
                          color: AppTheme.textHint, size: 20),
                      suffixIcon: _searchCtrl.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear,
                                  color: AppTheme.textHint, size: 18),
                              onPressed: () {
                                _searchCtrl.clear();
                                ref
                                    .read(_searchQueryProvider.notifier)
                                    .state = '';
                              },
                            )
                          : null,
                    ),
                    onChanged: (v) =>
                        ref.read(_searchQueryProvider.notifier).state = v,
                  ),
                ),
                const SizedBox(width: 8),
                // Camera barcode scanner button
                GestureDetector(
                  onTap: _openBarcodeScanner,
                  child: Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: AppTheme.primary.withValues(alpha: 0.3)),
                    ),
                    child: const Icon(Icons.qr_code_scanner_rounded,
                        color: AppTheme.primary, size: 22),
                  ),
                ),
              ],
            ),
          ),

          // ─── Search Results ──────────────────────────────────────────
          searchResults.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(8),
              child: LinearProgressIndicator(),
            ),
            error: (e, _) => Padding(
              padding: const EdgeInsets.all(8),
              child: Text('Error: $e',
                  style: const TextStyle(color: AppTheme.danger)),
            ),
            data: (products) =>
                products.isEmpty && _searchCtrl.text.isNotEmpty
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: Text('No products found',
                            style: TextStyle(
                                color: AppTheme.textSecondary)),
                      )
                    : products.isNotEmpty
                        ? Container(
                            constraints:
                                const BoxConstraints(maxHeight: 220),
                            margin: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppTheme.elevatedDark,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                  color: AppTheme.borderDark),
                            ),
                            child: ListView.separated(
                              shrinkWrap: true,
                              itemCount: products.length,
                              separatorBuilder: (_, __) =>
                                  const Divider(height: 1),
                              itemBuilder: (context, i) {
                                final p = products[i];
                                return ListTile(
                                  dense: true,
                                  title: Text(p.name,
                                      style: const TextStyle(
                                          color: AppTheme.textPrimary,
                                          fontSize: 14)),
                                  subtitle: Text(
                                      p.sellingPrice.toCurrency(),
                                      style: const TextStyle(
                                          color: AppTheme.accent,
                                          fontSize: 12)),
                                  trailing: Text(
                                    'Stock: ${p.stockQuantity}',
                                    style: TextStyle(
                                      color: p.isLowStock
                                          ? AppTheme.warning
                                          : AppTheme.textHint,
                                      fontSize: 11,
                                    ),
                                  ),
                                  onTap: () {
                                    ref
                                        .read(cartProvider.notifier)
                                        .addItem(p);
                                    _searchCtrl.clear();
                                    ref
                                        .read(_searchQueryProvider
                                            .notifier)
                                        .state = '';
                                  },
                                );
                              },
                            ),
                          )
                        : const SizedBox(),
          ),

          // ─── Cart List ───────────────────────────────────────────────
          Expanded(
            child: cart.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.shopping_cart_outlined,
                            size: 60,
                            color: AppTheme.textHint.withValues(alpha: 0.4)),
                        const SizedBox(height: 12),
                        const Text('Cart is empty',
                            style: TextStyle(color: AppTheme.textHint)),
                        const Text('Search or scan a product to add',
                            style: TextStyle(
                                color: AppTheme.textHint, fontSize: 12)),
                      ],
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: cart.length,
                    separatorBuilder: (_, __) =>
                        const SizedBox(height: 8),
                    itemBuilder: (context, i) => _CartItemTile(
                      item: cart[i],
                      onIncrease: () => ref
                          .read(cartProvider.notifier)
                          .updateQuantity(
                              cart[i].productId, cart[i].quantity + 1),
                      onDecrease: () => ref
                          .read(cartProvider.notifier)
                          .updateQuantity(
                              cart[i].productId, cart[i].quantity - 1),
                      onRemove: () => ref
                          .read(cartProvider.notifier)
                          .removeItem(cart[i].productId),
                    ),
                  ),
          ),

          // ─── Checkout Panel ──────────────────────────────────────────
          if (cart.isNotEmpty)
            Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              decoration: BoxDecoration(
                color: AppTheme.surfaceDark,
                border:
                    const Border(top: BorderSide(color: AppTheme.borderDark)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Payment method chips
                  Consumer(
                    builder: (ctx, ref2, _) {
                      final methodsAsync = ref2.watch(paymentMethodsProvider);
                      final methods = methodsAsync.value ??
                          [
                            AppConstants.paymentCash,
                            AppConstants.paymentCard,
                            AppConstants.paymentTransfer
                          ];
                      return SizedBox(
                        width: double.infinity,
                        child: Wrap(
                          spacing: 8,
                          children: methods
                              .map((method) => ChoiceChip(
                                    label: Text(method,
                                        style:
                                            const TextStyle(fontSize: 12)),
                                    selected: payment == method,
                                    onSelected: (_) {
                                      ref
                                          .read(_selectedPaymentProvider
                                              .notifier)
                                          .state = method;
                                      if (method !=
                                          AppConstants.paymentCash) {
                                        ref
                                            .read(
                                                _cashTenderedProvider.notifier)
                                            .state = 0;
                                        _tenderedCtrl.clear();
                                      }
                                    },
                                    selectedColor: AppTheme.primary
                                        .withValues(alpha: 0.2),
                                  ))
                              .toList(),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 10),

                  // Totals
                  _TotalRow(
                      label: 'Subtotal', value: subtotal.toCurrency()),
                  if (billDiscount > 0) ...[
                    const SizedBox(height: 3),
                    _TotalRow(
                        label: 'Discount',
                        value: '- ${billDiscount.toCurrency()}',
                        color: AppTheme.warning),
                  ],
                  if (taxAmount > 0) ...[
                    const SizedBox(height: 3),
                    _TotalRow(
                      label: settings != null
                          ? 'Tax (${settings.taxPercentage.toStringAsFixed(1)}%)'
                          : 'Tax',
                      value: taxAmount.toCurrency(),
                      color: AppTheme.textSecondary,
                    ),
                  ],
                  const Divider(height: 14),
                  _TotalRow(
                    label: 'Grand Total',
                    value: grandTotal.toCurrency(),
                    isBold: true,
                    valueColor: AppTheme.accent,
                  ),

                  // Cash tendered
                  if (payment == AppConstants.paymentCash) ...[
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _tenderedCtrl,
                            keyboardType:
                                const TextInputType.numberWithOptions(
                                    decimal: true),
                            style: const TextStyle(
                                color: AppTheme.textPrimary),
                            decoration: InputDecoration(
                              labelText: 'Cash Tendered',
                              labelStyle: const TextStyle(
                                  color: AppTheme.textSecondary,
                                  fontSize: 13),
                              isDense: true,
                              contentPadding:
                                  const EdgeInsets.symmetric(
                                      vertical: 10, horizontal: 12),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: const BorderSide(
                                    color: AppTheme.borderDark),
                              ),
                            ),
                            onChanged: (v) {
                              ref
                                  .read(_cashTenderedProvider.notifier)
                                  .state = double.tryParse(v) ?? 0;
                            },
                          ),
                        ),
                        if (cashTendered > 0) ...[
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              const Text('Change Due',
                                  style: TextStyle(
                                      color: AppTheme.textSecondary,
                                      fontSize: 11)),
                              Text(
                                changeDue >= 0
                                    ? changeDue.toCurrency()
                                    : '- ${(-changeDue).toCurrency()}',
                                style: TextStyle(
                                  color: changeDue >= 0
                                      ? AppTheme.accent
                                      : AppTheme.danger,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                    if (isCashShort)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Row(
                          children: [
                            const Icon(Icons.warning_amber_rounded,
                                color: AppTheme.danger, size: 14),
                            const SizedBox(width: 4),
                            Text(
                              'Need ${(-changeDue).toCurrency()} more',
                              style: const TextStyle(
                                  color: AppTheme.danger, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                  ],

                  const SizedBox(height: 10),

                  // Discount + Checkout buttons
                  Row(
                    children: [
                      OutlinedButton.icon(
                        onPressed: () => _showDiscountDialog(subtotal),
                        icon: const Icon(Icons.discount_outlined, size: 16),
                        label: billDiscount > 0
                            ? Text('- ${billDiscount.toCurrency()}',
                                style: const TextStyle(
                                    color: AppTheme.warning))
                            : const Text('Discount'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: billDiscount > 0
                              ? AppTheme.warning
                              : AppTheme.textSecondary,
                          side: BorderSide(
                            color: billDiscount > 0
                                ? AppTheme.warning.withValues(alpha: 0.5)
                                : AppTheme.borderDark,
                          ),
                          minimumSize: const Size(0, 48),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed:
                              (isLoading || isCashShort) ? null : _checkout,
                          icon: isLoading
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2, color: Colors.white))
                              : const Icon(
                                  Icons.check_circle_outline_rounded),
                          label:
                              Text(isLoading ? 'Processing…' : 'Checkout'),
                          style: ElevatedButton.styleFrom(
                            minimumSize: const Size(double.infinity, 48),
                            backgroundColor: AppTheme.accent,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
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
                  color: AppTheme.elevatedDark,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.borderDark),
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
        color: AppTheme.cardDark,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.borderDark, width: 0.5),
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
