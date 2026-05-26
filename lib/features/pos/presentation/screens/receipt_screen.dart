import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
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
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Receipt'),
        backgroundColor: AppTheme.surfaceDark,
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
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Column(
            children: [
              _ReceiptCard(data: data, settings: settings),
              const SizedBox(height: 16),
              _ActionButtons(data: data, settings: settings),
            ],
          ),
        ),
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
      'customer_name': sale.customerName,
      'subtotal': sale.subtotal,
      'discount': sale.discount,
      'tax_amount': sale.taxAmount,
      'grand_total': sale.grandTotal,
      'amount_paid': sale.amountPaid,
      'balance_due': sale.balanceDue,
      'payment_status': sale.paymentStatus,
      'created_at': sale.createdAt.toIso8601String(),
      'payments': sale.payments
          .map((p) => {
                'method': p.paymentMethodName ?? 'Unknown',
                'amount': p.amount,
              })
          .toList(),
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
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Column(
            children: [
              _ReceiptCard(data: data, settings: settings),
              const SizedBox(height: 16),
              _ActionButtons(data: data, settings: settings),
            ],
          ),
        ),
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
      final doc = await ReceiptPdfService.generate(
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
      final doc = await ReceiptPdfService.generate(
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
  final Map<String, dynamic> data;
  final ShopSettings settings;

  const _ReceiptCard({
    required this.data,
    required this.settings,
  });

  @override
  Widget build(BuildContext context) {
    final invoiceNo = data['invoice_no'] as String? ?? '';
    final createdAt = data['created_at'] as String? ?? '';
    final staffName = data['staff_name'] as String? ?? '';
    final customerName = data['customer_name'] as String? ?? 'Walk-in Customer';
    
    final items = data['items'] as List? ?? [];
    final payments = data['payments'] as List? ?? [];
    
    final subtotal = (data['subtotal'] as num?)?.toDouble() ?? 0;
    final discount = (data['discount'] as num?)?.toDouble() ?? 0;
    final taxAmount = (data['tax_amount'] as num?)?.toDouble() ?? 0;
    final grandTotal = (data['grand_total'] as num?)?.toDouble() ?? 0;
    final amountPaid = (data['amount_paid'] as num?)?.toDouble() ?? 0;
    final balanceDue = (data['balance_due'] as num?)?.toDouble() ?? 0;

    DateTime? saleDate;
    try {
      saleDate = DateTime.parse(createdAt);
    } catch (_) {}
    
    final dateStr = saleDate != null ? DateFormat('dd/MM/yyyy').format(saleDate) : '';
    final timeStr = saleDate != null ? DateFormat('hh:mm a').format(saleDate) : '';

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppTheme.cardDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderDark),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Business header
          Text(
            settings.shopName,
            style: const TextStyle(color: AppTheme.textPrimary, fontSize: 22, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          if (settings.address != null && settings.address!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              settings.address!,
              style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ],
          if (settings.phone != null && settings.phone!.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              'Tel: ${settings.phone}',
              style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ],
          
          const SizedBox(height: 20),
          const Text(
            'SALES RECEIPT',
            style: TextStyle(color: AppTheme.textPrimary, fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),

          // Invoice info
          _InfoRow('Invoice No:', invoiceNo),
          if (dateStr.isNotEmpty) _InfoRow('Date:', dateStr),
          if (timeStr.isNotEmpty) _InfoRow('Time:', timeStr),
          if (staffName.isNotEmpty) _InfoRow('Cashier:', staffName),
          _InfoRow('Customer:', customerName),
          
          const SizedBox(height: 12),
          const _DashedDivider(),
          const SizedBox(height: 12),

          // Items header
          const Text('ITEMS', style: TextStyle(color: AppTheme.textPrimary, fontSize: 14, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
          
          const SizedBox(height: 12),
          const _DashedDivider(),
          const SizedBox(height: 12),

          // Items
          ...items.map((item) {
            final name = item['product_name'] ?? '';
            final qty = item['quantity'] ?? 0;
            final unitPrice = (item['unit_price'] as num?)?.toDouble() ?? 0;
            final lineTotal = (item['line_total'] as num?)?.toDouble() ?? 0;
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('$qty x ${unitPrice.toCurrency()}', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 14)),
                      Text(lineTotal.toCurrency(), style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14)),
                    ],
                  ),
                ],
              ),
            );
          }),

          const SizedBox(height: 4),
          const _DashedDivider(),
          const SizedBox(height: 12),

          // Totals
          _TotalRow('Subtotal:', subtotal.toCurrency()),
          _TotalRow('Discount:', discount.toCurrency()),
          _TotalRow('Tax/VAT:', taxAmount.toCurrency()),
          
          const SizedBox(height: 12),
          const _DashedDivider(),
          const SizedBox(height: 12),
          
          _TotalRow('GRAND TOTAL:', grandTotal.toCurrency(), isBold: true, color: AppTheme.accent),
          
          const SizedBox(height: 12),
          const _DashedDivider(),
          const SizedBox(height: 12),

          // Payments
          if (payments.length == 1) ...[
            _TotalRow('Payment Method:', payments.first['method'] as String? ?? 'Cash'),
            _TotalRow('Paid Amount:', ((payments.first['amount'] as num?)?.toDouble() ?? 0).toCurrency()),
            _TotalRow(balanceDue < 0 ? 'Change:' : 'Balance:', balanceDue.abs().toCurrency()),
          ] else if (payments.length > 1) ...[
            const Text('Payment Method:', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
            const SizedBox(height: 4),
            ...payments.map((p) {
              final method = p['method'] as String? ?? 'Unknown';
              final amt = (p['amount'] as num?)?.toDouble() ?? 0;
              return _TotalRow('  $method:', amt.toCurrency());
            }),
            const SizedBox(height: 4),
            _TotalRow('Total Paid:', amountPaid.toCurrency()),
            _TotalRow(balanceDue < 0 ? 'Change:' : 'Balance:', balanceDue.abs().toCurrency()),
          ] else ...[
            _TotalRow('Total Paid:', amountPaid.toCurrency()),
            _TotalRow(balanceDue < 0 ? 'Change:' : 'Balance:', balanceDue.abs().toCurrency()),
          ],

          const SizedBox(height: 24),

          // Footer
          Text(
            settings.receiptFooter?.isNotEmpty == true
                ? settings.receiptFooter!
                : 'Thank you for shopping with us.\nGoods once sold are not returnable unless damaged.\nPlease keep this receipt for warranty/returns.',
            style: const TextStyle(
              color: AppTheme.textHint,
              fontSize: 12,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Center(
            child: Image.asset(
              'assets/images/logo.png',
              height: 40,
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90,
            child: Text(label, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13), textAlign: TextAlign.right),
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

  const _TotalRow(
    this.label,
    this.value, {
    this.isBold = false,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
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
              color: color ?? (isBold ? AppTheme.textPrimary : AppTheme.textPrimary),
              fontSize: isBold ? 18 : 14,
              fontWeight: isBold ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _DashedDivider extends StatelessWidget {
  const _DashedDivider();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final boxWidth = constraints.constrainWidth();
        const dashWidth = 5.0;
        const dashHeight = 1.0;
        final dashCount = (boxWidth / (2 * dashWidth)).floor();
        return Flex(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          direction: Axis.horizontal,
          children: List.generate(dashCount, (_) {
            return const SizedBox(
              width: dashWidth,
              height: dashHeight,
              child: DecoratedBox(
                decoration: BoxDecoration(color: AppTheme.borderDark),
              ),
            );
          }),
        );
      },
    );
  }
}

// ─── Provider ─────────────────────────────────────────────────────────────────
final _saleDetailProvider =
    FutureProvider.family<SaleModel, String>((ref, id) async {
  return ref.read(salesRepositoryProvider).getSaleById(id);
});
