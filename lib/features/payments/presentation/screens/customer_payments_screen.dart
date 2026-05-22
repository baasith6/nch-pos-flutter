import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../app/theme.dart';
import '../../data/repositories/payment_repository.dart';
import '../../../customers/data/models/customer_model.dart';
import '../../../customers/data/repositories/customer_repository.dart';

final _customersProvider = FutureProvider<List<CustomerModel>>((ref) {
  return ref.read(customerRepositoryProvider).getActive();
});

final _paymentMethodsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) {
  return ref.read(paymentRepositoryProvider).getPaymentMethods();
});

class CustomerPaymentsScreen extends ConsumerStatefulWidget {
  const CustomerPaymentsScreen({super.key});

  @override
  ConsumerState<CustomerPaymentsScreen> createState() => _CustomerPaymentsScreenState();
}

class _CustomerPaymentsScreenState extends ConsumerState<CustomerPaymentsScreen> {
  final _formKey = GlobalKey<FormState>();
  String? _selectedCustomerId;
  String? _selectedPaymentMethodId;
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _processPayment() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedCustomerId == null || _selectedPaymentMethodId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a customer and payment method')),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final amount = double.parse(_amountController.text.trim());
      await ref.read(paymentRepositoryProvider).processCustomerPayment(
            customerId: _selectedCustomerId!,
            paymentMethodId: _selectedPaymentMethodId!,
            amount: amount,
            note: _noteController.text.trim().isEmpty ? null : _noteController.text.trim(),
          );
          
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Payment processed successfully!')),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error processing payment: \$e', style: const TextStyle(color: AppTheme.danger))),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final customersAsync = ref.watch(_customersProvider);
    final paymentMethodsAsync = ref.watch(_paymentMethodsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Record Customer Payment'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  const Text('Payment automatically allocates to the oldest unpaid invoices.',
                      style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                  const SizedBox(height: 20),
                  customersAsync.when(
                    loading: () => const LinearProgressIndicator(),
                    error: (e, _) => Text('Error: \$e', style: const TextStyle(color: AppTheme.danger)),
                    data: (customers) => DropdownButtonFormField<String>(
                      value: _selectedCustomerId,
                      dropdownColor: AppTheme.elevatedDark,
                      style: const TextStyle(color: AppTheme.textPrimary),
                      decoration: const InputDecoration(labelText: 'Select Customer *'),
                      items: customers.map((c) => DropdownMenuItem(value: c.id, child: Text(c.name))).toList(),
                      onChanged: (v) => setState(() => _selectedCustomerId = v),
                      validator: (v) => v == null ? 'Required' : null,
                    ),
                  ),
                  const SizedBox(height: 16),
                  paymentMethodsAsync.when(
                    loading: () => const LinearProgressIndicator(),
                    error: (e, _) => Text('Error: \$e', style: const TextStyle(color: AppTheme.danger)),
                    data: (methods) => DropdownButtonFormField<String>(
                      value: _selectedPaymentMethodId,
                      dropdownColor: AppTheme.elevatedDark,
                      style: const TextStyle(color: AppTheme.textPrimary),
                      decoration: const InputDecoration(labelText: 'Payment Method *'),
                      items: methods.map((m) => DropdownMenuItem<String>(value: m['id'], child: Text(m['name']))).toList(),
                      onChanged: (v) => setState(() => _selectedPaymentMethodId = v),
                      validator: (v) => v == null ? 'Required' : null,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _amountController,
                    style: const TextStyle(color: AppTheme.textPrimary),
                    decoration: const InputDecoration(labelText: 'Payment Amount *'),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Required';
                      final num = double.tryParse(v);
                      if (num == null || num <= 0) return 'Must be > 0';
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _noteController,
                    style: const TextStyle(color: AppTheme.textPrimary),
                    decoration: const InputDecoration(labelText: 'Note / Reference (Optional)'),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 32),
                  ElevatedButton(
                    onPressed: _processPayment,
                    child: const Text('Process Payment'),
                  ),
                ],
              ),
            ),
    );
  }
}
