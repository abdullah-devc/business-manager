import 'package:flutter/material.dart';

import 'widgets/glass.dart';
import 'widgets/app_loading_indicator.dart';
import 'widgets/mini_charts.dart';
import 'companies_screen.dart';
import 'database_helper.dart';
import 'date_utils.dart';
import 'expenses_screen.dart';
import 'invoices_screen.dart';
import 'materials_screen.dart';
import 'transactions_screen.dart';
import 'unpaid_transactions_screen.dart';

/// The redesigned dashboard tab: a hero balance card, key stat cards, an
/// income/expense trend chart, an expense-category donut, and a recent
/// transactions list — replacing the old plain stat-grid Dashboard.
class OverviewScreen extends StatefulWidget {
  const OverviewScreen({super.key});

  @override
  State<OverviewScreen> createState() => _OverviewScreenState();
}

class _OverviewScreenState extends State<OverviewScreen>
    with AutomaticKeepAliveClientMixin {
  bool _loading = true;
  double _receivable = 0;
  double _payable = 0;
  double _monthlyExpenses = 0;
  double _monthlyBought = 0;
  double _monthlySold = 0;
  double _totalBalance = 0;
  double _invoiceDue = 0;
  int _lowStockCount = 0;
  int _unpaidCount = 0;
  List<TrendPoint> _trend = const [];
  List<CategorySlice> _categorySlices = const [];
  List<Map<String, dynamic>> _recentTransactions = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final results = await Future.wait([
      DatabaseHelper.instance.getCompanyBalances(),
      DatabaseHelper.instance.getCurrentMonthExpensesTotal(),
      DatabaseHelper.instance.getAllExpenseBalances(),
      DatabaseHelper.instance.getConfirmedInvoiceDue(),
      DatabaseHelper.instance.getLowStockMaterials(),
      DatabaseHelper.instance.getUnpaidTransactionCount(),
      DatabaseHelper.instance.getMonthlyIncomeExpenseTrend(months: 6),
      DatabaseHelper.instance.getExpenseCategoryTotals(),
      DatabaseHelper.instance.getCurrentMonthTransactionTotals(),
      DatabaseHelper.instance.getRecentTransactions(),
    ]);
    final companyBalances = results[0] as List<Map<String, dynamic>>;
    final monthlyExpenses = results[1] as double;
    final balances = results[2] as List<Map<String, dynamic>>;
    final invoiceDue = results[3] as double;
    final lowStock = results[4] as List<Map<String, dynamic>>;
    final unpaidCount = results[5] as int;
    final trendRows = results[6] as List<Map<String, dynamic>>;
    final categoryRows = results[7] as List<Map<String, dynamic>>;
    final monthlyTransactions = results[8] as Map<String, double>;
    final recentTransactions = results[9] as List<Map<String, dynamic>>;

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
    final totalBalance = balances.fold<double>(
      0,
      (sum, balance) => sum + (balance['current_balance'] as num).toDouble(),
    );

    const monthNames = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final trend = trendRows.map((r) {
      final parts = (r['month'] as String).split('-');
      final label = monthNames[int.parse(parts[1]) - 1];
      return TrendPoint(
        label: label,
        income: r['income'] as double,
        expense: r['expense'] as double,
      );
    }).toList();

    final slices = <CategorySlice>[];
    for (int i = 0; i < categoryRows.length; i++) {
      final row = categoryRows[i];
      slices.add(
        CategorySlice(
          label: row['category'] as String,
          value: (row['total'] as num).toDouble(),
          color:
              CategoryDonutChart.palette[i % CategoryDonutChart.palette.length],
        ),
      );
    }

    if (!mounted) return;
    setState(() {
      _receivable = receivable;
      _payable = payable;
      _monthlyExpenses = monthlyExpenses;
      _monthlyBought = monthlyTransactions['bought']!;
      _monthlySold = monthlyTransactions['sold']!;
      _totalBalance = totalBalance;
      _invoiceDue = invoiceDue;
      _lowStockCount = lowStock.length;
      _unpaidCount = unpaidCount;
      _trend = trend;
      _categorySlices = slices;
      _recentTransactions = recentTransactions;
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
    super.build(context);
    if (_loading) return const AppLoadingView(label: 'Loading overview');

    return AdaptiveBackgroundText(
      child: Builder(
        builder: (context) => RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _HeroBalanceCard(
                balance: _totalBalance,
                receivable: _receivable,
                payable: _payable,
              ),
              const SizedBox(height: 16),
              LayoutBuilder(
                builder: (context, constraints) {
                  final columns = constraints.maxWidth >= 900
                      ? 4
                      : constraints.maxWidth >= 560
                      ? 2
                      : 1;
                  return GridView.count(
                    crossAxisCount: columns,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: columns == 1 ? 3.5 : 1.9,
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
                      _DashboardCard(
                        label: 'This Month Bought',
                        value: _monthlyBought,
                        icon: Icons.shopping_cart_outlined,
                        color: Colors.brown,
                        onTap: () => _open(const TransactionsScreen()),
                      ),
                      _DashboardCard(
                        label: 'This Month Sold',
                        value: _monthlySold,
                        icon: Icons.sell_outlined,
                        color: Colors.teal,
                        onTap: () => _open(const TransactionsScreen()),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 16),
              LayoutBuilder(
                builder: (context, constraints) {
                  // Side by side once there's room; stacked on narrower windows.
                  if (constraints.maxWidth >= 760) {
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 3,
                          child: IncomeExpenseTrendChart(points: _trend),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          flex: 2,
                          child: CategoryDonutChart(slices: _categorySlices),
                        ),
                      ],
                    );
                  }
                  return Column(
                    children: [
                      IncomeExpenseTrendChart(points: _trend),
                      const SizedBox(height: 16),
                      CategoryDonutChart(slices: _categorySlices),
                    ],
                  );
                },
              ),
              const SizedBox(height: 16),
              GlassContainer(
                padding: const EdgeInsets.all(16),
                borderRadius: BorderRadius.circular(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'Recent Transactions',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const Spacer(),
                        TextButton(
                          onPressed: () => _open(const TransactionsScreen()),
                          child: const Text('View all'),
                        ),
                      ],
                    ),
                    const Divider(),
                    if (_recentTransactions.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: Text('No transactions yet.'),
                      )
                    else
                      ..._recentTransactions.map((t) {
                        final isSale = t['type'] == 'out';
                        final amount =
                            ((t['quantity'] as num).toDouble()) *
                            ((t['price'] as num?)?.toDouble() ?? 0);
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: CircleAvatar(
                            backgroundColor:
                                (isSale ? Colors.green : Colors.red)
                                    .withOpacity(0.15),
                            child: Icon(
                              isSale
                                  ? Icons.arrow_downward
                                  : Icons.arrow_upward,
                              color: isSale ? Colors.green : Colors.red,
                              size: 18,
                            ),
                          ),
                          title: Text(
                            '${t['company_name']} \u2022 ${t['material_name']}',
                          ),
                          subtitle: Text(
                            formatDateTime(t['transaction_date'] as String),
                          ),
                          trailing: Text(
                            '${isSale ? '+' : '-'}${amount.toStringAsFixed(2)}',
                            style: TextStyle(
                              color: isSale ? Colors.green : Colors.red,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        );
                      }),
                  ],
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

class _HeroBalanceCard extends StatelessWidget {
  final double balance;
  final double receivable;
  final double payable;

  const _HeroBalanceCard({
    required this.balance,
    required this.receivable,
    required this.payable,
  });

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      padding: const EdgeInsets.all(20),
      borderRadius: BorderRadius.circular(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Available Balance',
            style: Theme.of(context).textTheme.labelLarge,
          ),
          const SizedBox(height: 6),
          Text(
            balance.toStringAsFixed(2),
            style: Theme.of(
              context,
            ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    const Icon(
                      Icons.trending_up,
                      color: Colors.green,
                      size: 18,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Receivable',
                            style: Theme.of(context).textTheme.labelSmall,
                          ),
                          Text(
                            receivable.toStringAsFixed(2),
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Row(
                  children: [
                    const Icon(
                      Icons.trending_down,
                      color: Colors.red,
                      size: 18,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Payable',
                            style: Theme.of(context).textTheme.labelSmall,
                          ),
                          Text(
                            payable.toStringAsFixed(2),
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
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
