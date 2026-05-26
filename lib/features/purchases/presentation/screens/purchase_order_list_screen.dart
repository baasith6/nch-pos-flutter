import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../app/theme.dart';
import '../../../../core/extensions/extensions.dart';
import '../../data/repositories/purchases_repository.dart';

final _purchaseOrdersProvider = FutureProvider((ref) {
  return ref.read(purchasesRepositoryProvider).getAllPurchaseOrders();
});

class PurchaseOrderListScreen extends ConsumerWidget {
  const PurchaseOrderListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final posAsync = ref.watch(_purchaseOrdersProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Purchase Orders'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      body: posAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: \$e', style: const TextStyle(color: AppTheme.danger))),
        data: (pos) {
          if (pos.isEmpty) {
            return const Center(
              child: Text('No Purchase Orders found.', style: TextStyle(color: AppTheme.textSecondary)),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(20),
            itemCount: pos.length,
            itemBuilder: (context, index) {
              final po = pos[index];
              return Card(
                color: AppTheme.cardDark,
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  title: Text('PO: ${po.poNo}', style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold)),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Supplier: ${po.supplierName ?? "Unknown"}', style: const TextStyle(color: AppTheme.textSecondary)),
                      Text('Date: ${DateFormat("MMM dd, yyyy HH:mm").format(po.createdAt)}', style: const TextStyle(color: AppTheme.textHint, fontSize: 12)),
                      Text('Status: ${po.poStatus} | Receiving: ${po.receivingStatus}', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                    ],
                  ),
                  trailing: Text(po.grandTotal.toCurrency(), style: const TextStyle(color: AppTheme.accent, fontWeight: FontWeight.bold, fontSize: 16)),
                  onTap: () {
                    // Navigate to GRN Screen or View PO Screen
                    context.push('/purchases/\${po.id}/receive');
                  },
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          context.push('/purchases/add');
        },
        backgroundColor: AppTheme.accent,
        child: const Icon(Icons.add),
      ),
    );
  }
}
