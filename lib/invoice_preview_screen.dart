import 'package:flutter/material.dart';
import 'package:printing/printing.dart';

import 'invoice_pdf_service.dart';

class InvoicePreviewScreen extends StatelessWidget {
  final Map<String, dynamic> invoice;
  final List<Map<String, dynamic>> lineItems;

  const InvoicePreviewScreen({super.key, required this.invoice, required this.lineItems});

  @override
  Widget build(BuildContext context) {
    final number = invoice['invoice_number']?.toString().trim();
    return Scaffold(
      appBar: AppBar(title: Text(number == null || number.isEmpty ? 'Document Preview' : 'Preview $number')),
      body: PdfPreview(
        build: (_) => InvoicePdfService.generate(invoice: invoice, lineItems: lineItems),
        canChangeOrientation: false,
        canChangePageFormat: false,
        allowPrinting: true,
        allowSharing: true,
      ),
    );
  }
}
