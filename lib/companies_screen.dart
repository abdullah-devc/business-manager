import 'package:flutter/material.dart';
import 'delete_confirm.dart';

import 'add_company_screen.dart';
import 'database_helper.dart';
import 'ledger_screen.dart';
import 'widgets/glass.dart';

enum BalanceFilter { all, outstanding, settled, receivable, payable }

class CompaniesScreen extends StatefulWidget {
  final BalanceFilter? initialBalanceFilter;
  final bool embedded;

  const CompaniesScreen({super.key, this.initialBalanceFilter, this.embedded = false});

  @override
  State<CompaniesScreen> createState() => _CompaniesScreenState();
}

class _CompaniesScreenState extends State<CompaniesScreen>
    with AutomaticKeepAliveClientMixin {
  List<Map<String, dynamic>> _companies = [];
  Map<int, Map<String, double>> _balanceByCompany = {};
  String _search = '';
  BalanceFilter _balanceFilter = BalanceFilter.all;

  @override
  void initState() {
    super.initState();
    _balanceFilter = widget.initialBalanceFilter ?? BalanceFilter.all;
    _loadCompanies();
  }

  Future<void> _loadCompanies() async {
    final data = await DatabaseHelper.instance.getAllCompanies();
    final balances = await DatabaseHelper.instance.getCompanyBalances();
    final balanceMap = <int, Map<String, double>>{};
    for (final balance in balances) {
      final inTotal = (balance['in_total'] as num).toDouble();
      final inPaid = (balance['in_paid'] as num).toDouble();
      final outTotal = (balance['out_total'] as num).toDouble();
      final outPaid = (balance['out_paid'] as num).toDouble();
      balanceMap[balance['company_id'] as int] = {
        'youOwe': (inTotal - inPaid).clamp(0, double.infinity).toDouble(),
        'theyOwe': (outTotal - outPaid).clamp(0, double.infinity).toDouble(),
      };
    }
    if (!mounted) return;
    setState(() {
      _companies = data;
      _balanceByCompany = balanceMap;
    });
  }

  bool _hasOutstanding(int companyId) {
    final balance = _balanceByCompany[companyId];
    return balance != null && (balance['youOwe']! > 0.01 || balance['theyOwe']! > 0.01);
  }

  List<Map<String, dynamic>> get _filteredCompanies {
    return _companies.where((company) {
      if (_search.trim().isNotEmpty) {
        final query = _search.trim().toLowerCase();
        final name = (company['name'] ?? '').toString().toLowerCase();
        final contact = (company['contact_person'] ?? '').toString().toLowerCase();
        final phone = (company['phone'] ?? '').toString().toLowerCase();
        if (!name.contains(query) && !contact.contains(query) && !phone.contains(query)) return false;
      }
      final id = company['id'] as int;
      final balance = _balanceByCompany[id] ?? const <String, double>{};
      if (_balanceFilter == BalanceFilter.outstanding && !_hasOutstanding(id)) return false;
      if (_balanceFilter == BalanceFilter.settled && _hasOutstanding(id)) return false;
      if (_balanceFilter == BalanceFilter.receivable && (balance['theyOwe'] ?? 0) <= 0.01) return false;
      if (_balanceFilter == BalanceFilter.payable && (balance['youOwe'] ?? 0) <= 0.01) return false;
      return true;
    }).toList();
  }

  Future<void> _editCompanyDialog(Map<String, dynamic> company) async {
    final nameCtrl = TextEditingController(text: company['name']);
    final contactCtrl = TextEditingController(text: company['contact_person'] ?? '');
    final phoneCtrl = TextEditingController(text: company['phone'] ?? '');
    final addressCtrl = TextEditingController(text: company['address'] ?? '');
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => PinnedDarkText(
        child: AlertDialog(
          title: const Text('Edit Company'),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Company Name')),
              TextField(controller: contactCtrl, decoration: const InputDecoration(labelText: 'Contact Person')),
              TextField(controller: phoneCtrl, decoration: const InputDecoration(labelText: 'Phone')),
              TextField(controller: addressCtrl, decoration: const InputDecoration(labelText: 'Address')),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
            TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Save')),
          ],
        ),
      ),
    );
    if (saved != true) return;
    if (nameCtrl.text.trim().isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Company name cannot be empty.')));
      }
      return;
    }
    await DatabaseHelper.instance.updateCompany(company['id'], {
      'name': nameCtrl.text.trim(),
      'contact_person': contactCtrl.text.trim(),
      'phone': phoneCtrl.text.trim(),
      'address': addressCtrl.text.trim(),
    });
    _loadCompanies();
  }

  Future<void> _deleteCompanyDialog(Map<String, dynamic> company) async {
    final choice = await showDialog<String>(
      context: context,
      builder: (context) => PinnedDarkText(
        child: AlertDialog(
          title: Text('Delete "${company['name']}"?'),
          content: const Text(
            'Choose how to delete this company:\n\n'
            'Keep History: removes it from lists and dropdowns, but its past transactions stay intact in its ledger.\n\n'
            'Delete Everything: also permanently deletes all its transactions and invoices. Stock is reversed first. This cannot be undone.',
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, 'cancel'), child: const Text('Cancel')),
            TextButton(onPressed: () => Navigator.pop(context, 'keep'), child: const Text('Keep History')),
            TextButton(
              onPressed: () => Navigator.pop(context, 'delete_all'),
              child: const Text('Delete Everything', style: TextStyle(color: Colors.red)),
            ),
          ],
        ),
      ),
    );
    if (choice == 'keep') {
      final allowed = await confirmDeleteWithPassword(context, title: 'Confirm Delete', warning: 'This will remove this item from lists. Its history will be kept.');
      if (!allowed) return;
      await DatabaseHelper.instance.softDeleteCompany(company['id']);
      _loadCompanies();
    } else if (choice == 'delete_all') {
      final allowed = await confirmDeleteWithPassword(context, title: 'Confirm Permanent Delete', warning: 'This permanently deletes this item and its related data. This cannot be undone.');
      if (!allowed) return;
      await DatabaseHelper.instance.hardDeleteCompanyWithTransactions(company['id']);
      _loadCompanies();
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      appBar: widget.embedded ? null : AppBar(title: const Text('Companies')),
      floatingActionButton: Padding(
        padding: EdgeInsets.only(right: widget.embedded ? 72 : 0),
        child: FloatingActionButton.extended(
          onPressed: () async {
            final added = await Navigator.push(context, MaterialPageRoute(builder: (_) => const AddCompanyScreen()));
            if (added != null) _loadCompanies();
          },
          icon: const Icon(Icons.add),
          label: const Text('Add Company'),
        ),
      ),
      body: AdaptiveBackgroundText(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(children: [
            TextField(
              decoration: const InputDecoration(labelText: 'Search companies', prefixIcon: Icon(Icons.search)),
              onChanged: (value) => setState(() => _search = value),
            ),
            const SizedBox(height: 12),
            Row(children: [
              const Text('Balance:'),
              const SizedBox(width: 12),
              Expanded(
                child: AdaptiveDropdownButtonFormField<BalanceFilter>(
                  value: _balanceFilter,
                  items: const [
                    DropdownMenuItem(value: BalanceFilter.all, child: Text('All')),
                    DropdownMenuItem(value: BalanceFilter.outstanding, child: Text('Has Outstanding Balance')),
                    DropdownMenuItem(value: BalanceFilter.settled, child: Text('Fully Settled')),
                    DropdownMenuItem(value: BalanceFilter.receivable, child: Text('They Owe You')),
                    DropdownMenuItem(value: BalanceFilter.payable, child: Text('You Owe')),
                  ],
                  onChanged: (value) => setState(() => _balanceFilter = value ?? BalanceFilter.all),
                ),
              ),
            ]),
            const SizedBox(height: 12),
            Expanded(
              child: _filteredCompanies.isEmpty
                  ? const Center(child: Text('No companies found.'))
                  : LayoutBuilder(builder: (context, constraints) {
                      final columns = constraints.maxWidth >= 1100 ? 3 : constraints.maxWidth >= 700 ? 2 : 1;
                      Widget cardFor(int index) {
                        final company = _filteredCompanies[index];
                        final balance = _balanceByCompany[company['id']];
                        return _CompanyCard(
                          company: company,
                          youOwe: balance?['youOwe'] ?? 0,
                          theyOwe: balance?['theyOwe'] ?? 0,
                          onTap: () => _editCompanyDialog(company),
                          onViewLedger: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => LedgerScreen(companyId: company['id'], companyName: company['name']),
                            ),
                          ),
                          onDelete: () => _deleteCompanyDialog(company),
                        );
                      }
                      if (columns == 1) {
                        return ListView.separated(
                          itemCount: _filteredCompanies.length,
                          padding: const EdgeInsets.only(bottom: 88),
                          separatorBuilder: (_, __) => const SizedBox(height: 12),
                          itemBuilder: (_, index) => cardFor(index),
                        );
                      }
                      return GridView.builder(
                        itemCount: _filteredCompanies.length,
                        padding: const EdgeInsets.only(bottom: 88),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: columns,
                          mainAxisSpacing: 14,
                          crossAxisSpacing: 14,
                          childAspectRatio: columns == 3 ? 1.75 : 1.9,
                        ),
                        itemBuilder: (_, index) => cardFor(index),
                      );
                    }),
            ),
          ]),
        ),
      ),
    );
  }

  @override
  bool get wantKeepAlive => true;
}

class _CompanyCard extends StatelessWidget {
  const _CompanyCard({
    required this.company,
    required this.youOwe,
    required this.theyOwe,
    required this.onTap,
    required this.onViewLedger,
    required this.onDelete,
  });

  final Map<String, dynamic> company;
  final double youOwe;
  final double theyOwe;
  final VoidCallback onTap;
  final VoidCallback onViewLedger;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final name = (company['name'] ?? '').toString().trim();
    final contact = (company['contact_person'] ?? '').toString().trim();
    final phone = (company['phone'] ?? '').toString().trim();
    final initial = name.isEmpty ? '?' : name.substring(0, 1).toUpperCase();
    final hasBalance = youOwe > 0.01 || theyOwe > 0.01;
    final accent = Theme.of(context).colorScheme.primary;
    return GlassContainer(
      padding: const EdgeInsets.all(16),
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          CircleAvatar(
            radius: 23,
            backgroundColor: accent.withOpacity(0.18),
            child: Text(initial, style: TextStyle(color: accent, fontSize: 20, fontWeight: FontWeight.w700)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              name.isEmpty ? 'Unnamed company' : name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
            ),
          ),
          IconButton(tooltip: 'View ledger', icon: const Icon(Icons.receipt_long), onPressed: onViewLedger),
          IconButton(
            tooltip: 'Delete company',
            icon: const Icon(Icons.delete_outline, color: Colors.red),
            onPressed: onDelete,
          ),
        ]),
        if (contact.isNotEmpty || phone.isNotEmpty) ...[
          const SizedBox(height: 14),
          if (contact.isNotEmpty) _CardDetail(icon: Icons.person_outline, text: contact),
          if (phone.isNotEmpty) ...[
            if (contact.isNotEmpty) const SizedBox(height: 6),
            _CardDetail(icon: Icons.phone_outlined, text: phone),
          ],
        ],
        const SizedBox(height: 14),
        Wrap(spacing: 8, runSpacing: 6, children: [
          if (youOwe > 0.01) _BalanceChip(label: 'You owe: ${youOwe.toStringAsFixed(2)}', color: Colors.red),
          if (theyOwe > 0.01) _BalanceChip(label: 'They owe you: ${theyOwe.toStringAsFixed(2)}', color: Colors.green),
          if (!hasBalance) const _BalanceChip(label: 'Settled', color: Colors.blueGrey),
        ]),
      ]),
    );
  }
}

class _CardDetail extends StatelessWidget {
  const _CardDetail({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Row(children: [
        Icon(icon, size: 17),
        const SizedBox(width: 8),
        Expanded(child: Text(text, overflow: TextOverflow.ellipsis)),
      ]);
}

class _BalanceChip extends StatelessWidget {
  const _BalanceChip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: color.withOpacity(0.14),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: color.withOpacity(0.32)),
        ),
        child: Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w700)),
      );
}
