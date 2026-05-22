import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../../../features/settings/data/models/shop_settings_model.dart';

/// Generates a thermal-style receipt PDF from sale data.
class ReceiptPdfService {
  ReceiptPdfService._();

  static pw.Document generate({
    required Map<String, dynamic> data,
    required ShopSettings settings,
  }) {
    final doc = pw.Document();

    final invoiceNo = data['invoice_no'] as String? ?? '';
    final staffName = data['staff_name'] as String? ?? '';
    final subtotal = (data['subtotal'] as num?)?.toDouble() ?? 0;
    final discount = (data['discount'] as num?)?.toDouble() ?? 0;
    final taxAmount = (data['tax_amount'] as num?)?.toDouble() ?? 0;
    final grandTotal = (data['grand_total'] as num?)?.toDouble() ?? 0;
    final paymentMethod = data['payment_method'] as String? ?? '';
    final createdAt = data['created_at'] as String? ?? '';
    final items = data['items'] as List? ?? [];

    DateTime? saleDate;
    try {
      saleDate = DateTime.parse(createdAt);
    } catch (_) {}
    final dateStr = saleDate != null
        ? '${saleDate.day.toString().padLeft(2, '0')}/${saleDate.month.toString().padLeft(2, '0')}/${saleDate.year} '
            '${saleDate.hour.toString().padLeft(2, '0')}:${saleDate.minute.toString().padLeft(2, '0')}'
        : '';

    final currency = settings.currency;

    String fmt(double v) => '$currency ${v.toStringAsFixed(2)}';

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat(
          80 * PdfPageFormat.mm,
          double.infinity,
          marginAll: 8 * PdfPageFormat.mm,
        ),
        build: (ctx) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: [
            // Shop name header
            pw.Text(
              settings.shopName,
              style: pw.TextStyle(
                fontSize: 16,
                fontWeight: pw.FontWeight.bold,
              ),
              textAlign: pw.TextAlign.center,
            ),
            if (settings.address != null && settings.address!.isNotEmpty) ...[
              pw.SizedBox(height: 2),
              pw.Text(
                settings.address!,
                style: const pw.TextStyle(fontSize: 8),
                textAlign: pw.TextAlign.center,
              ),
            ],
            if (settings.phone != null && settings.phone!.isNotEmpty)
              pw.Text(
                settings.phone!,
                style: const pw.TextStyle(fontSize: 8),
                textAlign: pw.TextAlign.center,
              ),
            pw.SizedBox(height: 6),
            pw.Divider(thickness: 0.5),
            pw.SizedBox(height: 4),

            // Invoice info
            _row('Invoice', invoiceNo, fontSize: 8),
            if (dateStr.isNotEmpty) _row('Date', dateStr, fontSize: 8),
            if (staffName.isNotEmpty) _row('Cashier', staffName, fontSize: 8),
            pw.SizedBox(height: 6),
            pw.Divider(thickness: 0.5),
            pw.SizedBox(height: 4),

            // Items header
            pw.Row(children: [
              pw.Expanded(
                child: pw.Text('Item',
                    style: pw.TextStyle(
                        fontSize: 8, fontWeight: pw.FontWeight.bold)),
              ),
              pw.Text('Qty',
                  style: pw.TextStyle(
                      fontSize: 8, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(width: 8),
              pw.Text('Total',
                  style: pw.TextStyle(
                      fontSize: 8, fontWeight: pw.FontWeight.bold)),
            ]),
            pw.SizedBox(height: 4),

            // Items
            ...items.map((item) {
              final name = item['product_name'] as String? ?? '';
              final qty = item['quantity'] as int? ?? 0;
              final lineTotal =
                  (item['line_total'] as num?)?.toDouble() ?? 0;
              return pw.Padding(
                padding: const pw.EdgeInsets.symmetric(vertical: 2),
                child: pw.Row(children: [
                  pw.Expanded(
                    child:
                        pw.Text(name, style: const pw.TextStyle(fontSize: 8)),
                  ),
                  pw.Text('$qty',
                      style: const pw.TextStyle(fontSize: 8)),
                  pw.SizedBox(width: 8),
                  pw.Text(fmt(lineTotal),
                      style: const pw.TextStyle(fontSize: 8)),
                ]),
              );
            }),

            pw.SizedBox(height: 6),
            pw.Divider(thickness: 0.5),
            pw.SizedBox(height: 4),

            // Totals
            _row('Subtotal', fmt(subtotal), fontSize: 8),
            if (discount > 0)
              _row('Discount', '- ${fmt(discount)}', fontSize: 8),
            if (taxAmount > 0)
              _row(
                'Tax (${settings.taxPercentage.toStringAsFixed(1)}%)',
                fmt(taxAmount),
                fontSize: 8,
              ),
            pw.SizedBox(height: 4),
            pw.Divider(thickness: 0.5),
            _row('TOTAL', fmt(grandTotal),
                fontSize: 11, bold: true),
            pw.SizedBox(height: 2),
            _row('Payment', paymentMethod, fontSize: 8),

            pw.SizedBox(height: 8),
            pw.Divider(thickness: 0.5),
            pw.SizedBox(height: 4),

            // Footer
            pw.Text(
              settings.receiptFooter?.isNotEmpty == true
                  ? settings.receiptFooter!
                  : 'Thank you for shopping!',
              style: const pw.TextStyle(fontSize: 8),
              textAlign: pw.TextAlign.center,
            ),
          ],
        ),
      ),
    );

    return doc;
  }

  static pw.Widget _row(
    String label,
    String value, {
    double fontSize = 9,
    bool bold = false,
  }) {
    final style = bold
        ? pw.TextStyle(fontSize: fontSize, fontWeight: pw.FontWeight.bold)
        : pw.TextStyle(fontSize: fontSize);
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 1),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label, style: style),
          pw.Text(value, style: style),
        ],
      ),
    );
  }
}
