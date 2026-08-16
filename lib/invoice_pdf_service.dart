import 'dart:io';
import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import 'export_file_service.dart';

import 'database_helper.dart';

class InvoicePdfService {
  static Future<Uint8List> generate({
    required Map<String, dynamic> invoice,
    required List<Map<String, dynamic>> lineItems,
  }) async {
    final document = pw.Document();
    final profile = await DatabaseHelper.instance.getBusinessProfile();
    final template = _text(profile['invoice_template'], fallback: 'classic');
    final accent = _colorFromHex(_text(profile['accent_color'], fallback: '#1F5AA6'));
    final documentType = _text(invoice['document_type'], fallback: 'invoice');
    final documentTitle = documentType == 'proforma'
        ? 'PROFORMA INVOICE'
        : documentType == 'quote'
            ? 'QUOTE'
            : 'INVOICE';
    final compact = template == 'compact';
    final detailed = template == 'detailed';
    pw.MemoryImage? logoImage;
    final logoPath = _text(profile['logo_path']);
    if (logoPath.isNotEmpty && File(logoPath).existsSync()) {
      try {
        logoImage = pw.MemoryImage(await File(logoPath).readAsBytes());
      } catch (_) {
        logoImage = null;
      }
    }
    pw.MemoryImage? signatureImage;
    final signaturePath = await DatabaseHelper.instance.getAppSetting('invoice_signature_path');
    if (signaturePath != null && signaturePath.trim().isNotEmpty && File(signaturePath).existsSync()) {
      try {
        signatureImage = pw.MemoryImage(await File(signaturePath).readAsBytes());
      } catch (_) {
        signatureImage = null;
      }
    }
    final total = lineItems.fold<double>(0, (sum, item) {
      final quantity = (item['quantity'] as num).toDouble();
      final price = item['price'] == null ? 0.0 : (item['price'] as num).toDouble();
      return sum + quantity * price;
    });
    final marginValue = compact ? 24.0 : 36.0;
    // Estimated height (in points) of everything from the header down through
    // Grand Total, so we can insert a spacer that pushes the notes/terms/
    // signature block to roughly the vertical middle of the page on short
    // invoices. This is an estimate, not a measurement — the pdf package
    // doesn't expose rendered widget heights inside build(). We deliberately
    // do NOT wrap the table itself in a sizing widget: pw.Table is one of the
    // few widgets pw.MultiPage can split across pages natively, and wrapping
    // it in a non-spanning widget (e.g. ConstrainedBox) would break that and
    // risk an overflow error on long item lists.
    final baseContentHeight = compact ? 230.0 : 260.0;
    final estimatedRowHeight = 20.0;
    final estimatedContentHeight = baseContentHeight + lineItems.length * estimatedRowHeight;
    final halfPageHeight = (PdfPageFormat.a4.height - marginValue * 2) / 2;
    final footerSpacerHeight = (halfPageHeight - estimatedContentHeight).clamp(0.0, halfPageHeight);

    document.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: pw.EdgeInsets.all(marginValue),
        maxPages: 1000,
        build: (context) => [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                child: pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    if (logoImage != null)
                      pw.Padding(
                        padding: const pw.EdgeInsets.only(right: 12),
                        child: pw.Image(logoImage, width: 64, height: 64, fit: pw.BoxFit.contain),
                      ),
                    pw.Expanded(
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(_text(profile['business_name'], fallback: 'BizRise').toUpperCase(), style: pw.TextStyle(fontSize: compact ? 16 : 20, fontWeight: pw.FontWeight.bold, color: template == 'modern' ? accent : null)),
                          if (_text(profile['contact_person']).isNotEmpty) pw.Text(_text(profile['contact_person'])),
                          if (_text(profile['phone']).isNotEmpty) pw.Text(_text(profile['phone'])),
                          if (_text(profile['email']).isNotEmpty) pw.Text(_text(profile['email'])),
                          if (_text(profile['address']).isNotEmpty) pw.Text(_text(profile['address'])),
                          if (_text(profile['tax_number']).isNotEmpty) pw.Text('Tax No: ${_text(profile['tax_number'])}'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text(documentTitle, style: pw.TextStyle(fontSize: compact ? 15 : 18, fontWeight: pw.FontWeight.bold, color: template == 'modern' ? accent : null)),
                  pw.Text((invoice['invoice_number'] ?? 'Draft invoice').toString()),
                ],
              ),
            ],
          ),
          if (template == 'modern') ...[
            pw.SizedBox(height: 12),
            pw.Container(height: 5, color: accent),
          ],
          pw.SizedBox(height: compact ? 12 : 24),
          pw.Text('Bill To', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
          pw.Text((invoice['company_name'] ?? 'Company').toString()),
          if (_text(invoice['contact_person']).isNotEmpty) pw.Text(_text(invoice['contact_person'])),
          if (_text(invoice['phone']).isNotEmpty) pw.Text(_text(invoice['phone'])),
          if (_text(invoice['address']).isNotEmpty) pw.Text(_text(invoice['address'])),
          pw.SizedBox(height: 16),
          pw.Row(
            children: [
              pw.Expanded(child: pw.Text('Issue date: ${_date(invoice['issue_date'])}')),
              pw.Expanded(child: pw.Text('Due date: ${_date(invoice['due_date'], fallback: 'Not set')}')),
              pw.Text('Status: ${_text(invoice['status']).toUpperCase()}'),
            ],
          ),
          if (_text(invoice['valid_until']).isNotEmpty)
            pw.Padding(
              padding: const pw.EdgeInsets.only(top: 4),
              child: pw.Text('Valid until: ${_date(invoice['valid_until'])}'),
            ),
          pw.SizedBox(height: 20),
          pw.TableHelper.fromTextArray(
            headers: const ['Item', 'Quantity', 'Unit Price', 'Total'],
            data: lineItems.map((item) {
              final quantity = (item['quantity'] as num).toDouble();
              final price = item['price'] == null ? 0.0 : (item['price'] as num).toDouble();
              return [
                '${_text(item['material_name'])}${_text(item['material_unit']).isEmpty ? '' : ' (${_text(item['material_unit'])})'}',
                quantity.toString(),
                price.toStringAsFixed(2),
                (quantity * price).toStringAsFixed(2),
              ];
            }).toList(),
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
            headerDecoration: pw.BoxDecoration(color: template == 'classic' ? PdfColors.blueGrey700 : accent),
            cellAlignment: pw.Alignment.centerLeft,
          ),
          pw.SizedBox(height: 12),
          pw.Align(
            alignment: pw.Alignment.centerRight,
            child: pw.Text(
              'Grand Total: ${total.toStringAsFixed(2)}',
              style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: template == 'classic' ? PdfColors.blueGrey700 : accent),
            ),
          ),
          if (footerSpacerHeight > 0) pw.SizedBox(height: footerSpacerHeight),
          if (_text(invoice['notes']).isNotEmpty ||
              _text(invoice['terms']).isNotEmpty ||
              _text(profile['payment_instructions']).isNotEmpty ||
              signatureImage != null ||
              _text(profile['invoice_footer']).isNotEmpty) ...[
            pw.SizedBox(height: 20),
            pw.Divider(color: PdfColors.grey400),
            pw.SizedBox(height: 10),
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Expanded(
                  child: pw.Padding(
                    padding: const pw.EdgeInsets.only(right: 20),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        if (_text(invoice['notes']).isNotEmpty) ...[
                          pw.Text('Notes', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11)),
                          pw.SizedBox(height: 4),
                          pw.Text(_text(invoice['notes']), maxLines: 5, style: const pw.TextStyle(fontSize: 10)),
                        ],
                        if (_text(invoice['terms']).isNotEmpty) ...[
                          pw.SizedBox(height: _text(invoice['notes']).isNotEmpty ? 14 : 0),
                          pw.Text('Terms & Payment Instructions', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11)),
                          pw.SizedBox(height: 4),
                          pw.Text(_text(invoice['terms']), maxLines: 5, style: const pw.TextStyle(fontSize: 10)),
                        ],
                        if (_text(profile['payment_instructions']).isNotEmpty && (detailed || _text(invoice['terms']).isEmpty)) ...[
                          pw.SizedBox(height: 14),
                          pw.Text('Payment Instructions', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11)),
                          pw.SizedBox(height: 4),
                          pw.Text(_text(profile['payment_instructions']), maxLines: 5, style: const pw.TextStyle(fontSize: 10)),
                        ],
                      ],
                    ),
                  ),
                ),
                pw.SizedBox(
                  width: 150,
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.center,
                    children: [
                      if (signatureImage != null) ...[
                        pw.Image(signatureImage, width: 130, height: 50, fit: pw.BoxFit.contain),
                        pw.SizedBox(height: 4),
                      ] else
                        pw.SizedBox(height: 34),
                      pw.Container(width: 130, child: pw.Divider(color: PdfColors.grey600)),
                      pw.Text('Authorized Signature', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
                    ],
                  ),
                ),
              ],
            ),
            if (_text(profile['invoice_footer']).isNotEmpty) ...[
              pw.SizedBox(height: 14),
              pw.Divider(color: PdfColors.grey400),
              pw.SizedBox(height: 6),
              pw.Center(
                child: pw.Text(
                  _text(profile['invoice_footer']),
                  maxLines: 2,
                  style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
                ),
              ),
            ],
          ],
        ],
      ),
    );
    return document.save();
  }

  static Future<String?> save({
    required Map<String, dynamic> invoice,
    required List<Map<String, dynamic>> lineItems,
  }) async {
    final fileName = '${_safeFileName(_text(invoice['invoice_number'], fallback: 'invoice'))}.pdf';
    return ExportFileService.saveBytes(
      suggestedName: fileName,
      bytes: await generate(invoice: invoice, lineItems: lineItems),
      mimeType: 'application/pdf',
      title: 'Save invoice PDF',
    );
  }

  static Future<bool> share({
    required Map<String, dynamic> invoice,
    required List<Map<String, dynamic>> lineItems,
  }) async {
    final fileName = '${_safeFileName(_text(invoice['invoice_number'], fallback: 'invoice'))}.pdf';
    return ExportFileService.shareBytes(
      fileName: fileName,
      bytes: await generate(invoice: invoice, lineItems: lineItems),
      mimeType: 'application/pdf',
      title: 'Share invoice PDF',
    );
  }

  static Future<void> print({
    required Map<String, dynamic> invoice,
    required List<Map<String, dynamic>> lineItems,
  }) {
    return Printing.layoutPdf(
      name: _safeFileName(_text(invoice['invoice_number'], fallback: 'invoice')),
      onLayout: (_) => generate(invoice: invoice, lineItems: lineItems),
    );
  }

  static String _text(dynamic value, {String fallback = ''}) => value?.toString().trim().isEmpty ?? true ? fallback : value.toString().trim();

  static String _date(dynamic value, {String fallback = ''}) {
    final text = _text(value, fallback: fallback);
    if (text.isEmpty) return fallback;
    final parsed = DateTime.tryParse(text);
    if (parsed == null) return text.contains('T') ? text.split('T').first : text;
    final day = parsed.day.toString().padLeft(2, '0');
    final month = parsed.month.toString().padLeft(2, '0');
    return '$day/$month/${parsed.year}';
  }

  static String _safeFileName(String name) => name.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_');

  static PdfColor _colorFromHex(String hex) {
    final normalized = hex.replaceAll('#', '');
    final value = int.tryParse(normalized, radix: 16) ?? 0x1F5AA6;
    return PdfColor((value >> 16 & 0xFF) / 255, (value >> 8 & 0xFF) / 255, (value & 0xFF) / 255);
  }
}