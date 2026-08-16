import 'package:flutter/material.dart';
import 'database_helper.dart';
import 'add_transaction_screen.dart';
import 'date_utils.dart';
import 'transaction_detail_dialog.dart';
import 'delete_confirm.dart';
import 'transaction_status_utils.dart';
import 'transaction_report_pdf_service.dart';
import 'export_file_service.dart';
import 'widgets/glass.dart';
import 'widgets/app_background_controller.dart';

class TransactionsScreen extends StatefulWidget {
  final bool embedded;

  const TransactionsScreen({super.key, this.embedded = false});

  @override
  State<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends State<TransactionsScreen>
    with AutomaticKeepAliveClientMixin {
  List<Map<String, dynamic>> _transactions = [];
  List<Map<String, dynamic>> _companies = [];
  List<Map<String, dynamic>> _materials = [];

  String _search = '';
  PaymentStatus? _paymentFilter;
  String? _typeFilter;
  int? _companyFilter;
  int? _materialFilter;
  DateTimeRange? _dateRange;

  double _boughtTotal = 0;
  double _soldTotal = 0;
  double _youOwe = 0;
  double _theyOwe = 0;
  List<Map<String, dynamic>> _materialSummary = [];

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    final transactions = await DatabaseHelper.instance.getAllTransactions();
    final companies = await DatabaseHelper.instance.getAllCompanies();
    final materials = await DatabaseHelper.instance.getAllMaterials();

    double bought = 0;
    double sold = 0;
    double youOwe = 0;
    double theyOwe = 0;
    final Map<String, Map<String, dynamic>> summary = {};

    for (final t in transactions) {
      final quantity = (t['quantity'] as num).toDouble();
      final price = t['price'] != null ? (t['price'] as num).toDouble() : null;
      final amount = price != null ? quantity * price : 0.0;
      final materialName = t['material_name'] as String;
      final unit = t['material_unit'] as String;

      summary.putIfAbsent(materialName, () => {
            'name': materialName,
            'unit': unit,
            'bought_qty': 0.0,
            'sold_qty': 0.0,
            'bought_amount': 0.0,
            'sold_amount': 0.0,
          });

      if (t['type'] == 'in') {
        bought += amount;
        summary[materialName]!['bought_qty'] += quantity;
        summary[materialName]!['bought_amount'] += amount;
      } else {
        sold += amount;
        summary[materialName]!['sold_qty'] += quantity;
        summary[materialName]!['sold_amount'] += amount;
      }
      if (price != null) {
        final amountPaid = (t['amount_paid'] as num).toDouble();
        final due = amount - amountPaid;
        if (due > 0) {
          if (t['type'] == 'in') {
            youOwe += due;
          } else {
            theyOwe += due;
          }
        }
      }
    }

    final summaryList = summary.values.toList()
      ..sort((a, b) => (a['name'] as String).compareTo(b['name'] as String));

    setState(() {
      _transactions = transactions;
      _companies = companies;
      _materials = materials;
      _boughtTotal = bought;
      _soldTotal = sold;
      _youOwe = youOwe;
      _theyOwe = theyOwe;
      _materialSummary = summaryList;
    });
  }

  bool get _hasActiveFilters =>
      _paymentFilter != null ||
      _typeFilter != null ||
      _companyFilter != null ||
      _materialFilter != null ||
      _dateRange != null;

  void _clearFilters() {
    setState(() {
      _paymentFilter = null;
      _typeFilter = null;
      _companyFilter = null;
      _materialFilter = null;
      _dateRange = null;
    });
  }

  bool _matchesDateRange(String isoDate) {
    if (_dateRange == null) return true;
    final dt = DateTime.parse(isoDate).toLocal();
    final dateOnly = DateTime(dt.year, dt.month, dt.day);
    final start = DateTime(_dateRange!.start.year, _dateRange!.start.month, _dateRange!.start.day);
    final end = DateTime(_dateRange!.end.year, _dateRange!.end.month, _dateRange!.end.day);
    return !dateOnly.isBefore(start) && !dateOnly.isAfter(end);
  }

  List<Map<String, dynamic>> get _filteredTransactions {
    return _transactions.where((t) {
      if (_search.trim().isNotEmpty) {
        final q = _search.trim().toLowerCase();
        final material = (t['material_name'] ?? '').toString().toLowerCase();
        final company = (t['company_name'] ?? '').toString().toLowerCase();
        final notes = (t['notes'] ?? '').toString().toLowerCase();
        final transactionNumber = (t['transaction_number'] ?? '').toString().toLowerCase();
        if (!material.contains(q) && !company.contains(q) && !notes.contains(q) && !transactionNumber.contains(q)) return false;
      }
      if (_paymentFilter != null && getPaymentStatus(t) != _paymentFilter) return false;
      if (_typeFilter != null && t['type'] != _typeFilter) return false;
      if (_companyFilter != null && t['company_id'] != _companyFilter) return false;
      if (_materialFilter != null && t['material_id'] != _materialFilter) return false;
      if (!_matchesDateRange(t['transaction_date'])) return false;
      return true;
    }).toList();
  }

  Future<void> _pickDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      initialDateRange: _dateRange,
    );
    if (picked != null) setState(() => _dateRange = picked);
  }

  Future<void> _savePdf() async {
    try {
      final bytes = await TransactionReportPdfService.generate(
        title: 'Transactions Report',
        transactions: _filteredTransactions,
        dateRange: _dateRange == null ? null : DateTimeRangeInfo(_dateRange!.start, _dateRange!.end),
      );
      final path = await ExportFileService.saveBytes(
        suggestedName: 'transactions-report.pdf',
        bytes: bytes,
        mimeType: 'application/pdf',
        title: 'Save transactions PDF',
      );
      if (path != null && mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('PDF saved to $path')));
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not save transactions PDF: $error')));
    }
  }

  Future<void> _viewTransactionDialog(Map<String, dynamic> t) async {
    final changed = await showTransactionDetailDialog(context, t);
    if (changed) _loadAll();
  }

  Future<void> _deleteTransaction(Map<String, dynamic> t) async {
    final allowed = await confirmDeleteWithPassword(
      context,
      title: 'Delete Transaction?',
      warning: 'This will also reverse its effect on stock and delete any payments recorded against it. This cannot be undone.',
    );
    if (!allowed) return;
    final isIn = t['type'] == 'in';
    final quantity = (t['quantity'] as num).toDouble();
    final reverseAmount = isIn ? -quantity : quantity;
    if ((t['item_type'] ?? 'material') == 'material' && t['material_id'] != null) {
      await DatabaseHelper.instance.updateMaterialStock(t['material_id'] as int, reverseAmount);
    }
    await DatabaseHelper.instance.deleteTransaction(t['id']);
    _loadAll();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final filtered = _filteredTransactions;

    return Scaffold(
      appBar: widget.embedded ? null : AppBar(title: const Text('Transactions'), actions: [IconButton(icon: const Icon(Icons.picture_as_pdf), tooltip: 'Save PDF', onPressed: _savePdf)]),
      floatingActionButton: Padding(
        // When embedded inside the main tab scaffold, that scaffold has
        // its own round "Quick Add" FAB pinned bottom-right, which sits
        // in the same corner as this button and overlaps it. Shift this
        // one to the left so both are visible without colliding.
        padding: EdgeInsets.only(right: widget.embedded ? 72.0 : 0.0),
        child: FloatingActionButton.extended(
          onPressed: () async {
            final added = await Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const AddTransactionScreen()),
            );
            if (added == true) _loadAll();
          },
          icon: const Icon(Icons.add),
          label: const Text('Add Transaction'),
        ),
      ),
      body: AdaptiveBackgroundText(
        child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              decoration: const InputDecoration(
                labelText: 'Search by product, company, number, or notes',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (value) => setState(() => _search = value),
            ),
            ValueListenableBuilder<double>(
              valueListenable: AppBackgroundController.instance.brightness,
              builder: (context, brightness, _) {
                final isDarkMode = brightness < 0.5;
                final textColor = isDarkMode ? Colors.white : Colors.black87;

                return Theme(
                  data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                  child: ExpansionTile(
                    title: Row(
                      children: [
                        Text(
                          'Filters',
                          style: TextStyle(color: textColor),
                        ),
                        if (_hasActiveFilters) ...[
                          const SizedBox(width: 8),
                          const CircleAvatar(radius: 4, backgroundColor: Colors.blue),
                        ],
                      ],
                    ),
                    tilePadding: EdgeInsets.zero,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12.0),
                        child: Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: [
                            SizedBox(
                              width: 180,
                              child: AdaptiveDropdownButtonFormField<PaymentStatus?>(
                                value: _paymentFilter,
                                decoration: const InputDecoration(labelText: 'Payment Status'),
                                items: const [
                                  DropdownMenuItem(value: null, child: Text('All')),
                                  DropdownMenuItem(value: PaymentStatus.paid, child: Text('Paid')),
                                  DropdownMenuItem(value: PaymentStatus.partial, child: Text('Partial')),
                                  DropdownMenuItem(value: PaymentStatus.unpaid, child: Text('Unpaid')),
                                ],
                                onChanged: (value) => setState(() => _paymentFilter = value),
                              ),
                            ),
                            SizedBox(
                              width: 150,
                              child: AdaptiveDropdownButtonFormField<String?>(
                                value: _typeFilter,
                                decoration: const InputDecoration(labelText: 'Type'),
                                items: const [
                                  DropdownMenuItem(value: null, child: Text('All')),
                                  DropdownMenuItem(value: 'in', child: Text('Bought (In)')),
                                  DropdownMenuItem(value: 'out', child: Text('Sold (Out)')),
                                ],
                                onChanged: (value) => setState(() => _typeFilter = value),
                              ),
                            ),
                            SizedBox(
                              width: 200,
                              child: AdaptiveDropdownButtonFormField<int?>(
                                value: _companyFilter,
                                decoration: const InputDecoration(labelText: 'Company'),
                                items: [
                                  const DropdownMenuItem(value: null, child: Text('All')),
                                  ..._companies.map((c) => DropdownMenuItem<int?>(
                                        value: c['id'] as int,
                                        child: Text(c['name']),
                                      )),
                                ],
                                onChanged: (value) => setState(() => _companyFilter = value),
                              ),
                            ),
                            SizedBox(
                              width: 200,
                              child: AdaptiveDropdownButtonFormField<int?>(
                                value: _materialFilter,
                                decoration: const InputDecoration(labelText: 'Material'),
                                items: [
                                  const DropdownMenuItem(value: null, child: Text('All')),
                                  ..._materials.map((m) => DropdownMenuItem<int?>(
                                        value: m['id'] as int,
                                        child: Text(m['name']),
                                      )),
                                ],
                                onChanged: (value) => setState(() => _materialFilter = value),
                              ),
                            ),
                            SizedBox(
                              width: 230,
                              child: OutlinedButton.icon(
                                onPressed: _pickDateRange,
                                icon: const Icon(Icons.date_range),
                                label: Text(
                                  _dateRange == null
                                      ? 'Date Range'
                                      : '${_dateRange!.start.toString().split(' ').first} → ${_dateRange!.end.toString().split(' ').first}',
                                ),
                              ),
                            ),
                            OutlinedButton.icon(
                              onPressed: _savePdf,
                              icon: const Icon(Icons.picture_as_pdf),
                              label: const Text('Save PDF'),
                            ),
                            if (_hasActiveFilters)
                              TextButton.icon(
                                onPressed: _clearFilters,
                                icon: const Icon(Icons.clear),
                                label: const Text('Clear Filters'),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
            ValueListenableBuilder<double>(
              valueListenable: AppBackgroundController.instance.brightness,
              builder: (context, brightness, _) {
                final isDarkMode = brightness < 0.5;
                final summaryBackgroundColor = isDarkMode ? const Color(0xFF2A2A2A) : Colors.grey.shade100;
                final summaryTextColor = isDarkMode ? Colors.white : Colors.black87;
                final subtleTextColor = isDarkMode ? Colors.grey.shade400 : Colors.blueGrey;
                final titleTextColor = isDarkMode ? Colors.white : Colors.black87;
                final subtitleTextColor = isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600;

                return Theme(
                  data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                  child: ExpansionTile(
                    tilePadding: EdgeInsets.zero,
                    leading: Icon(Icons.analytics_outlined, color: titleTextColor),
                    title: Text(
                      'Transaction Summary',
                      style: TextStyle(color: titleTextColor),
                    ),
                    subtitle: Text(
                      'Totals, balances, and material breakdown',
                      style: TextStyle(color: subtitleTextColor),
                    ),
                    children: [
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        color: summaryBackgroundColor,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Total Bought: ${_boughtTotal.toStringAsFixed(2)}',
                              style: TextStyle(color: summaryTextColor),
                            ),
                            Text(
                              'Total Sold: ${_soldTotal.toStringAsFixed(2)}',
                              style: TextStyle(color: summaryTextColor),
                            ),
                            if (_youOwe > 0.01)
                              Text(
                                'You Owe Them: ${_youOwe.toStringAsFixed(2)}',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.red.shade400,
                                ),
                              ),
                            if (_theyOwe > 0.01)
                              Text(
                                'They Owe You: ${_theyOwe.toStringAsFixed(2)}',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green.shade400,
                                ),
                              ),
                            if (_materialSummary.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Text(
                                'By Material:',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: summaryTextColor,
                                ),
                              ),
                              ..._materialSummary.map((m) => Padding(
                                    padding: const EdgeInsets.only(top: 2.0),
                                    child: Text(
                                      '${m['name']}: bought ${(m['bought_qty'] as double).toStringAsFixed(1)} ${m['unit']} (${(m['bought_amount'] as double).toStringAsFixed(2)}), '
                                      'sold ${(m['sold_qty'] as double).toStringAsFixed(1)} ${m['unit']} (${(m['sold_amount'] as double).toStringAsFixed(2)})',
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: summaryTextColor,
                                      ),
                                    ),
                                  )),
                            ],
                            if (filtered.length != _transactions.length)
                              Padding(
                                padding: const EdgeInsets.only(top: 8.0),
                                child: Text(
                                  'Showing ${filtered.length} of ${_transactions.length} transactions (filtered)',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: subtleTextColor,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
            const Divider(height: 24),
            Expanded(
              child: filtered.isEmpty
                  ? const Center(child: Text('No transactions found.'))
                  : ListView.builder(
                      itemCount: filtered.length,
                      itemBuilder: (context, index) {
                        final t = filtered[index];
                        final isIn = t['type'] == 'in';
                        final statusLabel = paymentStatusLabel(getPaymentStatus(t));

                        return ListTile(
                          leading: Icon(
                            isIn ? Icons.arrow_downward : Icons.arrow_upward,
                            color: isIn ? Colors.green : Colors.red,
                          ),
                          title: Text('${t['material_name']} — ${t['quantity']} ${t['material_unit']}'),
                          subtitle: Text(
                            '${isIn ? 'Bought from' : 'Sold to'} ${t['company_name']}${statusLabel.isNotEmpty ? ' • $statusLabel' : ''}\n'
                            '${formatDateTime(t['transaction_date'])}${(t['transaction_number'] as String?)?.trim().isNotEmpty ?? false ? ' â€¢ #${t['transaction_number']}' : ''}',
                          ),
                          isThreeLine: true,
                          onTap: () => _viewTransactionDialog(t),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () => _deleteTransaction(t),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
        ),
      ),
    );
  }

  @override
  bool get wantKeepAlive => true;
}
