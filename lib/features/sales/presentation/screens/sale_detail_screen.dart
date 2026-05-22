import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../app/router.dart';
import '../../../../app/theme.dart';
import '../../../../core/extensions/extensions.dart';
import '../../../../core/services/auth_session_service.dart';
import '../../../sales/data/models/sale_model.dart';
import '../../../sales/data/repositories/sales_repository.dart';

final _saleByIdProvider = FutureProvider.family<SaleModel, String>((ref, id) {
  return ref.read(salesRepositoryProvider).getSaleById(id);
});

class SaleDetailScreen extends ConsumerWidget {
  final String saleId;
  const SaleDetailScreen({super.key, required this.saleId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final saleAsync = ref.watch(_saleByIdProvider(saleId));
    final profileAsync = ref.watch(currentProfileProvider);
    final isAdmin = profileAsync.value?.isAdmin == true;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sale Detail'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      body: saleAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) =>
            Center(child: Text('Error: $e', style: const TextStyle(color: AppTheme.danger))),
        data: (sale) => SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header card ──────────────────────────────────────────
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.cardDark,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.borderDark, width: 0.5),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            sale.invoiceNo,
                            style: const TextStyle(
                              color: AppTheme.textPrimary,
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        _StatusBadge(status: sale.status),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(sale.createdAt.toDisplayDateTime(),
                        style: const TextStyle(
                            color: AppTheme.textHint, fontSize: 12)),
                    if (sale.staffName != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text('Cashier: ${sale.staffName}',
                            style: const TextStyle(
                                color: AppTheme.textSecondary, fontSize: 12)),
                      ),
                  ],
                ),
              ),

              const SizedBox(height: 16),
              const Text('Items',
                  style: TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w600)),
              const SizedBox(height: 10),

              // ── Items list ───────────────────────────────────────────
              Container(
                decoration: BoxDecoration(
                  color: AppTheme.cardDark,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppTheme.borderDark, width: 0.5),
                ),
                child: Column(
                  children: [
                    ...sale.items.asMap().entries.map((entry) {
                      final i = entry.key;
                      final item = entry.value;
                      return Column(
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 10),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(item.productName,
                                          style: const TextStyle(
                                              color: AppTheme.textPrimary,
                                              fontSize: 13)),
                                      Text(
                                          '${item.unitPrice.toCurrency()} × ${item.quantity}',
                                          style: const TextStyle(
                                              color: AppTheme.textHint,
                                              fontSize: 11)),
                                    ],
                                  ),
                                ),
                                Text(item.lineTotal.toCurrency(),
                                    style: const TextStyle(
                                        color: AppTheme.textPrimary,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500)),
                              ],
                            ),
                          ),
                          if (i < sale.items.length - 1)
                            const Divider(height: 1),
                        ],
                      );
                    }),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // ── Totals ───────────────────────────────────────────────
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.cardDark,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppTheme.borderDark, width: 0.5),
                ),
                child: Column(
                  children: [
                    _TRow(label: 'Subtotal', value: sale.subtotal.toCurrency()),
                    if (sale.discount > 0)
                      _TRow(
                        label: 'Discount',
                        value: '- ${sale.discount.toCurrency()}',
                        color: AppTheme.warning,
                      ),
                    if (sale.taxAmount > 0)
                      _TRow(
                        label: 'Tax',
                        value: sale.taxAmount.toCurrency(),
                        color: AppTheme.textSecondary,
                      ),
                    const Divider(height: 16),
                    _TRow(
                      label: 'Grand Total',
                      value: sale.grandTotal.toCurrency(),
                      isBold: true,
                      color: AppTheme.accent,
                    ),
                    const SizedBox(height: 8),
                    _TRow(label: 'Payment', value: sale.paymentMethod),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // ── Receipt button ───────────────────────────────────────
              ElevatedButton.icon(
                onPressed: () => context.push(
                  AppRoutes.receipt.replaceAll(':saleId', sale.id),
                ),
                icon: const Icon(Icons.receipt_long_outlined),
                label: const Text('View / Print Receipt'),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 50),
                ),
              ),

              // ── Admin: Cancel / Refund buttons ───────────────────────
              if (isAdmin && sale.status == 'Completed') ...[
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _StatusActionButton(
                        label: 'Cancel Sale',
                        icon: Icons.cancel_outlined,
                        color: AppTheme.danger,
                        onConfirm: () async {
                          await ref
                              .read(salesRepositoryProvider)
                              .updateSaleStatus(sale.id, 'Cancelled');
                          ref.invalidate(_saleByIdProvider(saleId));
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text('Sale cancelled'),
                                  backgroundColor: AppTheme.danger),
                            );
                          }
                        },
                        confirmMessage:
                            'Mark this sale as Cancelled? This cannot be undone.',
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _StatusActionButton(
                        label: 'Mark Refunded',
                        icon: Icons.replay_outlined,
                        color: AppTheme.warning,
                        onConfirm: () async {
                          await ref
                              .read(salesRepositoryProvider)
                              .updateSaleStatus(sale.id, 'Refunded');
                          ref.invalidate(_saleByIdProvider(saleId));
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text('Sale marked as refunded'),
                                  backgroundColor: AppTheme.warning),
                            );
                          }
                        },
                        confirmMessage:
                            'Mark this sale as Refunded? This cannot be undone.',
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Status Badge ─────────────────────────────────────────────────────────────
class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});

  Color get _color {
    switch (status) {
      case 'Completed':
        return AppTheme.accent;
      case 'Cancelled':
        return AppTheme.danger;
      case 'Refunded':
        return AppTheme.warning;
      default:
        return AppTheme.textSecondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: _color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _color.withValues(alpha: 0.3)),
      ),
      child: Text(status, style: TextStyle(color: _color, fontSize: 12)),
    );
  }
}

// ─── Status Action Button ─────────────────────────────────────────────────────
class _StatusActionButton extends StatefulWidget {
  final String label;
  final IconData icon;
  final Color color;
  final Future<void> Function() onConfirm;
  final String confirmMessage;

  const _StatusActionButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onConfirm,
    required this.confirmMessage,
  });

  @override
  State<_StatusActionButton> createState() => _StatusActionButtonState();
}

class _StatusActionButtonState extends State<_StatusActionButton> {
  bool _loading = false;

  Future<void> _handle() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.cardDark,
        title: Text(widget.label,
            style: TextStyle(color: widget.color)),
        content: Text(widget.confirmMessage,
            style: const TextStyle(color: AppTheme.textSecondary)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: widget.color),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _loading = true);
    try {
      await widget.onConfirm();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: _loading ? null : _handle,
      icon: _loading
          ? SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: widget.color),
            )
          : Icon(widget.icon, size: 16),
      label: Text(widget.label),
      style: OutlinedButton.styleFrom(
        foregroundColor: widget.color,
        side: BorderSide(color: widget.color.withValues(alpha: 0.5)),
        minimumSize: const Size(0, 46),
      ),
    );
  }
}

// ─── Row widget ───────────────────────────────────────────────────────────────
class _TRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isBold;
  final Color? color;
  const _TRow(
      {required this.label,
      required this.value,
      this.isBold = false,
      this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(
                  color:
                      isBold ? AppTheme.textPrimary : AppTheme.textSecondary,
                  fontWeight:
                      isBold ? FontWeight.w700 : FontWeight.normal,
                  fontSize: isBold ? 15 : 13)),
          Text(value,
              style: TextStyle(
                  color: color ?? AppTheme.textPrimary,
                  fontWeight:
                      isBold ? FontWeight.w700 : FontWeight.normal,
                  fontSize: isBold ? 17 : 13)),
        ],
      ),
    );
  }
}
