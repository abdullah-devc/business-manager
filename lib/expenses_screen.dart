import 'package:flutter/material.dart';

import 'add_expense_screen.dart';
import 'delete_confirm.dart';
import 'database_helper.dart';
import 'date_utils.dart';
import 'expense_setup_screens.dart';
import 'widgets/glass.dart';

class ExpensesScreen extends StatefulWidget {
  final bool embedded;
  final Widget? footer;

  const ExpensesScreen({super.key, this.embedded = false, this.footer});

  @override
  State<ExpensesScreen> createState() => _ExpensesScreenState();
}

class _ExpensesScreenState extends State<ExpensesScreen> {
  List<Map<String, dynamic>> _expenses = [];
  List<Map<String, dynamic>> _balances = [];
  String _search = '';
  String? _categoryFilter;

  // Below this width the three stat cards no longer have room to sit
  // side-by-side without their labels wrapping/truncating, so we switch
  // to a stacked (2 + 1) layout instead.
  static const double _narrowBreakpoint = 520;

  @override
  void initState() {
    super.initState();
    _loadExpenses();
  }

  Future<void> _loadExpenses() async {
    final expenses = await DatabaseHelper.instance.getAllExpenses();
    final balances = await DatabaseHelper.instance.getAllExpenseBalances();
    if (mounted) {
      setState(() {
        _expenses = expenses;
        _balances = balances;
      });
    }
  }

  List<Map<String, dynamic>> get _filteredExpenses {
    return _expenses.where((expense) {
      final category = (expense['category'] ?? '').toString();
      final description = (expense['description'] ?? '').toString();
      if (_categoryFilter != null && category != _categoryFilter) return false;
      final query = _search.trim().toLowerCase();
      return query.isEmpty ||
          category.toLowerCase().contains(query) ||
          description.toLowerCase().contains(query);
    }).toList();
  }

  double _totalFor(bool Function(DateTime) predicate) =>
      _expenses.fold(0.0, (total, expense) {
        final date = DateTime.parse(expense['expense_date']);
        return predicate(date)
            ? total + (expense['amount'] as num).toDouble()
            : total;
      });

  Future<void> _editExpense(Map<String, dynamic> expense) async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => AddExpenseScreen(existingExpense: expense),
      ),
    );
    if (changed == true) _loadExpenses();
  }

  Future<void> _deleteExpense(Map<String, dynamic> expense) async {
    final allowed = await confirmDeleteWithPassword(
      context,
      title: 'Delete Expense?',
      warning:
          'This will delete the expense and restore its effect on the related balance. This cannot be undone.',
    );
    if (!allowed) return;
    await DatabaseHelper.instance.deleteExpenseAndRestoreBalance(
      expense['id'] as int,
    );
    _loadExpenses();
  }


  /// Builds the "This Month" / "This Year" / "Total Balance" stat cards.
  /// On wide (desktop/PC-width) windows they sit in a single row.
  /// On narrow (mobile/small-window) widths they stack as 2 + 1 so each
  /// card gets enough width for its label to fit on one line.
  Widget _buildStatCards({
    required double monthlyTotal,
    required double yearlyTotal,
    required double totalBalance,
    required VoidCallback onManageBalances,
  }) {
    final monthCard = _SummaryCard(
      label: 'This Month',
      amount: monthlyTotal,
      icon: Icons.calendar_month,
      color: Colors.deepOrange,
    );
    final yearCard = _SummaryCard(
      label: 'This Year',
      amount: yearlyTotal,
      icon: Icons.calendar_today,
      color: Colors.deepOrange,
    );
    final balanceCard = _BalanceCard(
      amount: totalBalance,
      onPressed: onManageBalances,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < _narrowBreakpoint;

        if (isNarrow) {
          return Column(
            children: [
              Row(
                children: [
                  Expanded(child: monthCard),
                  const SizedBox(width: 12),
                  Expanded(child: yearCard),
                ],
              ),
              const SizedBox(height: 12),
              balanceCard,
            ],
          );
        }

        return Row(
          children: [
            Expanded(child: monthCard),
            const SizedBox(width: 12),
            Expanded(child: yearCard),
            const SizedBox(width: 12),
            Expanded(child: balanceCard),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final monthlyTotal = _totalFor(
      (date) => date.year == now.year && date.month == now.month,
    );
    final yearlyTotal = _totalFor((date) => date.year == now.year);
    final totalBalance = _balances.fold<double>(
      0,
      (total, balance) =>
          total + (balance['current_balance'] as num).toDouble(),
    );
    final categories =
        _expenses
            .map((expense) => expense['category'].toString())
            .toSet()
            .toList()
          ..sort();

    return Scaffold(
      appBar: widget.embedded
          ? null
          : AppBar(
              title: const Text('Expenses'),
              actions: [
                IconButton(
                  icon: const Icon(Icons.category_outlined),
                  tooltip: 'Manage expense categories',
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const ExpenseCategoriesScreen(),
                    ),
                  ),
                ),
              ],
            ),
      floatingActionButton: Padding(
        // The phone shell hides its own Quick Add button outside Overview,
        // leaving this labelled action unobstructed. Desktop keeps room for it.
        padding: EdgeInsets.only(
          right: widget.embedded && MediaQuery.sizeOf(context).width >= 600
              ? 72.0
              : 0.0,
        ),
        child: FloatingActionButton.extended(
          onPressed: () async {
            final changed = await Navigator.push<bool>(
              context,
              MaterialPageRoute(builder: (context) => const AddExpenseScreen()),
            );
            if (changed == true) _loadExpenses();
          },
          icon: const Icon(Icons.add),
          label: const Text('Add Expense'),
        ),
      ),
      body: AdaptiveBackgroundText(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: ListView(
            // Let the summary, filters, and results scroll as one page. This
            // avoids a bottom overflow on short phones and above the FAB.
            padding: const EdgeInsets.only(bottom: 96),
            children: [
              if (widget.embedded)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    children: [
                      Text(
                        'Expenses',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.category_outlined),
                        tooltip: 'Manage expense categories',
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                const ExpenseCategoriesScreen(),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              _buildStatCards(
                monthlyTotal: monthlyTotal,
                yearlyTotal: yearlyTotal,
                totalBalance: totalBalance,
                onManageBalances: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const ExpenseBalancesScreen(),
                    ),
                  );
                  _loadExpenses();
                },
              ),
              const SizedBox(height: 16),
              TextField(
                decoration: const InputDecoration(
                  labelText: 'Search expenses',
                  prefixIcon: Icon(Icons.search),
                ),
                onChanged: (value) => setState(() => _search = value),
              ),
              const SizedBox(height: 12),
              AdaptiveDropdownButtonFormField<String?>(
                value: _categoryFilter,
                decoration: const InputDecoration(labelText: 'Category'),
                items: [
                  const DropdownMenuItem(
                    value: null,
                    child: Text('All Categories'),
                  ),
                  ...categories.map(
                    (category) => DropdownMenuItem(
                      value: category,
                      child: Text(category),
                    ),
                  ),
                ],
                onChanged: (value) => setState(() => _categoryFilter = value),
              ),
              const SizedBox(height: 12),
              _filteredExpenses.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.symmetric(vertical: 48),
                      child: Center(child: Text('No expenses found.')),
                    )
                  : ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _filteredExpenses.length,
                      itemBuilder: (context, index) {
                        final expense = _filteredExpenses[index];
                        return ListTile(
                          leading: const Icon(
                            Icons.receipt_long,
                            color: Colors.deepOrange,
                          ),
                          title: Text(
                            '${expense['category']} (${(expense['amount'] as num).toStringAsFixed(2)})',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(
                            '${expense['description'] ?? ''}\n${formatDateTime(expense['expense_date']).split(',').first}'
                            '${expense['balance_name'] != null ? ' • From ${expense['balance_name']}' : ''}',
                          ),
                          isThreeLine: true,
                          trailing: PopupMenuButton<String>(
                            tooltip: 'Expense actions',
                            onSelected: (action) {
                              if (action == 'edit') _editExpense(expense);
                              if (action == 'delete') _deleteExpense(expense);
                            },
                            itemBuilder: (context) => const [
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
                                  leading: Icon(
                                    Icons.delete_outline,
                                    color: Colors.red,
                                  ),
                                  title: Text('Delete'),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
              if (widget.footer != null) ...[
                const SizedBox(height: 24),
                widget.footer!,
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String label;
  final double amount;
  final IconData icon;
  final Color color;

  const _SummaryCard({
    required this.label,
    required this.amount,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      borderRadius: BorderRadius.circular(16),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 14,
                backgroundColor: color.withOpacity(0.18),
                child: Icon(icon, color: color, size: 16),
              ),
              const SizedBox(width: 8),
              // FittedBox shrinks the label to fit one line instead of
              // wrapping mid-word ("This Mont/h") when the card is narrow.
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    label,
                    maxLines: 1,
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            amount.toStringAsFixed(2),
            style: Theme.of(context).textTheme.headlineSmall,
          ),
        ],
      ),
    );
  }
}

class _BalanceCard extends StatelessWidget {
  final double amount;
  final VoidCallback onPressed;

  const _BalanceCard({required this.amount, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      borderRadius: BorderRadius.circular(16),
      padding: const EdgeInsets.all(16),
      onTap: onPressed,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 14,
                backgroundColor: Colors.blue.withOpacity(0.18),
                child: const Icon(
                  Icons.account_balance_wallet_outlined,
                  color: Colors.blue,
                  size: 16,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text('Total Balance', maxLines: 1),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            amount.toStringAsFixed(2),
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 4),
          const Text('Manage Balances', style: TextStyle(color: Colors.blue)),
        ],
      ),
    );
  }
}
