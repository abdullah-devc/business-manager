import 'package:flutter/material.dart';

import 'widgets/glass.dart';
import 'widgets/app_loading_indicator.dart';
import 'add_transaction_screen.dart';
import 'companies_screen.dart';
import 'database_helper.dart';
import 'expenses_screen.dart';
import 'invoices_screen.dart';
import 'materials_screen.dart';
import 'unpaid_transactions_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  bool _loading = true;
  double _receivable = 0;
  double _payable = 0;
  double _monthlyExpenses = 0;
  double _totalBalance = 0;
  double _invoiceDue = 0;
  int _lowStockCount = 0;
  int _unpaidCount = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final results = await Future.wait([
      DatabaseHelper.instance.getCompanyBalances(),
      DatabaseHelper.instance.getAllExpenses(),
      DatabaseHelper.instance.getAllExpenseBalances(),
      DatabaseHelper.instance.getAllInvoices(),
      DatabaseHelper.instance.getLowStockMaterials(),
      DatabaseHelper.instance.getUnpaidTransactions(),
    ]);
    final companyBalances = results[0] as List<Map<String, dynamic>>;
    final expenses = results[1] as List<Map<String, dynamic>>;
    final balances = results[2] as List<Map<String, dynamic>>;
    final invoices = results[3] as List<Map<String, dynamic>>;
    final lowStock = results[4] as List<Map<String, dynamic>>;
    final unpaid = results[5] as List<Map<String, dynamic>>;
    final now = DateTime.now();

    double receivable = 0;
    double payable = 0;
    for (final balance in companyBalances) {
      receivable +=
          ((balance['out_total'] as num).toDouble() -
                  (balance['out_paid'] as num).toDouble())
              .clamp(0, double.infinity)
              .toDouble();
      payable +=
          ((balance['in_total'] as num).toDouble() -
                  (balance['in_paid'] as num).toDouble())
              .clamp(0, double.infinity)
              .toDouble();
    }
    final monthlyExpenses = expenses.fold<double>(0, (sum, expense) {
      final date = DateTime.parse(expense['expense_date']);
      return date.year == now.year && date.month == now.month
          ? sum + (expense['amount'] as num).toDouble()
          : sum;
    });
    final totalBalance = balances.fold<double>(
      0,
      (sum, balance) => sum + (balance['current_balance'] as num).toDouble(),
    );
    final invoiceDue = invoices
        .where((invoice) => invoice['status'] == 'confirmed')
        .fold<double>(0, (sum, invoice) {
          final total = (invoice['total_amount'] as num).toDouble();
          final paid = (invoice['amount_paid'] as num).toDouble();
          return sum + (total - paid).clamp(0, double.infinity).toDouble();
        });

    if (!mounted) return;
    setState(() {
      _receivable = receivable;
      _payable = payable;
      _monthlyExpenses = monthlyExpenses;
      _totalBalance = totalBalance;
      _invoiceDue = invoiceDue;
      _lowStockCount = lowStock.length;
      _unpaidCount = unpaid.length;
      _loading = false;
    });
  }

  Future<void> _open(Widget screen) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => screen),
    );
    _load();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const AppLoadingView(label: 'Loading overview');

    return AdaptiveBackgroundText(
      // Builder gives us a BuildContext that sits *below* the adaptive
      // Theme that AdaptiveBackgroundText just inserted. Without this,
      // `Theme.of(context)` below would resolve using the outer
      // (pre-wrap) context and always return the app's static light
      // theme, so headings would stay dark regardless of brightness.
      child: Builder(
        builder: (context) => RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                'Business Overview',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 12),
              LayoutBuilder(
                builder: (context, constraints) {
                  final columns = constraints.maxWidth >= 900
                      ? 3
                      : constraints.maxWidth >= 560
                      ? 2
                      : 1;
                  return GridView.count(
                    crossAxisCount: columns,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: columns == 1 ? 3.5 : 2.3,
                    children: [
                      _DashboardCard(
                        label: 'Receivable',
                        value: _receivable,
                        icon: Icons.trending_up,
                        color: Colors.green,
                        onTap: () => _open(
                          const CompaniesScreen(
                            initialBalanceFilter: BalanceFilter.receivable,
                          ),
                        ),
                      ),
                      _DashboardCard(
                        label: 'Payable',
                        value: _payable,
                        icon: Icons.trending_down,
                        color: Colors.red,
                        onTap: () => _open(
                          const CompaniesScreen(
                            initialBalanceFilter: BalanceFilter.payable,
                          ),
                        ),
                      ),
                      _DashboardCard(
                        label: 'This Month Expenses',
                        value: _monthlyExpenses,
                        icon: Icons.receipt_long,
                        color: Colors.deepOrange,
                        onTap: () => _open(const ExpensesScreen()),
                      ),
                      _DashboardCard(
                        label: 'Available Balance',
                        value: _totalBalance,
                        icon: Icons.account_balance_wallet,
                        color: Colors.blue,
                        onTap: () => _open(const ExpensesScreen()),
                      ),
                      _DashboardCard(
                        label: 'Invoice Amount Due',
                        value: _invoiceDue,
                        icon: Icons.request_quote,
                        color: Colors.purple,
                        onTap: () => _open(const InvoicesScreen()),
                      ),
                      _DashboardCard(
                        label: 'Low Stock Items',
                        value: _lowStockCount.toDouble(),
                        icon: Icons.warning_amber_rounded,
                        color: Colors.orange,
                        isCount: true,
                        onTap: () => _open(MaterialsScreen()),
                      ),
                      _DashboardCard(
                        label: 'Unpaid Transactions',
                        value: _unpaidCount.toDouble(),
                        icon: Icons.pending_actions,
                        color: Colors.redAccent,
                        isCount: true,
                        onTap: () => _open(const UnpaidTransactionsScreen()),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 24),
              Text(
                'Quick Actions',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  GlassActionButton(
                    icon: Icons.add,
                    label: const Text('Add Transaction'),
                    color: Colors.blue,
                    onPressed: () => _open(const AddTransactionScreen()),
                  ),
                  GlassActionButton(
                    icon: Icons.receipt_long,
                    label: const Text('Manage Expenses'),
                    color: Colors.deepOrange,
                    onPressed: () => _open(const ExpensesScreen()),
                  ),
                  GlassActionButton(
                    icon: Icons.request_quote,
                    label: const Text('View Invoices'),
                    color: Colors.purple,
                    onPressed: () => _open(const InvoicesScreen()),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DashboardCard extends StatelessWidget {
  final String label;
  final double value;
  final IconData icon;
  final Color color;
  final bool isCount;
  final VoidCallback onTap;

  const _DashboardCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    required this.onTap,
    this.isCount = false,
  });

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      borderRadius: BorderRadius.circular(16),
      padding: const EdgeInsets.all(16),
      onTap: onTap,
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: color.withOpacity(0.18),
            child: Icon(icon, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: Theme.of(context).textTheme.labelLarge),
                const SizedBox(height: 4),
                Text(
                  isCount ? value.toInt().toString() : value.toStringAsFixed(2),
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
