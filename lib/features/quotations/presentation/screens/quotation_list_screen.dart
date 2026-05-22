import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../app/theme.dart';
import '../../data/repositories/quotation_repository.dart';

final quotationsProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) {
  return ref.read(quotationRepositoryProvider).getQuotations();
});

class QuotationListScreen extends ConsumerWidget {
  const QuotationListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncData = ref.watch(quotationsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Quotations'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          context.push('/quotations/create').then((_) => ref.refresh(quotationsProvider));
        },
        icon: const Icon(Icons.add),
        label: const Text('New Quotation'),
      ),
      body: asyncData.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Text('Error: \$e', style: const TextStyle(color: AppTheme.danger)),
        ),
        data: (quotations) {
          if (quotations.isEmpty) {
            return const Center(
              child: Text(
                'No quotations found',
                style: TextStyle(color: AppTheme.textSecondary),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(20),
            itemCount: quotations.length,
            itemBuilder: (context, index) {
              final quote = quotations[index];
              final date = DateTime.parse(quote['created_at']);
              final customerName = quote['customers']?['name'] ?? 'Walk-in Customer';
              final grandTotal = (quote['grand_total'] as num).toDouble();

              return Card(
                color: AppTheme.cardDark,
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  title: Text(
                    '${quote["invoice_no"]} • $customerName',
                    style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  subtitle: Text(
                    DateFormat('MMM dd, yyyy HH:mm').format(date),
                    style: const TextStyle(color: AppTheme.textSecondary),
                  ),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '\$\${grandTotal.toStringAsFixed(2)}',
                        style: const TextStyle(
                          color: AppTheme.accent,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        quote['status'],
                        style: TextStyle(
                          color: quote['status'] == 'Draft' 
                              ? AppTheme.textHint 
                              : quote['status'] == 'Converted' 
                                  ? AppTheme.accent 
                                  : AppTheme.warning,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  onTap: () {
                    // Could open a details screen or convert to sale
                    // For now, we allow loading it to POS if it's not converted
                    if (quote['status'] != 'Converted') {
                      _showActionMenu(context, ref, quote['id']);
                    }
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _showActionMenu(BuildContext context, WidgetRef ref, String quotationId) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.elevatedDark,
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.point_of_sale_rounded, color: AppTheme.accent),
            title: const Text('Convert to Sale in POS', style: TextStyle(color: AppTheme.textPrimary)),
            onTap: () {
              Navigator.pop(ctx);
              // Send the quotationId to POS
              // This requires POS to read a provider, we'll route to POS with query param or extra
              context.push('/pos', extra: {'quotationId': quotationId});
            },
          ),
          ListTile(
            leading: const Icon(Icons.cancel_outlined, color: AppTheme.danger),
            title: const Text('Mark as Rejected', style: TextStyle(color: AppTheme.danger)),
            onTap: () async {
              Navigator.pop(ctx);
              await ref.read(quotationRepositoryProvider).updateQuotationStatus(quotationId, 'Rejected');
              ref.refresh(quotationsProvider);
            },
          ),
        ],
      ),
    );
  }
}
