import 'package:flutter/material.dart';
import 'database_helper.dart';
import 'delete_confirm.dart';
import 'date_utils.dart';
import 'add_invoice_screen.dart';
import 'widgets/glass.dart';

class InvoicesScreen extends StatefulWidget {
  final bool embedded;

  const InvoicesScreen({super.key, this.embedded = false});

  @override
  State<InvoicesScreen> createState() => _InvoicesScreenState();
}

class _InvoicesScreenState extends State<InvoicesScreen>
    with AutomaticKeepAliveClientMixin {
  List<Map<String, dynamic>> _invoices = [];
  String _search = '';
  String? _statusFilter;

  @override
  void initState() {
    super.initState();
    _loadInvoices();
  }

  Future<void> _loadInvoices() async {
    final data = await DatabaseHelper.instance.getAllInvoices();
    setState(() => _invoices = data);
  }

  double _amount(Map<String, dynamic> invoice, String key) =>
      (invoice[key] as num?)?.toDouble() ?? 0;

  String _paymentStatus(Map<String, dynamic> invoice) {
    if (invoice['status'] == 'draft') return 'draft';
    final total = _amount(invoice, 'total_amount');
    final paid = _amount(invoice, 'amount_paid');
    if (total <= 0) return 'confirmed';
    if (paid <= 0.01) return 'unpaid';
    if (paid + 0.01 >= total) return 'paid';
    return 'partial';
  }

  Future<void> _recordPayment(Map<String, dynamic> invoice) async {
    final total = _amount(invoice, 'total_amount');
    final paid = _amount(invoice, 'amount_paid');
    final due = total - paid;
    final amountController = TextEditingController(
      text: due.toStringAsFixed(2),
    );
    final notesController = TextEditingController();

    final shouldSave = await showDialog<bool>(
      context: context,
      builder: (context) => PinnedDarkText(
        child: AlertDialog(
          title: Text('Record Payment for ${invoice['invoice_number']}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Invoice total: ${total.toStringAsFixed(2)}'),
              Text('Already paid: ${paid.toStringAsFixed(2)}'),
              Text(
                'Remaining: ${due.toStringAsFixed(2)}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: amountController,
                autofocus: true,
                decoration: const InputDecoration(labelText: 'Payment Amount'),
                keyboardType: TextInputType.number,
              ),
              TextField(
                controller: notesController,
                decoration: const InputDecoration(
                  labelText: 'Notes (optional)',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Record Payment'),
            ),
          ],
        ),
      ),
    );

    if (shouldSave != true) return;
    final amount = double.tryParse(amountController.text.trim());
    if (amount == null || amount <= 0 || amount > due + 0.01) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Enter an amount from 0.01 to ${due.toStringAsFixed(2)}.',
            ),
          ),
        );
      }
      return;
    }

    try {
      await DatabaseHelper.instance.recordInvoicePayment(
        invoice['id'] as int,
        amount,
        notes: notesController.text.trim(),
      );
      await _loadInvoices();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not record payment: $error')),
        );
      }
    }
  }

  List<Map<String, dynamic>> get _filteredInvoices {
    return _invoices.where((inv) {
      if (_search.trim().isNotEmpty) {
        final q = _search.trim().toLowerCase();
        final company = (inv['company_name'] ?? '').toString().toLowerCase();
        final number = (inv['invoice_number'] ?? '').toString().toLowerCase();
        if (!company.contains(q) && !number.contains(q)) return false;
      }
      if (_statusFilter != null && _paymentStatus(inv) != _statusFilter)
        return false;
      return true;
    }).toList();
  }

  Future<void> _deleteInvoiceConfirm(Map<String, dynamic> invoice) async {
    final warning = invoice['status'] == 'confirmed'
        ? 'This invoice is confirmed. Deleting it will reverse its stock changes and remove its linked transactions and payments. This cannot be undone.'
        : 'This draft invoice and its line items will be permanently deleted.';
    final allowed = await confirmDeleteWithPassword(context, title: 'Delete ${invoice['invoice_number']}?', warning: warning);
    if (!allowed) return;
    await DatabaseHelper.instance.deleteInvoice(invoice['id']);
    _loadInvoices();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final isPhone = MediaQuery.sizeOf(context).width < 600;
    return Scaffold(
      appBar: widget.embedded ? null : AppBar(title: const Text('Invoices')),
      floatingActionButton: Padding(
        // Shift left of the main tab scaffold's round "Quick Add" FAB
        // (same bottom-right corner) so the two buttons don't overlap.
        padding: EdgeInsets.only(right: widget.embedded ? 72.0 : 0.0),
        child: FloatingActionButton.extended(
          onPressed: () async {
            final result = await Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const AddInvoiceScreen()),
            );
            if (result == true) _loadInvoices();
          },
          icon: const Icon(Icons.add),
          label: const Text('Add Invoice'),
        ),
      ),
      body: AdaptiveBackgroundText(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              TextField(
                decoration: const InputDecoration(
                  labelText: 'Search by invoice number or company',
                  prefixIcon: Icon(Icons.search),
                ),
                onChanged: (value) => setState(() => _search = value),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Text('Status:'),
                  const SizedBox(width: 12),
                  Expanded(
                    child: AdaptiveDropdownButtonFormField<String?>(
                      value: _statusFilter,
                      items: const [
                        DropdownMenuItem(value: null, child: Text('All')),
                        DropdownMenuItem(value: 'draft', child: Text('Draft')),
                        DropdownMenuItem(
                          value: 'unpaid',
                          child: Text('Unpaid'),
                        ),
                        DropdownMenuItem(
                          value: 'partial',
                          child: Text('Partially Paid'),
                        ),
                        DropdownMenuItem(value: 'paid', child: Text('Paid')),
                        DropdownMenuItem(
                          value: 'confirmed',
                          child: Text('Confirmed'),
                        ),
                      ],
                      onChanged: (value) =>
                          setState(() => _statusFilter = value),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Expanded(
                child: _filteredInvoices.isEmpty
                    ? const Center(child: Text('No invoices found.'))
                    : ListView.builder(
                        itemCount: _filteredInvoices.length,
                        itemBuilder: (context, index) {
                          final inv = _filteredInvoices[index];
                          final isDraft = inv['status'] == 'draft';
                          final paymentStatus = _paymentStatus(inv);
                          final total = _amount(inv, 'total_amount');
                          final paid = _amount(inv, 'amount_paid');
                          final due = total - paid;
                          return ListTile(
                            leading: Icon(
                              isDraft
                                  ? Icons.edit_note
                                  : paymentStatus == 'paid'
                                  ? Icons.check_circle
                                  : Icons.pending_actions,
                              color: isDraft
                                  ? Colors.orange
                                  : paymentStatus == 'paid'
                                  ? Colors.green
                                  : Colors.red,
                            ),
                            title: Text(
                              '${inv['invoice_number']} — ${inv['company_name']}',
                            ),
                            subtitle: Text(
                              '${isDraft ? 'Draft' : 'Confirmed'} • Issued ${formatDateTime(inv['issue_date']).split(',').first}'
                              '${inv['due_date'] != null ? ' • Due ${formatDateTime(inv['due_date']).split(',').first}' : ''}',
                            ),
                            onTap: () async {
                              final result = await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      AddInvoiceScreen(existingInvoice: inv),
                                ),
                              );
                              if (result == true) _loadInvoices();
                            },
                            trailing: isPhone
                                ? PopupMenuButton<String>(
                                    tooltip: 'Invoice actions',
                                    onSelected: (action) {
                                      if (action == 'payment')
                                        _recordPayment(inv);
                                      if (action == 'delete')
                                        _deleteInvoiceConfirm(inv);
                                    },
                                    itemBuilder: (context) => [
                                      if (!isDraft && due > 0.01)
                                        const PopupMenuItem(
                                          value: 'payment',
                                          child: ListTile(
                                            leading: Icon(
                                              Icons.payments_outlined,
                                            ),
                                            title: Text('Record payment'),
                                          ),
                                        ),
                                      const PopupMenuItem(
                                        value: 'delete',
                                        child: ListTile(
                                          leading: Icon(
                                            Icons.delete_outline,
                                            color: Colors.red,
                                          ),
                                          title: Text('Delete'),
                                        ),
                                      ),
                                    ],
                                  )
                                : Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      if (!isDraft)
                                        Padding(
                                          padding: const EdgeInsets.only(
                                            right: 8,
                                          ),
                                          child: Text(
                                            paymentStatus == 'partial'
                                                ? 'Partially Paid'
                                                : paymentStatus[0]
                                                          .toUpperCase() +
                                                      paymentStatus.substring(
                                                        1,
                                                      ),
                                            style: TextStyle(
                                              color: paymentStatus == 'paid'
                                                  ? Colors.green
                                                  : Colors.red,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                      if (!isDraft && due > 0.01)
                                        IconButton(
                                          onPressed: () => _recordPayment(inv),
                                          icon: const Icon(
                                            Icons.payments_outlined,
                                          ),
                                          tooltip:
                                              'Record payment (due: ${due.toStringAsFixed(2)})',
                                        ),
                                      IconButton(
                                        icon: const Icon(
                                          Icons.delete,
                                          color: Colors.red,
                                        ),
                                        tooltip: 'Delete invoice',
                                        onPressed: () =>
                                            _deleteInvoiceConfirm(inv),
                                      ),
                                    ],
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
