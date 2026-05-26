import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';
import 'package:flutter/services.dart';
import '../../../features/settings/data/models/shop_settings_model.dart';

/// Generates a thermal-style receipt PDF from sale data.
class ReceiptPdfService {
  ReceiptPdfService._();

  static Future<pw.Document> generate({
    required Map<String, dynamic> data,
    required ShopSettings settings,
  }) async {
    final doc = pw.Document();

    final invoiceNo = data['invoice_no'] as String? ?? '';
    final staffName = data['staff_name'] as String? ?? '';
    final customerName = data['customer_name'] as String? ?? 'Walk-in Customer';
    final subtotal = (data['subtotal'] as num?)?.toDouble() ?? 0;
    final discount = (data['discount'] as num?)?.toDouble() ?? 0;
    final taxAmount = (data['tax_amount'] as num?)?.toDouble() ?? 0;
    final grandTotal = (data['grand_total'] as num?)?.toDouble() ?? 0;
    final amountPaid = (data['amount_paid'] as num?)?.toDouble() ?? 0;
    final balanceDue = (data['balance_due'] as num?)?.toDouble() ?? 0;
    final payments = data['payments'] as List? ?? [];
    final createdAt = data['created_at'] as String? ?? '';
    final items = data['items'] as List? ?? [];

    DateTime? saleDate;
    try {
      saleDate = DateTime.parse(createdAt);
    } catch (_) {}
    
    final dateStr = saleDate != null ? DateFormat('dd/MM/yyyy').format(saleDate) : '';
    final timeStr = saleDate != null ? DateFormat('hh:mm a').format(saleDate) : '';

    String fmt(double v) {
      return NumberFormat.currency(
        symbol: 'LKR ',
        decimalDigits: 2,
      ).format(v);
    }

    final ByteData bytes = await rootBundle.load('assets/images/logo.png');
    final pw.MemoryImage logoImage = pw.MemoryImage(bytes.buffer.asUint8List());

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat(
          80 * PdfPageFormat.mm,
          double.infinity,
          marginAll: 5 * PdfPageFormat.mm,
        ),
        build: (ctx) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            // Business header
            pw.Center(
              child: pw.Text(
                settings.shopName,
                style: pw.TextStyle(
                  fontSize: 16,
                  fontWeight: pw.FontWeight.bold,
                ),
                textAlign: pw.TextAlign.center,
              ),
            ),
            if (settings.address != null && settings.address!.isNotEmpty) ...[
              pw.SizedBox(height: 2),
              pw.Center(
                child: pw.Text(
                  settings.address!,
                  style: const pw.TextStyle(fontSize: 10),
                  textAlign: pw.TextAlign.center,
                ),
              ),
            ],
            if (settings.phone != null && settings.phone!.isNotEmpty) ...[
              pw.SizedBox(height: 2),
              pw.Center(
                child: pw.Text(
                  'Tel: \${settings.phone}',
                  style: const pw.TextStyle(fontSize: 10),
                  textAlign: pw.TextAlign.center,
                ),
              ),
            ],
            pw.SizedBox(height: 12),
            pw.Center(
              child: pw.Text(
                'SALES RECEIPT',
                style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
              ),
            ),
            pw.SizedBox(height: 12),

            // Invoice info
            _infoRow('Invoice No:', invoiceNo),
            if (dateStr.isNotEmpty) _infoRow('Date:', dateStr),
            if (timeStr.isNotEmpty) _infoRow('Time:', timeStr),
            if (staffName.isNotEmpty) _infoRow('Cashier:', staffName),
            _infoRow('Customer:', customerName),
            pw.SizedBox(height: 8),
            pw.Divider(thickness: 1, borderStyle: pw.BorderStyle.dashed),
            pw.SizedBox(height: 4),

            // Items header
            pw.Center(
              child: pw.Text('ITEMS', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
            ),
            pw.SizedBox(height: 4),
            pw.Divider(thickness: 1, borderStyle: pw.BorderStyle.dashed),
            pw.SizedBox(height: 8),

            // Items
            ...items.map((item) {
              final name = item['product_name'] as String? ?? '';
              final qty = item['quantity'] as int? ?? 0;
              final unitPrice = (item['unit_price'] as num?)?.toDouble() ?? 0;
              final lineTotal = (item['line_total'] as num?)?.toDouble() ?? 0;
              return pw.Padding(
                padding: const pw.EdgeInsets.only(bottom: 8),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(name, style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                    pw.SizedBox(height: 2),
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text('$qty x ${fmt(unitPrice)}', style: const pw.TextStyle(fontSize: 10)),
                        pw.Text(fmt(lineTotal), style: const pw.TextStyle(fontSize: 10)),
                      ],
                    ),
                  ],
                ),
              );
            }),

            pw.SizedBox(height: 4),
            pw.Divider(thickness: 1, borderStyle: pw.BorderStyle.dashed),
            pw.SizedBox(height: 4),

            // Totals
            _summaryRow('Subtotal:', fmt(subtotal)),
            _summaryRow('Discount:', fmt(discount)),
            _summaryRow('Tax/VAT:', fmt(taxAmount)),
            
            pw.SizedBox(height: 4),
            pw.Divider(thickness: 1, borderStyle: pw.BorderStyle.dashed),
            pw.SizedBox(height: 4),
            
            _summaryRow('GRAND TOTAL:', fmt(grandTotal), bold: true, fontSize: 12),
            
            pw.SizedBox(height: 4),
            pw.Divider(thickness: 1, borderStyle: pw.BorderStyle.dashed),
            pw.SizedBox(height: 8),

            // Payments
            if (payments.length == 1) ...[
              _summaryRow('Payment Method:', payments.first['method'] as String? ?? 'Cash'),
              _summaryRow('Paid Amount:', fmt((payments.first['amount'] as num?)?.toDouble() ?? 0)),
              _summaryRow(balanceDue < 0 ? 'Change:' : 'Balance:', fmt(balanceDue.abs())),
            ] else if (payments.length > 1) ...[
              pw.Text('Payment Method:', style: const pw.TextStyle(fontSize: 10)),
              ...payments.map((p) {
                final method = p['method'] as String? ?? 'Unknown';
                final amt = (p['amount'] as num?)?.toDouble() ?? 0;
                return _summaryRow('  $method:', fmt(amt));
              }),
              _summaryRow('Total Paid:', fmt(amountPaid)),
              _summaryRow(balanceDue < 0 ? 'Change:' : 'Balance:', fmt(balanceDue.abs())),
            ] else ...[
              _summaryRow('Total Paid:', fmt(amountPaid)),
              _summaryRow(balanceDue < 0 ? 'Change:' : 'Balance:', fmt(balanceDue.abs())),
            ],

            pw.SizedBox(height: 16),

            // Footer
            pw.Center(
              child: pw.Text(
                settings.receiptFooter?.isNotEmpty == true
                    ? settings.receiptFooter!
                    : 'Thank you for shopping with us.\nGoods once sold are not returnable unless damaged.\nPlease keep this receipt for warranty/returns.',
                style: const pw.TextStyle(fontSize: 9),
                textAlign: pw.TextAlign.center,
              ),
            ),
            pw.SizedBox(height: 12),
            pw.Center(
              child: pw.Image(logoImage, height: 30),
            ),
          ],
        ),
      ),
    );

    return doc;
  }

  static pw.Widget _infoRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 1),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(
            width: 60,
            child: pw.Text(label, style: const pw.TextStyle(fontSize: 10)),
          ),
          pw.Expanded(
            child: pw.Text(value, style: const pw.TextStyle(fontSize: 10), textAlign: pw.TextAlign.right),
          ),
        ],
      ),
    );
  }

  static pw.Widget _summaryRow(
    String label,
    String value, {
    double fontSize = 10,
    bool bold = false,
  }) {
    final style = bold
        ? pw.TextStyle(fontSize: fontSize, fontWeight: pw.FontWeight.bold)
        : pw.TextStyle(fontSize: fontSize);
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
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
