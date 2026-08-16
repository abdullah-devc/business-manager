import 'package:flutter/material.dart';
import 'database_helper.dart';
import 'date_utils.dart';
import 'transaction_detail_dialog.dart';
import 'transaction_status_utils.dart';
import 'transaction_report_pdf_service.dart';
import 'export_file_service.dart';
import 'widgets/glass.dart';

class LedgerScreen extends StatefulWidget {
  final int companyId;
  final String companyName;

  const LedgerScreen({super.key, required this.companyId, required this.companyName});

  @override
  State<LedgerScreen> createState() => _LedgerScreenState();
}

class _LedgerScreenState extends State<LedgerScreen> {
  List<Map<String, dynamic>> _transactions = [];
  List<Map<String, dynamic>> _materialTotals = [];
  double _youOwe = 0;
  double _theyOwe = 0;
  double _boughtTotal = 0;
  double _soldTotal = 0;

  PaymentStatus? _paymentFilter;
  String? _typeFilter;
  DateTimeRange? _dateRange;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final data = await DatabaseHelper.instance.getTransactionsByCompany(widget.companyId);
    final materialTotals = await DatabaseHelper.instance.getMaterialTotalsByCompany(widget.companyId);
    double youOwe = 0;
    double theyOwe = 0;
    double bought = 0;
    double sold = 0;
    for (final t in data) {
      if (t['price'] != null) {
        final quantity = (t['quantity'] as num).toDouble();
        final price = (t['price'] as num).toDouble();
        final amount = quantity * price;
        final amountPaid = (t['amount_paid'] as num).toDouble();
        final due = amount - amountPaid;
        if (t['type'] == 'in') {
          bought += amount;
          if (due > 0) youOwe += due;
        } else {
          sold += amount;
          if (due > 0) theyOwe += due;
        }
      }
    }
    setState(() {
      _transactions = data;
      _materialTotals = materialTotals;
      _youOwe = youOwe;
      _theyOwe = theyOwe;
      _boughtTotal = bought;
      _soldTotal = sold;
    });
  }

  bool get _hasActiveFilters => _paymentFilter != null || _typeFilter != null || _dateRange != null;

  bool _matchesDateRange(dynamic value) {
    if (_dateRange == null) return true;
    final parsed = DateTime.tryParse(value?.toString() ?? '');
    if (parsed == null) return false;
    final date = parsed.toLocal();
    final day = DateTime(date.year, date.month, date.day);
    final start = DateTime(_dateRange!.start.year, _dateRange!.start.month, _dateRange!.start.day);
    final end = DateTime(_dateRange!.end.year, _dateRange!.end.month, _dateRange!.end.day);
    return !day.isBefore(start) && !day.isAfter(end);
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
        title: '${widget.companyName} — Ledger',
        companyName: widget.companyName,
        transactions: _filteredTransactions,
        dateRange: _dateRange == null ? null : DateTimeRangeInfo(_dateRange!.start, _dateRange!.end),
      );
      final safe = widget.companyName.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_');
      final path = await ExportFileService.saveBytes(
        suggestedName: '${safe}_ledger.pdf',
        bytes: bytes,
        mimeType: 'application/pdf',
        title: 'Save company ledger PDF',
      );
      if (path != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('PDF saved to $path')));
      }
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not save ledger PDF: $error')));
    }
  }


  List<Map<String, dynamic>> get _filteredTransactions {
    return _transactions.where((t) {
      if (_paymentFilter != null && getPaymentStatus(t) != _paymentFilter) return false;
      if (_typeFilter != null && t['type'] != _typeFilter) return false;
      if (!_matchesDateRange(t['transaction_date'])) return false;
      return true;
    }).toList();
  }

  Future<void> _viewTransactionDialog(Map<String, dynamic> t) async {
    final changed = await showTransactionDetailDialog(context, t);
    if (changed) _load();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredTransactions;

    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.companyName} — Ledger'),
        actions: [IconButton(icon: const Icon(Icons.picture_as_pdf), tooltip: 'Save PDF', onPressed: _savePdf)],
      ),
      body: AdaptiveBackgroundText(
        child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            color: Colors.grey.shade100,
            child: PinnedDarkText(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Total Bought: ${_boughtTotal.toStringAsFixed(2)}'),
                Text('Total Sold: ${_soldTotal.toStringAsFixed(2)}'),
                if (_youOwe > 0.01)
                  Padding(
                    padding: const EdgeInsets.only(top: 4.0),
                    child: Text(
                      'You Owe Them: ${_youOwe.toStringAsFixed(2)}',
                      style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red),
                    ),
                  ),
                if (_theyOwe > 0.01)
                  Padding(
                    padding: const EdgeInsets.only(top: 4.0),
                    child: Text(
                      'They Owe You: ${_theyOwe.toStringAsFixed(2)}',
                      style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green),
                    ),
                  ),
                if (_materialTotals.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  const Text('By Material:', style: TextStyle(fontWeight: FontWeight.bold)),
                  ..._materialTotals.map((m) {
                    final boughtQty = (m['bought_qty'] as num).toDouble();
                    final soldQty = (m['sold_qty'] as num).toDouble();
                    final boughtAmount = (m['bought_amount'] as num).toDouble();
                    final soldAmount = (m['sold_amount'] as num).toDouble();
                    return Padding(
                      padding: const EdgeInsets.only(top: 2.0),
                      child: Text(
                        '${m['material_name']}: bought ${boughtQty.toStringAsFixed(1)} ${m['material_unit']} (${boughtAmount.toStringAsFixed(2)}), '
                        'sold ${soldQty.toStringAsFixed(1)} ${m['material_unit']} (${soldAmount.toStringAsFixed(2)})',
                        style: const TextStyle(fontSize: 13),
                      ),
                    );
                  }),
                ],
              ],
            ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
            child: PinnedDarkText(
            child: Wrap(
              spacing: 12,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                SizedBox(
                  width: 170,
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
                      DropdownMenuItem(value: 'in', child: Text('Bought')),
                      DropdownMenuItem(value: 'out', child: Text('Sold')),
                    ],
                    onChanged: (value) => setState(() => _typeFilter = value),
                  ),
                ),
                SizedBox(
                  width: 220,
                  child: OutlinedButton.icon(
                    onPressed: _pickDateRange,
                    icon: const Icon(Icons.date_range),
                    label: Text(_dateRange == null ? 'Date Range' : '${_dateRange!.start.toString().split(' ').first} → ${_dateRange!.end.toString().split(' ').first}'),
                  ),
                ),
                if (_hasActiveFilters)
                  TextButton.icon(
                    onPressed: () => setState(() { _paymentFilter = null; _typeFilter = null; _dateRange = null; }),
                    icon: const Icon(Icons.clear),
                    label: const Text('Clear Filters'),
                  ),
                if (_hasActiveFilters)
                  TextButton.icon(
                    onPressed: () => setState(() {
                      _paymentFilter = null;
                      _typeFilter = null;
                    }),
                    icon: const Icon(Icons.clear),
                    label: const Text('Clear'),
                  ),
              ],
            ),
            ),
          ),
          Expanded(
            child: filtered.isEmpty
                ? const Center(child: Text('No transactions match.'))
                : ListView.builder(
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final t = filtered[index];
                      final isIn = t['type'] == 'in';
                      final quantity = (t['quantity'] as num).toDouble();
                      final price = t['price'] != null ? (t['price'] as num).toDouble() : null;
                      final amount = price != null ? quantity * price : null;
                      final statusLabel = paymentStatusLabel(getPaymentStatus(t));
                      final date = formatDateTime(t['transaction_date']);

                      return ListTile(
                        leading: Icon(
                          isIn ? Icons.arrow_downward : Icons.arrow_upward,
                          color: isIn ? Colors.green : Colors.red,
                        ),
                        title: Text('${t['material_name']} — $quantity ${t['material_unit']}'),
                        subtitle: Text('$date • ${isIn ? 'Bought' : 'Sold'}'),
                        onTap: () => _viewTransactionDialog(t),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(amount != null ? amount.toStringAsFixed(2) : '—'),
                            if (statusLabel.isNotEmpty)
                              Text(statusLabel, style: TextStyle(fontSize: 12, color: _statusColor(statusLabel))),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
      ),
    );
  }

  Color _statusColor(String label) {
    if (label == 'Paid') return Colors.green;
    if (label == 'Partial') return Colors.orange;
    return Colors.red;
  }
}
