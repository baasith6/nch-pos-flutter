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
      paymentMethodId: AppConstants.paymentCash, 
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
            const SnackBar(content: Text('Offline Sale Saved! It will sync later.'), backgroundColor: AppTheme.success),
          );
        }
      } else {
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

      ref.read(cartProvider.notifier).clearCart();

      if (mounted) {
        context.pop(true);
        context.push(AppRoutes.receipt.replaceAll(':saleId', saleId));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.danger),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final methodsAsync = ref.watch(paymentMethodsProvider);
    List<String> paymentMethods = methodsAsync.value ?? [];
    if (paymentMethods.isEmpty) {
      paymentMethods = [
        AppConstants.paymentCash,
        AppConstants.paymentCard,
        AppConstants.paymentTransfer
      ];
    }
    
    final cartItemCount = ref.watch(cartProvider).length;
    final bool isCompleteDisabled = _totalPaid < widget.grandTotal || _isLoading;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Checkout'),
        backgroundColor: AppTheme.surfaceDark,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 600),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Order Summary Card
                        Card(
                          elevation: 0,
                          margin: EdgeInsets.zero,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(22),
                            side: const BorderSide(color: AppTheme.borderDark),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text('Order Summary', style: TextStyle(color: AppTheme.textPrimary, fontSize: 16, fontWeight: FontWeight.w600)),
                                    Text('$cartItemCount item${cartItemCount != 1 ? 's' : ''}', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 14)),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                _buildSummaryRow('Subtotal', widget.subtotal.toCurrency()),
                                const SizedBox(height: 8),
                                _buildSummaryRow('Discount', widget.discount.toCurrency(), isDiscount: true),
                                const SizedBox(height: 8),
                                const Divider(color: AppTheme.borderDark),
                                const SizedBox(height: 8),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text('Grand Total', style: TextStyle(color: AppTheme.textPrimary, fontSize: 16, fontWeight: FontWeight.w600)),
                                    Text(widget.grandTotal.toCurrency(), style: const TextStyle(color: AppTheme.textPrimary, fontSize: 18, fontWeight: FontWeight.bold)),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Customer Section
                        Card(
                          elevation: 0,
                          margin: EdgeInsets.zero,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(22),
                            side: const BorderSide(color: AppTheme.borderDark),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Customer', style: TextStyle(color: AppTheme.textPrimary, fontSize: 16, fontWeight: FontWeight.w600)),
                                const SizedBox(height: 12),
                                DropdownButtonFormField<CustomerModel?>(
                                  dropdownColor: AppTheme.surfaceDark,
                                  icon: const Icon(Icons.person_outline, color: AppTheme.textSecondary),
                                  style: const TextStyle(color: AppTheme.textPrimary, fontSize: 15),
                                  decoration: InputDecoration(
                                    filled: true,
                                    fillColor: AppTheme.elevatedDark,
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(14),
                                      borderSide: BorderSide.none,
                                    ),
                                  ),
                                  items: const [
                                    DropdownMenuItem(value: null, child: Text('Walk-in Customer')),
                                    // Add actual customers from provider if fetched
                                  ],
                                  onChanged: (val) => setState(() => _selectedCustomer = val),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Payments Section
                        const Text('Payment Split', style: TextStyle(color: AppTheme.textPrimary, fontSize: 16, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 12),
                        ..._payments.asMap().entries.map((e) {
                          final idx = e.key;
                          final p = e.value;
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12.0),
                            child: Row(
                              children: [
                                Expanded(
                                  flex: 2,
                                  child: DropdownButtonFormField<String>(
                                    value: paymentMethods.contains(p.paymentMethodName) ? p.paymentMethodName : paymentMethods.first,
                                    dropdownColor: AppTheme.surfaceDark,
                                    icon: const Icon(Icons.keyboard_arrow_down, color: AppTheme.textSecondary),
                                    style: const TextStyle(color: AppTheme.textPrimary, fontSize: 15),
                                    decoration: InputDecoration(
                                      filled: true,
                                      fillColor: AppTheme.elevatedDark,
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(14),
                                        borderSide: BorderSide.none,
                                      ),
                                    ),
                                    items: paymentMethods.map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
                                    onChanged: (val) {
                                      if (val != null) {
                                        setState(() {
                                          p.paymentMethodName = val;
                                          p.paymentMethodId = val;
                                        });
                                      }
                                    },
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  flex: 2,
                                  child: TextFormField(
                                    initialValue: p.amount > 0 ? p.amount.toStringAsFixed(2) : '',
                                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                    style: const TextStyle(color: AppTheme.textPrimary, fontSize: 15, fontWeight: FontWeight.w600),
                                    decoration: InputDecoration(
                                      prefixText: 'LKR ',
                                      prefixStyle: const TextStyle(color: AppTheme.textSecondary, fontSize: 15),
                                      filled: true,
                                      fillColor: AppTheme.elevatedDark,
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(14),
                                        borderSide: BorderSide.none,
                                      ),
                                    ),
                                    onChanged: (val) {
                                      setState(() {
                                        _payments[idx].amount = double.tryParse(val) ?? 0;
                                      });
                                    },
                                  ),
                                ),
                                if (_payments.length > 1)
                                  Padding(
                                    padding: const EdgeInsets.only(left: 8.0),
                                    child: IconButton(
                                      icon: const Icon(Icons.remove_circle_outline, color: AppTheme.danger),
                                      onPressed: () {
                                        setState(() => _payments.removeAt(idx));
                                      },
                                    ),
                                  )
                              ],
                            ),
                          );
                        }),
                        
                        Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton.icon(
                            onPressed: _addPayment,
                            icon: const Icon(Icons.add, color: AppTheme.primary),
                            label: const Text('Add Split Payment', style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.w600)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            
            // Bottom Action Area
            Container(
              decoration: BoxDecoration(
                color: AppTheme.surfaceDark,
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, -4)),
                ],
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 600),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Payment Summary
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Total Paid:', style: TextStyle(color: AppTheme.textSecondary, fontSize: 14)),
                          Text(_totalPaid.toCurrency(), style: const TextStyle(color: AppTheme.textPrimary, fontSize: 16, fontWeight: FontWeight.w600)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(_balanceDue < 0 ? 'Change:' : (_balanceDue == 0 ? 'Balance:' : 'Remaining:'), 
                            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 14)),
                          Text(
                            _balanceDue < 0 ? _balanceDue.abs().toCurrency() : (_balanceDue == 0 ? 'LKR 0.00' : _balanceDue.toCurrency()), 
                            style: TextStyle(
                              color: _balanceDue <= 0 ? AppTheme.success : AppTheme.danger, 
                              fontSize: 18, 
                              fontWeight: FontWeight.bold
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      // Action Buttons
                      Row(
                        children: [
                          Expanded(
                            flex: 1,
                            child: OutlinedButton(
                              onPressed: () => context.pop(),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              ),
                              child: const Text('Cancel', style: TextStyle(color: AppTheme.textSecondary, fontSize: 16)),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            flex: 2,
                            child: ElevatedButton(
                              onPressed: isCompleteDisabled ? null : _processCheckout,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.primary,
                                disabledBackgroundColor: AppTheme.disabled,
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              ),
                              child: _isLoading 
                                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                : const Text('Complete Sale', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
                            ),
                          ),
                        ],
                      )
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value, {bool isDiscount = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 14)),
        Text(value, style: TextStyle(color: isDiscount ? AppTheme.warning : AppTheme.textPrimary, fontSize: 14, fontWeight: FontWeight.w500)),
      ],
    );
  }
}
