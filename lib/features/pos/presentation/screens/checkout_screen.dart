import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import '../../../../app/router.dart';
import '../../../../app/theme.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/extensions/extensions.dart';
import '../../../../core/services/local_db_service.dart';
import '../../../sales/data/models/sale_model.dart';
import '../../../sales/data/repositories/sales_repository.dart';
import '../../../settings/data/repositories/payment_method_repository.dart';
import '../../../customers/data/models/customer_model.dart';
import '../screens/pos_screen.dart';

class CheckoutScreen extends ConsumerStatefulWidget {
  final double subtotal;
  final double discount;
  final double taxAmount;
  final double grandTotal;

  const CheckoutScreen({
    super.key,
    required this.subtotal,
    required this.discount,
    required this.taxAmount,
    required this.grandTotal,
  });

  @override
  ConsumerState<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends ConsumerState<CheckoutScreen> {
  CustomerModel? _selectedCustomer;
  final List<CheckoutPayment> _payments = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // Default to Cash for the full amount
    _payments.add(CheckoutPayment(
      paymentMethodId: AppConstants.paymentCash, // Assuming the name or ID is the same for simplicity
      paymentMethodName: AppConstants.paymentCash,
      amount: widget.grandTotal,
    ));
  }

  void _addPayment() {
    setState(() {
      _payments.add(CheckoutPayment(
        paymentMethodId: AppConstants.paymentCard,
        paymentMethodName: AppConstants.paymentCard,
        amount: 0,
      ));
    });
  }

  double get _totalPaid => _payments.fold(0, (sum, p) => sum + p.amount);
  double get _balanceDue => widget.grandTotal - _totalPaid;

  Future<void> _processCheckout() async {
    if (_totalPaid < widget.grandTotal) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Total paid is less than grand total'), backgroundColor: AppTheme.danger),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final cart = ref.read(cartProvider);
      final connectivity = await Connectivity().checkConnectivity();
      final isOffline = connectivity.contains(ConnectivityResult.none);
      final saleId = const Uuid().v4();

      if (isOffline) {
        // Enqueue offline
        final payload = {
          'customer_id': _selectedCustomer?.id,
          'items': cart.map((e) => e.toRpcJson()).toList(),
          'payments': _payments.map((e) => e.toRpcJson()).toList(),
          'subtotal': widget.subtotal,
          'discount': widget.discount,
          'tax_amount': widget.taxAmount,
          'grand_total': widget.grandTotal,
        };
        await LocalDbService().enqueueSale(saleId, payload);
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Offline Sale Saved! It will sync later.'), backgroundColor: AppTheme.accent),
          );
        }
      } else {
        // Push online
        await ref.read(salesRepositoryProvider).createSale(
          saleId: saleId,
          customerId: _selectedCustomer?.id,
          items: cart,
          payments: _payments,
          subtotal: widget.subtotal,
          discount: widget.discount,
          taxAmount: widget.taxAmount,
          grandTotal: widget.grandTotal,
        );
      }

      // Clear cart
      ref.read(cartProvider.notifier).clearCart();

      if (mounted) {
        context.pop(true); // Success
        context.push(AppRoutes.receipt.replaceAll(':saleId', saleId), extra: {'sale_id': saleId});
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: \$e'), backgroundColor: AppTheme.danger),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final methodsAsync = ref.watch(paymentMethodsProvider);
    final paymentMethods = methodsAsync.value ?? [
      AppConstants.paymentCash,
      AppConstants.paymentCard,
      AppConstants.paymentTransfer
    ];

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Checkout'),
        backgroundColor: AppTheme.surfaceDark,
      ),
      body: Center(
        child: Container(
          width: 600,
          padding: const EdgeInsets.all(24),
          child: ListView(
            shrinkWrap: true,
            children: [
              const SizedBox(height: 20),

            // Customer Selection (Mocked for simplicity)
            Row(
              children: [
                const Icon(Icons.person_outline, color: AppTheme.textSecondary),
                const SizedBox(width: 8),
                Expanded(
                  child: DropdownButtonFormField<CustomerModel?>(
                    dropdownColor: AppTheme.elevatedDark,
                    style: const TextStyle(color: AppTheme.textPrimary),
                    decoration: const InputDecoration(
                      labelText: 'Select Customer (Optional)',
                      labelStyle: TextStyle(color: AppTheme.textSecondary),
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(value: null, child: Text('Walk-in Customer')),
                      // Add actual customers from provider if fetched
                    ],
                    onChanged: (val) => setState(() => _selectedCustomer = val),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Split Payments
            const Text('Payment Methods', style: TextStyle(color: AppTheme.textPrimary, fontSize: 16)),
            const SizedBox(height: 8),
            ..._payments.asMap().entries.map((e) {
              final idx = e.key;
              final p = e.value;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: DropdownButtonFormField<String>(
                        value: paymentMethods.contains(p.paymentMethodName) ? p.paymentMethodName : paymentMethods.first,
                        dropdownColor: AppTheme.elevatedDark,
                        style: const TextStyle(color: AppTheme.textPrimary),
                        items: paymentMethods.map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setState(() {
                              p.amount = p.amount; // Keep amount
                            });
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 1,
                      child: TextFormField(
                        initialValue: p.amount.toStringAsFixed(2),
                        keyboardType: TextInputType.number,
                        style: const TextStyle(color: AppTheme.textPrimary),
                        decoration: const InputDecoration(prefixText: '\$'),
                        onChanged: (val) {
                          setState(() {
                            _payments[idx].amount = double.tryParse(val) ?? 0;
                          });
                        },
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: AppTheme.danger),
                      onPressed: () {
                        if (_payments.length > 1) {
                          setState(() => _payments.removeAt(idx));
                        }
                      },
                    )
                  ],
                ),
              );
            }),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: _addPayment,
                icon: const Icon(Icons.add, color: AppTheme.accent),
                label: const Text('Add Split Payment', style: TextStyle(color: AppTheme.accent)),
              ),
            ),
            const Divider(color: AppTheme.borderDark),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Grand Total:', style: TextStyle(color: AppTheme.textSecondary, fontSize: 16)),
                Text(widget.grandTotal.toCurrency(), style: const TextStyle(color: AppTheme.textPrimary, fontSize: 18, fontWeight: FontWeight.bold)),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Total Paid:', style: TextStyle(color: AppTheme.textSecondary, fontSize: 16)),
                Text(_totalPaid.toCurrency(), style: TextStyle(color: _totalPaid >= widget.grandTotal ? AppTheme.accent : AppTheme.warning, fontSize: 18, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => context.pop(),
                  child: const Text('Cancel', style: TextStyle(color: AppTheme.textSecondary)),
                ),
                const SizedBox(width: 16),
                ElevatedButton(
                  onPressed: _isLoading ? null : _processCheckout,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.accent,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  ),
                  child: _isLoading ? const CircularProgressIndicator(color: Colors.white) : const Text('Complete Sale'),
                ),
              ],
            )
          ],
        ),
      ),
      )
    );
  }
}
