import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../app/theme.dart';
import '../../../../core/extensions/extensions.dart';
import '../../data/repositories/stock_repository.dart';

final _adjustmentHistoryProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) {
  return ref.read(stockRepositoryProvider).getAdjustments();
});

class StockAdjustmentHistoryScreen extends ConsumerWidget {
  const StockAdjustmentHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyAsync = ref.watch(_adjustmentHistoryProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Adjustment History'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      body: historyAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Text('Error: $e',
              style: const TextStyle(color: AppTheme.danger)),
        ),
        data: (records) => records.isEmpty
            ? const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.history_outlined,
                        size: 60, color: AppTheme.textHint),
                    SizedBox(height: 12),
                    Text('No adjustments yet',
                        style:
                            TextStyle(color: AppTheme.textSecondary)),
                  ],
                ),
              )
            : ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: records.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, i) {
                  final r = records[i];
                  final productName =
                      (r['products'] as Map<String, dynamic>?)?['name'] as String? ??
                          'Unknown';
                  final adjustedBy =
                      (r['profiles'] as Map<String, dynamic>?)?['full_name'] as String? ??
                          'Unknown';
                  final oldQty = r['old_quantity'] as int? ?? 0;
                  final newQty = r['new_quantity'] as int? ?? 0;
                  final reason = r['reason'] as String? ?? '';
                  final createdAt = r['created_at'] as String? ?? '';
                  DateTime? date;
                  try {
                    date = DateTime.parse(createdAt);
                  } catch (_) {}

                  final diff = newQty - oldQty;
                  final isIncrease = diff >= 0;

                  return Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppTheme.cardDark,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                          color: AppTheme.borderDark, width: 0.5),
                    ),
                    child: Row(
                      children: [
                        // Direction indicator
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: isIncrease
                                ? AppTheme.accent.withValues(alpha: 0.12)
                                : AppTheme.danger.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            isIncrease
                                ? Icons.arrow_upward_rounded
                                : Icons.arrow_downward_rounded,
                            color: isIncrease
                                ? AppTheme.accent
                                : AppTheme.danger,
                            size: 18,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(productName,
                                  style: const TextStyle(
                                      color: AppTheme.textPrimary,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600)),
                              const SizedBox(height: 2),
                              Text(
                                '$oldQty → $newQty  (${isIncrease ? '+' : ''}$diff)',
                                style: TextStyle(
                                  color: isIncrease
                                      ? AppTheme.accent
                                      : AppTheme.danger,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              Text(reason,
                                  style: const TextStyle(
                                      color: AppTheme.textSecondary,
                                      fontSize: 11)),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(adjustedBy,
                                style: const TextStyle(
                                    color: AppTheme.textHint,
                                    fontSize: 11)),
                            if (date != null)
                              Text(date.toDisplayDateTime(),
                                  style: const TextStyle(
                                      color: AppTheme.textHint,
                                      fontSize: 10)),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
      ),
    );
  }
}
