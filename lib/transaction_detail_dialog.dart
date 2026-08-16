import 'dart:io';

import 'package:flutter/material.dart';
import 'delete_confirm.dart';
import 'database_helper.dart';
import 'date_utils.dart';
import 'widgets/glass.dart';

Future<bool> showTransactionDetailDialog(BuildContext context, Map<String, dynamic> t) async {
  bool changed = false;
  final priceCtrl = TextEditingController(text: t['price'] != null ? t['price'].toString() : '');
  final notesCtrl = TextEditingController(text: t['notes'] ?? '');
  final isIn = t['type'] == 'in';
  final quantity = (t['quantity'] as num).toDouble();

  List<Map<String, dynamic>> payments = await DatabaseHelper.instance.getPaymentsForTransaction(t['id']);

  await showDialog(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setDialogState) {
        final price = double.tryParse(priceCtrl.text.trim());
        final total = price != null ? quantity * price : 0.0;
        final amountPaid = payments.fold(0.0, (sum, p) => sum + (p['amount'] as num).toDouble());
        final due = total - amountPaid;
        final String status = price == null
            ? ''
            : amountPaid <= 0
                ? 'Unpaid'
                : due <= 0
                    ? 'Paid'
                    : 'Partial';

        Future<void> addPaymentDialog({bool fullAmount = false}) async {
          final amountCtrl = TextEditingController(
            text: fullAmount ? due.toStringAsFixed(2) : '',
          );
          final added = await showDialog<bool>(
            context: context,
            builder: (context) => PinnedDarkText(child: AlertDialog(
              title: Text(fullAmount ? 'Mark as Fully Paid' : 'Add Payment'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Due: ${due.toStringAsFixed(2)}'),
                  const SizedBox(height: 8),
                  TextField(
                    controller: amountCtrl,
                    autofocus: !fullAmount,
                    readOnly: fullAmount,
                    decoration: const InputDecoration(labelText: 'Payment Amount'),
                    keyboardType: TextInputType.number,
                  ),
                ],
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Add')),
              ],
            )),
          );
          if (added == true) {
            final amount = double.tryParse(amountCtrl.text.trim());
            if (amount == null || amount <= 0) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Enter a valid payment amount greater than 0.')),
                );
              }
              return;
            }
            if (amount > due + 0.01) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Payment cannot exceed the amount due (${due.toStringAsFixed(2)}).',
                    ),
                  ),
                );
              }
              return;
            }
            await DatabaseHelper.instance.insertPayment({
              'transaction_id': t['id'],
              'amount': amount,
              'payment_date': DateTime.now().toIso8601String(),
              'notes': '',
            });
            payments = await DatabaseHelper.instance.getPaymentsForTransaction(t['id']);
            changed = true;
            setDialogState(() {});
          }
        }

        Future<void> deletePaymentConfirm(Map<String, dynamic> payment) async {
          final confirm = await showDialog<bool>(
            context: context,
            builder: (context) => PinnedDarkText(child: AlertDialog(
              title: const Text('Delete Payment?'),
              content: Text('Remove this payment of ${(payment['amount'] as num).toStringAsFixed(2)}?'),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
              ],
            )),
          );
          if (confirm == true) {
            final allowed = await confirmDeleteWithPassword(context, title: 'Confirm Delete Payment', warning: 'This payment will be permanently deleted. This cannot be undone.');
            if (!allowed) return;
            await DatabaseHelper.instance.deletePayment(payment['id']);
            payments = await DatabaseHelper.instance.getPaymentsForTransaction(t['id']);
            changed = true;
            setDialogState(() {});
          }
        }

        return PinnedDarkText(child: AlertDialog(
          title: Text('${t['material_name']} — ${isIn ? 'Bought' : 'Sold'}'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (t['company_name'] != null) Text('${isIn ? 'Bought from' : 'Sold to'}: ${t['company_name']}'),
                if ((t['transaction_number'] as String?)?.trim().isNotEmpty ?? false)
                  Text('Transaction #: ${t['transaction_number']}'),
                Text('Quantity: ${t['quantity']} ${t['material_unit']}'),
                Text('Date: ${formatDateTime(t['transaction_date'])}'),
                if ((t['attachment_path'] as String?)?.trim().isNotEmpty ?? false)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.receipt_long_outlined),
                      label: const Text('View Attached Bill'),
                      onPressed: () {
                        final file = File(t['attachment_path'] as String);
                        showDialog<void>(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text('Attached Bill'),
                            content: SizedBox(
                              width: 600,
                              child: file.existsSync()
                                  ? InteractiveViewer(child: Image.file(file))
                                  : const Text('This bill image is no longer available.'),
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: const Text('Close'),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                const SizedBox(height: 12),
                TextField(
                  controller: priceCtrl,
                  decoration: const InputDecoration(labelText: 'Price'),
                  keyboardType: TextInputType.number,
                  onChanged: (_) => setDialogState(() {}),
                ),
                const SizedBox(height: 12),
                if (price != null) ...[
                  Text('Total: ${total.toStringAsFixed(2)}'),
                  Text('Paid: ${amountPaid.toStringAsFixed(2)}'),
                  Text(
                    'Due: ${due.toStringAsFixed(2)}',
                    style: TextStyle(fontWeight: FontWeight.bold, color: due > 0 ? Colors.red : Colors.green),
                  ),
                  Text('Status: $status'),
                  const SizedBox(height: 8),
                  if (due > 0)
                    Row(
                      children: [
                        Expanded(
                          child: GlassActionButton(
                            onPressed: () => addPaymentDialog(),
                            icon: Icons.payments,
                            expand: true,
                            label: const Text('Add Payment'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: GlassActionButton(
                            onPressed: () => addPaymentDialog(fullAmount: true),
                            icon: Icons.check_circle,
                            color: Colors.green,
                            expand: true,
                            label: const Text('Mark as Paid'),
                          ),
                        ),
                      ],
                    ),
                  if (payments.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    const Text('Payment History:', style: TextStyle(fontWeight: FontWeight.bold)),
                    ...payments.map((p) => ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          title: Text((p['amount'] as num).toStringAsFixed(2)),
                          subtitle: Text(formatDateTime(p['payment_date'])),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red, size: 20),
                            onPressed: () => deletePaymentConfirm(p),
                          ),
                        )),
                  ],
                ] else
                  const Text('Enter a price to track payments.', style: TextStyle(color: Colors.grey)),
                const SizedBox(height: 12),
                TextField(
                  controller: notesCtrl,
                  decoration: const InputDecoration(labelText: 'Notes'),
                ),
                const Padding(
                  padding: EdgeInsets.only(top: 8.0),
                  child: Text(
                    'Note: quantity, type, company, and material cannot be changed here since it would affect stock calculations.',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
            TextButton(
              onPressed: () async {
                double? newPrice;
                if (priceCtrl.text.trim().isNotEmpty) {
                  newPrice = double.tryParse(priceCtrl.text.trim());
                  if (newPrice == null || newPrice < 0) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Price must be a valid non-negative number.')),
                    );
                    return;
                  }
                }
                await DatabaseHelper.instance.updateTransaction(t['id'], {
                  'price': newPrice,
                  'notes': notesCtrl.text.trim(),
                });
                changed = true;
                if (context.mounted) Navigator.pop(context);
              },
              child: const Text('Save'),
            ),
          ],
        ));
      },
    ),
  );

  return changed;
}
