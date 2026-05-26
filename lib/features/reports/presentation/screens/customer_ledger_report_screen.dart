import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../app/theme.dart';
import '../../../../core/extensions/extensions.dart';
import '../../data/repositories/report_repository.dart';
import '../../../customers/data/models/customer_model.dart';
import '../../../customers/data/repositories/customer_repository.dart';

final _customersProvider = FutureProvider<List<CustomerModel>>((ref) {
  return ref.read(customerRepositoryProvider).getActive();
});

final _customerLedgerProvider = FutureProvider.family<List<Map<String, dynamic>>, String>((ref, customerId) {
  return ref.read(reportRepositoryProvider).getCustomerLedger(customerId);
});

class CustomerLedgerReportScreen extends ConsumerStatefulWidget {
  const CustomerLedgerReportScreen({super.key});

  @override
  ConsumerState<CustomerLedgerReportScreen> createState() => _CustomerLedgerReportScreenState();
}

class _CustomerLedgerReportScreenState extends ConsumerState<CustomerLedgerReportScreen> {
  String? _selectedCustomerId;

  @override
  Widget build(BuildContext context) {
    final customersAsync = ref.watch(_customersProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Customer Ledgers'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => context.pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.payments_outlined),
            tooltip: 'Record Customer Payment',
            onPressed: () {
              context.push('/payments/customer').then((_) {
                if (_selectedCustomerId != null) {
                  ref.refresh(_customerLedgerProvider(_selectedCustomerId!));
                }
              });
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: customersAsync.when(
              loading: () => const CircularProgressIndicator(),
              error: (e, _) => Text('Error: \$e', style: const TextStyle(color: AppTheme.danger)),
              data: (customers) => DropdownButtonFormField<String>(
                value: _selectedCustomerId,
                dropdownColor: AppTheme.elevatedDark,
                style: const TextStyle(color: AppTheme.textPrimary),
                decoration: const InputDecoration(labelText: 'Select Customer', labelStyle: TextStyle(color: AppTheme.textSecondary)),
                items: customers.map((c) => DropdownMenuItem(value: c.id, child: Text(c.name))).toList(),
                onChanged: (v) => setState(() => _selectedCustomerId = v),
              ),
            ),
          ),
          
          if (_selectedCustomerId != null)
            Expanded(
              child: Consumer(
                builder: (context, ref, child) {
                  final ledgerAsync = ref.watch(_customerLedgerProvider(_selectedCustomerId!));
                  
                  return ledgerAsync.when(
                    loading: () => const Center(child: CircularProgressIndicator()),
                    error: (e, _) => Center(child: Text('Error: \$e', style: const TextStyle(color: AppTheme.danger))),
                    data: (ledger) {
                      if (ledger.isEmpty) {
                        return const Center(child: Text('No transactions found for this customer.', style: TextStyle(color: AppTheme.textSecondary)));
                      }

                      double totalOwed = 0;
                      for (final tx in ledger) {
                        totalOwed += (tx['balance_due'] as num).toDouble();
                      }

                      return Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(16),
                            margin: const EdgeInsets.symmetric(horizontal: 20),
                            decoration: BoxDecoration(
                              color: AppTheme.elevatedDark,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppTheme.borderDark),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Total Outstanding Balance:', style: TextStyle(color: AppTheme.textPrimary, fontSize: 16)),
                                Text('\$\${totalOwed.toStringAsFixed(2)}', style: const TextStyle(color: AppTheme.danger, fontSize: 20, fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          Expanded(
                            child: ListView.builder(
                              padding: const EdgeInsets.all(20),
                              itemCount: ledger.length,
                              itemBuilder: (context, index) {
                                final tx = ledger[index];
                                final date = DateTime.parse(tx['created_at']);
                                final grandTotal = (tx['grand_total'] as num).toDouble();
                                final amountPaid = (tx['amount_paid'] as num).toDouble();
                                final balanceDue = (tx['balance_due'] as num).toDouble();
                                
                                return Card(
                                  color: AppTheme.cardDark,
                                  margin: const EdgeInsets.only(bottom: 12),
                                  child: Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text('Invoice: ${tx["invoice_no"]}', style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold)),
                                            Text(DateFormat('MMM dd, yyyy HH:mm').format(date), style: const TextStyle(color: AppTheme.textHint, fontSize: 12)),
                                          ],
                                        ),
                                        const SizedBox(height: 8),
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text('Total: ${grandTotal.toCurrency()}', style: const TextStyle(color: AppTheme.textSecondary)),
                                            Text('Paid: ${amountPaid.toCurrency()}', style: const TextStyle(color: AppTheme.accent)),
                                          ],
                                        ),
                                        const Divider(color: AppTheme.borderDark),
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text('Status: ${tx["payment_status"]}', style: const TextStyle(color: AppTheme.textSecondary)),
                                            Text('Balance Due: ${balanceDue.toCurrency()}', style: const TextStyle(color: AppTheme.danger, fontWeight: FontWeight.bold)),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
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
