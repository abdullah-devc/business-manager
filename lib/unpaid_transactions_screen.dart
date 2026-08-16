import 'package:flutter/material.dart';

import 'database_helper.dart';
import 'date_utils.dart';
import 'transaction_detail_dialog.dart';
import 'widgets/glass.dart';
import 'widgets/app_loading_indicator.dart';

/// Filtered view of every unpaid or partially-paid transaction, with
/// overdue ones (past their linked invoice's due date) surfaced first.
/// Tapping an entry opens the same payment dialog used elsewhere so a
/// payment can be recorded without leaving this screen.
class UnpaidTransactionsScreen extends StatefulWidget {
  const UnpaidTransactionsScreen({super.key});

  @override
  State<UnpaidTransactionsScreen> createState() =>
      _UnpaidTransactionsScreenState();
}

class _UnpaidTransactionsScreenState extends State<UnpaidTransactionsScreen> {
  List<Map<String, dynamic>> _unpaid = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final data = await DatabaseHelper.instance.getUnpaidTransactions();
    if (!mounted) return;
    setState(() {
      _unpaid = data;
      _loading = false;
    });
  }

  bool _isOverdue(Map<String, dynamic> t) {
    final dueDateText = t['due_date'] as String?;
    if (dueDateText == null) return false;
    final dueDate = DateTime.tryParse(dueDateText);
    if (dueDate == null) return false;
    return dueDate.isBefore(DateTime.now());
  }

  @override
  Widget build(BuildContext context) {
    final totalOutstanding = _unpaid.fold<double>(0, (sum, t) {
      final total =
          (t['quantity'] as num).toDouble() * (t['price'] as num).toDouble();
      final paid = (t['amount_paid'] as num).toDouble();
      return sum + (total - paid);
    });
    final overdueCount = _unpaid.where(_isOverdue).length;

    return Scaffold(
      appBar: AppBar(title: const Text('Unpaid & Partial Payments')),
      body: AdaptiveBackgroundText(
        child: _loading
            ? const AppLoadingView(label: 'Loading unpaid transactions')
            : _unpaid.isEmpty
            ? const Center(
                child: Text('Nothing outstanding — everything is paid up.'),
              )
            : RefreshIndicator(
                onRefresh: _load,
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: _unpaid.length + 1,
                  separatorBuilder: (context, index) =>
                      const Divider(height: 1),
                  itemBuilder: (context, index) {
                    if (index == 0) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        child: Text(
                          'Total outstanding: ${totalOutstanding.toStringAsFixed(2)}'
                          '${overdueCount > 0 ? '  •  $overdueCount overdue' : ''}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      );
                    }
                    final t = _unpaid[index - 1];
                    final isIn = t['type'] == 'in';
                    final total =
                        (t['quantity'] as num).toDouble() *
                        (t['price'] as num).toDouble();
                    final paid = (t['amount_paid'] as num).toDouble();
                    final remaining = total - paid;
                    final overdue = _isOverdue(t);
                    final dueDateText = t['due_date'] as String?;

                    return ListTile(
                      leading: Icon(
                        overdue
                            ? Icons.warning_amber_rounded
                            : Icons.hourglass_bottom,
                        color: overdue ? Colors.red : Colors.orange,
                      ),
                      title: Text(
                        '${t['material_name']} — ${isIn ? 'Bought from' : 'Sold to'} ${t['company_name']}',
                      ),
                      subtitle: Text(
                        '${paid > 0 ? 'Partially paid' : 'Unpaid'} • Remaining: ${remaining.toStringAsFixed(2)} of ${total.toStringAsFixed(2)}\n'
                        '${overdue
                            ? 'Overdue since '
                            : dueDateText != null
                            ? 'Due '
                            : 'Transaction date: '}'
                        '${dueDateText != null ? formatDateTime(dueDateText).split(',').first : formatDateTime(t['transaction_date']).split(',').first}',
                      ),
                      isThreeLine: true,
                      trailing: Text(
                        remaining.toStringAsFixed(2),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: overdue ? Colors.red : null,
                        ),
                      ),
                      onTap: () async {
                        final changed = await showTransactionDetailDialog(
                          context,
                          t,
                        );
                        if (changed) _load();
                      },
                    );
                  },
                ),
              ),
      ),
    );
  }
}
