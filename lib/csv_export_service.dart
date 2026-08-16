import 'database_helper.dart';
import 'export_file_service.dart';

class CsvExportService {
  static Future<String?> exportTransactions() async {
    final rows = await DatabaseHelper.instance.getAllTransactions();
    return _save(
      'transactions',
      [
        'ID',
        'Date',
        'Type',
        'Company',
        'Material',
        'Quantity',
        'Unit',
        'Unit Price',
        'Amount Paid',
        'Notes',
      ],
      rows.map(
        (row) => [
          row['id'],
          row['transaction_date'],
          row['type'],
          row['company_name'],
          row['material_name'],
          row['quantity'],
          row['material_unit'],
          row['price'],
          row['amount_paid'],
          row['notes'],
        ],
      ),
    );
  }

  static Future<String?> exportExpenses() async {
    final rows = await DatabaseHelper.instance.getAllExpenses();
    return _save(
      'expenses',
      ['ID', 'Date', 'Category', 'Description', 'Amount', 'Deducted From'],
      rows.map(
        (row) => [
          row['id'],
          row['expense_date'],
          row['category'],
          row['description'],
          row['amount'],
          row['balance_name'],
        ],
      ),
    );
  }

  static Future<String?> exportInvoices() async {
    final rows = await DatabaseHelper.instance.getAllInvoices();
    return _save(
      'invoices',
      [
        'ID',
        'Document Type',
        'Invoice Number',
        'Company',
        'Status',
        'Issue Date',
        'Due Date',
        'Total',
        'Paid',
        'Remaining',
      ],
      rows.map((row) {
        final total = (row['total_amount'] as num).toDouble();
        final paid = (row['amount_paid'] as num).toDouble();
        return [
          row['id'],
          row['document_type'] ?? 'invoice',
          row['invoice_number'],
          row['company_name'],
          row['status'],
          row['issue_date'],
          row['due_date'],
          total,
          paid,
          total - paid,
        ];
      }),
    );
  }

  static Future<String?> exportBalances() async {
    final rows = await DatabaseHelper.instance.getAllExpenseBalances();
    return _save('balances', [
      'ID',
      'Balance Name',
      'Current Balance',
    ], rows.map((row) => [row['id'], row['name'], row['current_balance']]));
  }

  static Future<String?> _save(
    String name,
    List<String> headers,
    Iterable<List<dynamic>> rows,
  ) async {
    final lines = <String>[_line(headers)];
    lines.addAll(rows.map(_line));
    return ExportFileService.saveText(
      suggestedName:
          'business-manager-$name-${DateTime.now().toIso8601String().replaceAll(':', '-')}.csv',
      contents: lines.join('\r\n'),
      title: 'Save BizRise $name CSV',
    );
  }

  static String _line(Iterable<dynamic> values) => values
      .map((value) {
        final text = value?.toString() ?? '';
        return '"${text.replaceAll('"', '""')}"';
      })
      .join(',');
}
