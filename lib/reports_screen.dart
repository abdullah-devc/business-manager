import 'package:flutter/material.dart';

import 'csv_export_service.dart';
import 'expenses_screen.dart';
import 'widgets/glass.dart';

/// Reports tab: expense management (the most-used report) plus CSV
/// export shortcuts for transactions, expenses, invoices, and balances.
class ReportsScreen extends StatelessWidget {
  const ReportsScreen({super.key});

  Future<void> _export(
    BuildContext context,
    Future<String?> Function() exportFn,
    String label,
  ) async {
    final path = await exportFn();
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          path != null ? '$label exported to $path' : 'Could not export $label',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ExpensesScreen(
      embedded: true,
      footer: _CsvExportSection(onExport: _export),
    );
  }
}

class _CsvExportSection extends StatelessWidget {
  const _CsvExportSection({required this.onExport});

  final Future<void> Function(BuildContext, Future<String?> Function(), String)
  onExport;

  @override
  Widget build(BuildContext context) {
    final buttons = [
      _CsvButton(
        label: 'Transactions',
        action: CsvExportService.exportTransactions,
      ),
      _CsvButton(label: 'Expenses', action: CsvExportService.exportExpenses),
      _CsvButton(label: 'Invoices', action: CsvExportService.exportInvoices),
      _CsvButton(label: 'Balances', action: CsvExportService.exportBalances),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final isPhone = constraints.maxWidth < 600;
        return AdaptiveBackgroundText(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Export CSV',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              const Text(
                'Download a spreadsheet-compatible copy of your records.',
              ),
              const SizedBox(height: 12),
              if (isPhone)
                ...buttons.map(
                  (button) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () =>
                            onExport(context, button.action, button.label),
                        icon: const Icon(Icons.download, size: 18),
                        label: Text('Export ${button.label} CSV'),
                      ),
                    ),
                  ),
                )
              else
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: buttons
                      .map(
                        (button) => OutlinedButton.icon(
                          onPressed: () =>
                              onExport(context, button.action, button.label),
                          icon: const Icon(Icons.download, size: 18),
                          label: Text('Export ${button.label} CSV'),
                        ),
                      )
                      .toList(),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _CsvButton {
  const _CsvButton({required this.label, required this.action});

  final String label;
  final Future<String?> Function() action;
}
