import 'package:flutter/material.dart';
import 'database_helper.dart';
import 'date_utils.dart';
import 'transaction_detail_dialog.dart';
import 'widgets/glass.dart';

class ProductLedgerScreen extends StatefulWidget {
  final int productId;
  final String productName;

  const ProductLedgerScreen({super.key, required this.productId, required this.productName});

  @override
  State<ProductLedgerScreen> createState() => _ProductLedgerScreenState();
}

class _ProductLedgerScreenState extends State<ProductLedgerScreen> {
  List<Map<String, dynamic>> _transactions = [];
  double _boughtQty = 0;
  double _soldQty = 0;
  double _boughtAmount = 0;
  double _soldAmount = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final data = await DatabaseHelper.instance.getTransactionsByProduct(widget.productId);
    double boughtQty = 0, soldQty = 0, boughtAmount = 0, soldAmount = 0;
    for (final t in data) {
      final quantity = (t['quantity'] as num).toDouble();
      final price = t['price'] != null ? (t['price'] as num).toDouble() : null;
      final amount = price != null ? quantity * price : 0.0;
      if (t['type'] == 'in') {
        boughtQty += quantity;
        boughtAmount += amount;
      } else {
        soldQty += quantity;
        soldAmount += amount;
      }
    }
    setState(() {
      _transactions = data;
      _boughtQty = boughtQty;
      _soldQty = soldQty;
      _boughtAmount = boughtAmount;
      _soldAmount = soldAmount;
    });
  }

  Future<void> _viewTransactionDialog(Map<String, dynamic> t) async {
    final changed = await showTransactionDetailDialog(context, t);
    if (changed) _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('${widget.productName} — Ledger')),
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
                Text('Total Bought: ${_boughtQty.toStringAsFixed(2)} (${_boughtAmount.toStringAsFixed(2)})'),
                Text('Total Sold: ${_soldQty.toStringAsFixed(2)} (${_soldAmount.toStringAsFixed(2)})'),
              ],
            ),
            ),
          ),
          Expanded(
            child: _transactions.isEmpty
                ? const Center(child: Text('No transactions for this material yet.'))
                : ListView.builder(
                    itemCount: _transactions.length,
                    itemBuilder: (context, index) {
                      final t = _transactions[index];
                      final isIn = t['type'] == 'in';
                      final quantity = (t['quantity'] as num).toDouble();
                      final price = t['price'] != null ? (t['price'] as num).toDouble() : null;
                      final amount = price != null ? quantity * price : null;
                      final amountPaid = (t['amount_paid'] as num).toDouble();
                      final date = formatDateTime(t['transaction_date']);

                      String statusLabel = '';
                      Color statusColor = Colors.grey;
                      if (amount != null) {
                        if (amountPaid <= 0) {
                          statusLabel = 'Unpaid';
                          statusColor = Colors.red;
                        } else if (amountPaid >= amount) {
                          statusLabel = 'Paid';
                          statusColor = Colors.green;
                        } else {
                          statusLabel = 'Partial (${amountPaid.toStringAsFixed(2)}/${amount.toStringAsFixed(2)})';
                          statusColor = Colors.orange;
                        }
                      }

                      return ListTile(
                        leading: Icon(
                          isIn ? Icons.arrow_downward : Icons.arrow_upward,
                          color: isIn ? Colors.green : Colors.red,
                        ),
                        title: Text('${t['company_name']} — $quantity ${t['material_unit']}'),
                        subtitle: Text('$date • ${isIn ? 'Bought' : 'Sold'}'),
                        onTap: () => _viewTransactionDialog(t),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(amount != null ? amount.toStringAsFixed(2) : '—'),
                            if (statusLabel.isNotEmpty)
                              Text(statusLabel, style: TextStyle(fontSize: 12, color: statusColor)),
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
}