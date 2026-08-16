import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'transaction_status_utils.dart';

class TransactionReportPdfService {
  static Future<Uint8List> generate({
    required String title,
    String? companyName,
    required List<Map<String, dynamic>> transactions,
    DateTimeRangeInfo? dateRange,
  }) async {
    final document = pw.Document();

    double bought = 0;
    double sold = 0;
    double paid = 0;
    double due = 0;
    for (final t in transactions) {
      final quantity = (t['quantity'] as num?)?.toDouble() ?? 0;
      final price = (t['price'] as num?)?.toDouble();
      final amount = price == null ? 0 : quantity * price;
      final amountPaid = (t['amount_paid'] as num?)?.toDouble() ?? 0;
      if (t['type'] == 'in') {
        bought += amount;
      } else {
        sold += amount;
      }
      paid += amountPaid;
      due += (amount - amountPaid).clamp(0, double.infinity).toDouble();
    }

    final subtitleParts = <String>[];
    if (companyName != null && companyName.trim().isNotEmpty) {
      subtitleParts.add('Company: $companyName');
    }
    if (dateRange != null) {
      subtitleParts.add('Date: ${_date(dateRange.start)} - ${_date(dateRange.end)}');
    }

    document.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(28),
        maxPages: 1000,
        header: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(title, style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
            if (subtitleParts.isNotEmpty) ...[
              pw.SizedBox(height: 4),
              pw.Text(subtitleParts.join('   •   '), style: const pw.TextStyle(fontSize: 9)),
            ],
            pw.SizedBox(height: 10),
          ],
        ),
        footer: (context) => pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.Text('Page ${context.pageNumber} of ${context.pagesCount}', style: const pw.TextStyle(fontSize: 8)),
        ),
        build: (context) => [
          pw.Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              _summary('Bought', bought),
              _summary('Sold', sold),
              _summary('Paid', paid),
              _summary('Due', due),
            ],
          ),
          pw.SizedBox(height: 12),
          if (transactions.isEmpty)
            pw.Padding(
              padding: const pw.EdgeInsets.symmetric(vertical: 30),
              child: pw.Center(child: pw.Text('No transactions match the selected filters.')),
            )
          else
            pw.TableHelper.fromTextArray(
              headers: const ['Date', 'Type', 'Company', 'Item', 'Qty', 'Price', 'Total', 'Paid', 'Due', 'Status'],
              data: transactions.map((t) {
                final quantity = (t['quantity'] as num?)?.toDouble() ?? 0;
                final price = (t['price'] as num?)?.toDouble();
                final total = price == null ? 0.0 : quantity * price;
                final amountPaid = (t['amount_paid'] as num?)?.toDouble() ?? 0;
                final rowDue = (total - amountPaid).clamp(0, double.infinity).toDouble();
                return [
                  _dateTime(t['transaction_date']),
                  t['type'] == 'in' ? 'Bought' : 'Sold',
                  '${t['company_name'] ?? ''}',
                  '${t['material_name'] ?? ''}',
                  _number(quantity),
                  price == null ? '-' : _money(price),
                  price == null ? '-' : _money(total),
                  _money(amountPaid),
                  price == null ? '-' : _money(rowDue),
                  paymentStatusLabel(getPaymentStatus(t)),
                ];
              }).toList(),
              headerStyle: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold),
              cellStyle: const pw.TextStyle(fontSize: 6.5),
              cellAlignment: pw.Alignment.centerLeft,
              headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
              border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.4),
              cellPadding: const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 4),
              columnWidths: const {
                0: pw.FlexColumnWidth(1.2),
                1: pw.FlexColumnWidth(.8),
                2: pw.FlexColumnWidth(1.5),
                3: pw.FlexColumnWidth(1.5),
                4: pw.FlexColumnWidth(.7),
                5: pw.FlexColumnWidth(.9),
                6: pw.FlexColumnWidth(1),
                7: pw.FlexColumnWidth(.9),
                8: pw.FlexColumnWidth(.9),
                9: pw.FlexColumnWidth(.9),
              },
            ),
        ],
      ),
    );

    return document.save();
  }

  static pw.Widget _summary(String label, double value) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey400)),
      child: pw.Text('$label: ${_money(value)}', style: const pw.TextStyle(fontSize: 8)),
    );
  }

  static String _money(double value) => value.toStringAsFixed(2);
  static String _number(double value) => value.toStringAsFixed(value == value.roundToDouble() ? 0 : 2);

  static String _date(DateTime value) {
    final dt = value.toLocal();
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
  }

  static String _dateTime(dynamic value) {
    try {
      final dt = DateTime.parse(value.toString()).toLocal();
      return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
    } catch (_) {
      return value?.toString() ?? '';
    }
  }
}

class DateTimeRangeInfo {
  final DateTime start;
  final DateTime end;
  const DateTimeRangeInfo(this.start, this.end);
}
