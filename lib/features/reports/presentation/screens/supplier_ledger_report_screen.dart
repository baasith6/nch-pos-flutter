import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../app/theme.dart';
import '../../data/repositories/report_repository.dart';
import '../../../suppliers/data/models/supplier_model.dart';
import '../../../suppliers/data/repositories/supplier_repository.dart';

final _suppliersProvider = FutureProvider<List<SupplierModel>>((ref) {
  return ref.read(supplierRepositoryProvider).getActive();
});

final _supplierLedgerProvider = FutureProvider.family<List<Map<String, dynamic>>, String>((ref, supplierId) {
  return ref.read(reportRepositoryProvider).getSupplierLedger(supplierId);
});

class SupplierLedgerReportScreen extends ConsumerStatefulWidget {
  const SupplierLedgerReportScreen({super.key});

  @override
  ConsumerState<SupplierLedgerReportScreen> createState() => _SupplierLedgerReportScreenState();
}

class _SupplierLedgerReportScreenState extends ConsumerState<SupplierLedgerReportScreen> {
  String? _selectedSupplierId;

  @override
  Widget build(BuildContext context) {
    final suppliersAsync = ref.watch(_suppliersProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Supplier Ledgers'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => context.pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.payments_outlined),
            tooltip: 'Record Supplier Payment',
            onPressed: () {
              context.push('/payments/supplier').then((_) {
                if (_selectedSupplierId != null) {
                  ref.refresh(_supplierLedgerProvider(_selectedSupplierId!));
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
            child: suppliersAsync.when(
              loading: () => const CircularProgressIndicator(),
              error: (e, _) => Text('Error: \$e', style: const TextStyle(color: AppTheme.danger)),
              data: (suppliers) => DropdownButtonFormField<String>(
                value: _selectedSupplierId,
                dropdownColor: AppTheme.elevatedDark,
                style: const TextStyle(color: AppTheme.textPrimary),
                decoration: const InputDecoration(labelText: 'Select Supplier', labelStyle: TextStyle(color: AppTheme.textSecondary)),
                items: suppliers.map((c) => DropdownMenuItem(value: c.id, child: Text(c.name))).toList(),
                onChanged: (v) => setState(() => _selectedSupplierId = v),
              ),
            ),
          ),
          
          if (_selectedSupplierId != null)
            Expanded(
              child: Consumer(
                builder: (context, ref, child) {
                  final ledgerAsync = ref.watch(_supplierLedgerProvider(_selectedSupplierId!));
                  
                  return ledgerAsync.when(
                    loading: () => const Center(child: CircularProgressIndicator()),
                    error: (e, _) => Center(child: Text('Error: \$e', style: const TextStyle(color: AppTheme.danger))),
                    data: (ledger) {
                      if (ledger.isEmpty) {
                        return const Center(child: Text('No purchase orders found for this supplier.', style: TextStyle(color: AppTheme.textSecondary)));
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
                                            Text('PO: ${tx["po_number"]}', style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold)),
                                            Text(DateFormat('MMM dd, yyyy HH:mm').format(date), style: const TextStyle(color: AppTheme.textHint, fontSize: 12)),
                                          ],
                                        ),
                                        const SizedBox(height: 8),
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text('Total: \$${grandTotal.toStringAsFixed(2)}', style: const TextStyle(color: AppTheme.textSecondary)),
                                            Text('Paid: \$${amountPaid.toStringAsFixed(2)}', style: const TextStyle(color: AppTheme.accent)),
                                          ],
                                        ),
                                        const Divider(color: AppTheme.borderDark),
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text('Status: ${tx["payment_status"]}', style: const TextStyle(color: AppTheme.textSecondary)),
                                            Text('Balance Due: \$${balanceDue.toStringAsFixed(2)}', style: const TextStyle(color: AppTheme.danger, fontWeight: FontWeight.bold)),
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
