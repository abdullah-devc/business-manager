import 'package:flutter/material.dart';
import 'delete_confirm.dart';

import 'database_helper.dart';
import 'date_utils.dart';
import 'widgets/glass.dart';

class ExpenseCategoriesScreen extends StatefulWidget {
  const ExpenseCategoriesScreen({super.key});

  @override
  State<ExpenseCategoriesScreen> createState() =>
      _ExpenseCategoriesScreenState();
}

class _ExpenseCategoriesScreenState extends State<ExpenseCategoriesScreen> {
  List<Map<String, dynamic>> _categories = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final categories = await DatabaseHelper.instance.getAllExpenseCategories();
    if (mounted) setState(() => _categories = categories);
  }

  Future<void> _add() async {
    final controller = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => PinnedDarkText(
        child: AlertDialog(
          title: const Text('Add Expense Category'),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(labelText: 'Category name'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
    final name = controller.text.trim();
    if (confirmed != true || name.isEmpty) return;
    try {
      await DatabaseHelper.instance.insertExpenseCategory(name);
      _load();
    } catch (_) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('That category already exists.')),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Expense Categories')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _add,
        icon: const Icon(Icons.add),
        label: const Text('Add Category'),
      ),
      body: AdaptiveBackgroundText(
        child: ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: _categories.length,
          itemBuilder: (context, index) {
            final category = _categories[index];
            return ListTile(
              title: Text(category['name']),
              trailing: IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.red),
                tooltip: 'Delete category',
                onPressed: () async {
                  final allowed = await confirmDeleteWithPassword(context, title: 'Confirm Delete Category', warning: 'This expense category will be permanently deleted. This cannot be undone.');
                  if (!allowed) return;
                  await DatabaseHelper.instance.deleteExpenseCategory(
                    category['id'] as int,
                  );
                  _load();
                },
              ),
            );
          },
        ),
      ),
    );
  }
}

class ExpenseBalancesScreen extends StatefulWidget {
  const ExpenseBalancesScreen({super.key});

  @override
  State<ExpenseBalancesScreen> createState() => _ExpenseBalancesScreenState();
}

class _ExpenseBalancesScreenState extends State<ExpenseBalancesScreen> {
  List<Map<String, dynamic>> _balances = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final balances = await DatabaseHelper.instance.getAllExpenseBalances();
    if (mounted) setState(() => _balances = balances);
  }

  Future<void> _edit([Map<String, dynamic>? balance]) async {
    final nameController = TextEditingController(text: balance?['name'] ?? '');
    final amountController = TextEditingController(
      text: balance?['current_balance']?.toString() ?? '0',
    );
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => PinnedDarkText(
        child: AlertDialog(
          title: Text(balance == null ? 'Add Balance' : 'Edit Balance'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Balance name (e.g. Cash, Bank)',
                ),
              ),
              TextField(
                controller: amountController,
                decoration: const InputDecoration(labelText: 'Current balance'),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
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
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
    if (saved != true) return;
    final name = nameController.text.trim();
    final amount = double.tryParse(amountController.text.trim());
    if (name.isEmpty || amount == null) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Enter a name and valid balance.')),
        );
      return;
    }
    try {
      if (balance == null) {
        await DatabaseHelper.instance.insertExpenseBalance(name, amount);
      } else {
        await DatabaseHelper.instance.updateExpenseBalance(
          balance['id'] as int,
          name,
          amount,
        );
      }
      _load();
    } catch (_) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('That balance name already exists.')),
        );
    }
  }

  Future<void> _delete(Map<String, dynamic> balance) async {
    final allowed = await confirmDeleteWithPassword(context, title: 'Confirm Delete Balance', warning: 'This expense balance will be permanently deleted. This cannot be undone.');
    if (!allowed) return;
    try {
      await DatabaseHelper.instance.deleteExpenseBalance(balance['id'] as int);
      _load();
    } catch (error) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  Future<void> _addFunds(Map<String, dynamic> balance) async {
    final controller = TextEditingController();
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => PinnedDarkText(
        child: AlertDialog(
          title: Text('Add Funds to ${balance['name']}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Current balance: ${(balance['current_balance'] as num).toStringAsFixed(2)}',
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                autofocus: true,
                decoration: const InputDecoration(labelText: 'Amount to add'),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
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
              child: const Text('Add Funds'),
            ),
          ],
        ),
      ),
    );
    if (saved != true) return;
    final amount = double.tryParse(controller.text.trim());
    if (amount == null || amount <= 0) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Enter an amount greater than zero.')),
        );
      return;
    }
    await DatabaseHelper.instance.addToExpenseBalance(
      balance['id'] as int,
      amount,
    );
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Expense Balances')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _edit,
        icon: const Icon(Icons.add),
        label: const Text('Add Balance Account'),
      ),
      body: AdaptiveBackgroundText(
        child: ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: _balances.length,
          itemBuilder: (context, index) {
            final balance = _balances[index];
            return ListTile(
              leading: const Icon(Icons.account_balance_wallet_outlined),
              title: Text(balance['name']),
              subtitle: Text(
                'Current balance: ${(balance['current_balance'] as num).toStringAsFixed(2)}',
              ),
              // A single overflow menu keeps account names and actions usable
              // on narrow phones instead of forcing a wide trailing Row.
              trailing: PopupMenuButton<String>(
                tooltip: 'Balance actions',
                onSelected: (action) {
                  switch (action) {
                    case 'addFunds':
                      _addFunds(balance);
                      break;
                    case 'history':
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              ExpenseBalanceHistoryScreen(balance: balance),
                        ),
                      );
                      break;
                    case 'edit':
                      _edit(balance);
                      break;
                    case 'delete':
                      _delete(balance);
                      break;
                  }
                },
                itemBuilder: (context) => const [
                  PopupMenuItem(
                    value: 'addFunds',
                    child: ListTile(
                      leading: Icon(Icons.add),
                      title: Text('Add funds'),
                    ),
                  ),
                  PopupMenuItem(
                    value: 'history',
                    child: ListTile(
                      leading: Icon(Icons.history),
                      title: Text('View history'),
                    ),
                  ),
                  PopupMenuItem(
                    value: 'edit',
                    child: ListTile(
                      leading: Icon(Icons.edit_outlined),
                      title: Text('Edit'),
                    ),
                  ),
                  PopupMenuItem(
                    value: 'delete',
                    child: ListTile(
                      leading: Icon(Icons.delete_outline, color: Colors.red),
                      title: Text('Delete'),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class ExpenseBalanceHistoryScreen extends StatefulWidget {
  final Map<String, dynamic> balance;

  const ExpenseBalanceHistoryScreen({super.key, required this.balance});

  @override
  State<ExpenseBalanceHistoryScreen> createState() =>
      _ExpenseBalanceHistoryScreenState();
}

class _ExpenseBalanceHistoryScreenState
    extends State<ExpenseBalanceHistoryScreen> {
  List<Map<String, dynamic>> _records = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final records = await DatabaseHelper.instance.getExpenseBalanceRecords(
      widget.balance['id'] as int,
    );
    if (mounted) setState(() => _records = records);
  }

  String _label(String type) {
    switch (type) {
      case 'funds_added':
        return 'Funds Added';
      case 'expense':
        return 'Expense Used';
      case 'expense_reversal':
        return 'Expense Restored';
      case 'manual_adjustment':
        return 'Manual Adjustment';
      case 'opening_balance':
        return 'Opening Balance';
      default:
        return type;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('${widget.balance['name']} History')),
      body: AdaptiveBackgroundText(
        child: _records.isEmpty
            ? const Center(child: Text('No balance records yet.'))
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _records.length,
                itemBuilder: (context, index) {
                  final record = _records[index];
                  final amount = (record['amount'] as num).toDouble();
                  final added = amount >= 0;
                  return ListTile(
                    leading: Icon(
                      added
                          ? Icons.add_circle_outline
                          : Icons.remove_circle_outline,
                      color: added ? Colors.green : Colors.red,
                    ),
                    title: Text(_label(record['type'])),
                    subtitle: Text(
                      '${record['notes'] ?? ''}\n${formatDateTime(record['created_at'])}',
                    ),
                    isThreeLine: true,
                    trailing: Text(
                      '${added ? '+' : ''}${amount.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: added ? Colors.green : Colors.red,
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }
}
