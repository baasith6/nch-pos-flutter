import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:printing/printing.dart';
import '../../../../app/theme.dart';
import '../../../../core/extensions/extensions.dart';
import '../../../../core/services/receipt_pdf_service.dart';
import '../../../sales/data/models/sale_model.dart';
import '../../../sales/data/repositories/sales_repository.dart';
import '../../../settings/data/models/shop_settings_model.dart';
import '../../../settings/data/repositories/settings_repository.dart';

class ReceiptScreen extends ConsumerWidget {
  final String saleId;
  final Map<String, dynamic>? receiptData;

  const ReceiptScreen({
    super.key,
    required this.saleId,
    this.receiptData,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final saleAsync = receiptData != null
        ? null
        : ref.watch(_saleDetailProvider(saleId));
    final settingsAsync = ref.watch(shopSettingsProvider);
    final settings = settingsAsync.value ?? ShopSettings.defaults;
    final data = receiptData;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Receipt'),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      body: data != null
          ? _ReceiptBody(data: data, settings: settings)
          : saleAsync!.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
              data: (sale) =>
                  _ReceiptFromModel(sale: sale, settings: settings),
            ),
    );
  }
}

// ─── Receipt from RPC return data ────────────────────────────────────────────
class _ReceiptBody extends StatelessWidget {
  final Map<String, dynamic> data;
  final ShopSettings settings;
  const _ReceiptBody({required this.data, required this.settings});

  @override
  Widget build(BuildContext context) {
    final items = data['items'] as List? ?? [];
    final invoiceNo = data['invoice_no'] as String? ?? '';
    final grandTotal = (data['grand_total'] as num?)?.toDouble() ?? 0;
    final subtotal = (data['subtotal'] as num?)?.toDouble() ?? 0;
    final discount = (data['discount'] as num?)?.toDouble() ?? 0;
    final taxAmount = (data['tax_amount'] as num?)?.toDouble() ?? 0;
    final paymentMethod = data['payment_method'] as String? ?? '';
    final createdAt = data['created_at'] as String? ?? '';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          _ReceiptCard(
            invoiceNo: invoiceNo,
            createdAt: createdAt,
            items: items,
            subtotal: subtotal,
            discount: discount,
            taxAmount: taxAmount,
            taxLabel: settings.taxEnabled && settings.taxPercentage > 0
                ? 'Tax (${settings.taxPercentage.toStringAsFixed(1)}%)'
                : null,
            grandTotal: grandTotal,
            paymentMethod: paymentMethod,
            shopName: settings.shopName,
            footer: settings.receiptFooter,
          ),
          const SizedBox(height: 16),
          _ActionButtons(data: data, settings: settings),
        ],
      ),
    );
  }
}

// ─── Receipt from fetched SaleModel ──────────────────────────────────────────
class _ReceiptFromModel extends StatelessWidget {
  final SaleModel sale;
  final ShopSettings settings;
  const _ReceiptFromModel({required this.sale, required this.settings});

  @override
  Widget build(BuildContext context) {
    final data = {
      'invoice_no': sale.invoiceNo,
      'staff_name': sale.staffName ?? '',
      'subtotal': sale.subtotal,
      'discount': sale.discount,
      'tax_amount': sale.taxAmount,
      'grand_total': sale.grandTotal,
      'payment_method': sale.paymentMethod,
      'created_at': sale.createdAt.toIso8601String(),
      'items': sale.items
          .map((e) => {
                'product_name': e.productName,
                'quantity': e.quantity,
                'unit_price': e.unitPrice,
                'line_total': e.lineTotal,
              })
          .toList(),
    };

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          _ReceiptCard(
            invoiceNo: sale.invoiceNo,
            createdAt: sale.createdAt.toIso8601String(),
            items: data['items'] as List,
            subtotal: sale.subtotal,
            discount: sale.discount,
            taxAmount: sale.taxAmount,
            taxLabel: settings.taxEnabled && settings.taxPercentage > 0
                ? 'Tax (${settings.taxPercentage.toStringAsFixed(1)}%)'
                : null,
            grandTotal: sale.grandTotal,
            paymentMethod: sale.paymentMethod,
            shopName: settings.shopName,
            footer: settings.receiptFooter,
          ),
          const SizedBox(height: 16),
          _ActionButtons(data: data, settings: settings),
        ],
      ),
    );
  }
}

// ─── Print & Share buttons ────────────────────────────────────────────────────
class _ActionButtons extends StatefulWidget {
  final Map<String, dynamic> data;
  final ShopSettings settings;
  const _ActionButtons({required this.data, required this.settings});

  @override
  State<_ActionButtons> createState() => _ActionButtonsState();
}

class _ActionButtonsState extends State<_ActionButtons> {
  bool _printing = false;

  Future<void> _print() async {
    setState(() => _printing = true);
    try {
      final doc = ReceiptPdfService.generate(
        data: widget.data,
        settings: widget.settings,
      );
      await Printing.layoutPdf(
        onLayout: (_) async => doc.save(),
        name: 'Receipt-${widget.data['invoice_no'] ?? ''}',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Print failed: $e'),
            backgroundColor: AppTheme.danger,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _printing = false);
    }
  }

  Future<void> _share() async {
    setState(() => _printing = true);
    try {
      final doc = ReceiptPdfService.generate(
        data: widget.data,
        settings: widget.settings,
      );
      await Printing.sharePdf(
        bytes: await doc.save(),
        filename: 'Receipt-${widget.data['invoice_no'] ?? ''}.pdf',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Share failed: $e'),
            backgroundColor: AppTheme.danger,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _printing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _printing ? null : _print,
                icon: _printing
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.print_outlined),
                label: const Text('Print'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(0, 50),
                  foregroundColor: AppTheme.primary,
                  side: BorderSide(
                      color: AppTheme.primary.withValues(alpha: 0.5)),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _printing ? null : _share,
                icon: const Icon(Icons.share_outlined),
                label: const Text('Share'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(0, 50),
                  foregroundColor: AppTheme.accent,
                  side: BorderSide(
                      color: AppTheme.accent.withValues(alpha: 0.5)),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        ElevatedButton.icon(
          onPressed: () => context.pop(),
          icon: const Icon(Icons.home_outlined),
          label: const Text('Back to Dashboard'),
          style: ElevatedButton.styleFrom(
            minimumSize: const Size(double.infinity, 52),
          ),
        ),
      ],
    );
  }
}

// ─── Shared Receipt Card ──────────────────────────────────────────────────────
class _ReceiptCard extends StatelessWidget {
  final String invoiceNo;
  final String createdAt;
  final List items;
  final double subtotal;
  final double discount;
  final double taxAmount;
  final String? taxLabel;
  final double grandTotal;
  final String paymentMethod;
  final String shopName;
  final String? footer;

  const _ReceiptCard({
    required this.invoiceNo,
    required this.createdAt,
    required this.items,
    required this.subtotal,
    required this.discount,
    required this.taxAmount,
    this.taxLabel,
    required this.grandTotal,
    required this.paymentMethod,
    required this.shopName,
    this.footer,
  });

  @override
  Widget build(BuildContext context) {
    final dateStr = createdAt.isNotEmpty
        ? DateTime.tryParse(createdAt)?.toDisplayDateTime() ?? createdAt
        : '';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.cardDark,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.borderDark),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Center(
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: AppTheme.primaryGradient,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(
                    Icons.receipt_long_rounded,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  shopName,
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  invoiceNo,
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 13,
                  ),
                ),
                Text(
                  dateStr,
                  style: const TextStyle(
                    color: AppTheme.textHint,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const Divider(),
          const SizedBox(height: 8),

          // Items
          ...items.map((item) {
            final name = item['product_name'] ?? '';
            final qty = item['quantity'] ?? 0;
            final lineTotal = (item['line_total'] as num?)?.toDouble() ?? 0;
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      name,
                      style: const TextStyle(
                          color: AppTheme.textPrimary, fontSize: 13),
                    ),
                  ),
                  Text(
                    'x$qty',
                    style: const TextStyle(
                        color: AppTheme.textSecondary, fontSize: 13),
                  ),
                  const SizedBox(width: 20),
                  Text(
                    lineTotal.toCurrency(),
                    style: const TextStyle(
                        color: AppTheme.textPrimary, fontSize: 13),
                  ),
                ],
              ),
            );
          }),

          const SizedBox(height: 8),
          const Divider(),
          const SizedBox(height: 8),

          // Totals
          _TotalRow(label: 'Subtotal', value: subtotal.toCurrency()),
          if (discount > 0)
            _TotalRow(
              label: 'Discount',
              value: '- ${discount.toCurrency()}',
              color: AppTheme.warning,
            ),
          if (taxAmount > 0)
            _TotalRow(
              label: taxLabel ?? 'Tax',
              value: taxAmount.toCurrency(),
              color: AppTheme.textSecondary,
            ),
          const SizedBox(height: 6),
          _TotalRow(
            label: 'Grand Total',
            value: grandTotal.toCurrency(),
            isBold: true,
            color: AppTheme.accent,
          ),
          const SizedBox(height: 6),
          _TotalRow(label: 'Payment', value: paymentMethod),

          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 8),
          Center(
            child: Text(
              footer?.isNotEmpty == true
                  ? footer!
                  : 'Thank you for shopping!',
              style: const TextStyle(
                color: AppTheme.textHint,
                fontSize: 12,
                fontStyle: FontStyle.italic,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}

class _TotalRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isBold;
  final Color? color;

  const _TotalRow({
    required this.label,
    required this.value,
    this.isBold = false,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            color: isBold ? AppTheme.textPrimary : AppTheme.textSecondary,
            fontSize: isBold ? 16 : 13,
            fontWeight: isBold ? FontWeight.w700 : FontWeight.normal,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: color ?? AppTheme.textPrimary,
            fontSize: isBold ? 18 : 13,
            fontWeight: isBold ? FontWeight.w700 : FontWeight.normal,
          ),
        ),
      ],
    );
  }
}

// ─── Provider ─────────────────────────────────────────────────────────────────
final _saleDetailProvider =
    FutureProvider.family<SaleModel, String>((ref, id) async {
  return ref.read(salesRepositoryProvider).getSaleById(id);
});
