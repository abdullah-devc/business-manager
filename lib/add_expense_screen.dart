import 'package:flutter/material.dart';

import 'database_helper.dart';
import 'widgets/glass.dart';

class AddExpenseScreen extends StatefulWidget {
  final Map<String, dynamic>? existingExpense;

  const AddExpenseScreen({super.key, this.existingExpense});

  @override
  State<AddExpenseScreen> createState() => _AddExpenseScreenState();
}

class _AddExpenseScreenState extends State<AddExpenseScreen> {
  final _formKey = GlobalKey<FormState>();
  final _descriptionController = TextEditingController();
  final _amountController = TextEditingController();
  List<Map<String, dynamic>> _categories = [];
  List<Map<String, dynamic>> _balances = [];
  int? _selectedCategoryId;
  int? _selectedBalanceId;
  DateTime _expenseDate = DateTime.now();
  bool _saving = false;

  bool get _isEditing => widget.existingExpense != null;

  @override
  void initState() {
    super.initState();
    final expense = widget.existingExpense;
    if (expense != null) {
      _descriptionController.text = expense['description'] ?? '';
      _amountController.text = expense['amount']?.toString() ?? '';
      _expenseDate = DateTime.parse(expense['expense_date']);
      _selectedBalanceId = expense['balance_id'] as int?;
    }
    _loadOptions();
  }

  Future<void> _loadOptions() async {
    final categories = await DatabaseHelper.instance.getAllExpenseCategories();
    final balances = await DatabaseHelper.instance.getAllExpenseBalances();
    final currentCategory = widget.existingExpense?['category'];
    int? matchingCategoryId;
    for (final category in categories) {
      if (category['name'] == currentCategory) {
        matchingCategoryId = category['id'] as int;
        break;
      }
    }
    if (!mounted) return;
    setState(() {
      _categories = categories;
      _balances = balances;
      _selectedCategoryId = matchingCategoryId ?? _selectedCategoryId;
    });
  }

  Future<void> _addCategory() async {
    final controller = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => PinnedDarkText(child: AlertDialog(
        title: const Text('Add Expense Category'),
        content: TextField(controller: controller, autofocus: true, decoration: const InputDecoration(labelText: 'Category name')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Add')),
        ],
      )),
    );
    final name = controller.text.trim();
    if (confirmed != true || name.isEmpty) return;
    try {
      final id = await DatabaseHelper.instance.insertExpenseCategory(name);
      await _loadOptions();
      if (mounted) setState(() => _selectedCategoryId = id);
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('That category already exists.')));
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _expenseDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _expenseDate = picked);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedCategoryId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Select an expense category.')));
      return;
    }
    final amount = double.parse(_amountController.text.trim());
    final category = _categories.firstWhere((item) => item['id'] == _selectedCategoryId)['name'] as String;
    setState(() => _saving = true);
    final data = {
      'category': category,
      'description': _descriptionController.text.trim(),
      'amount': amount,
      'expense_date': _expenseDate.toIso8601String(),
      'balance_id': _selectedBalanceId,
    };
    try {
      if (_isEditing) {
        await DatabaseHelper.instance.updateExpenseAndBalance(widget.existingExpense!['id'] as int, data);
      } else {
        await DatabaseHelper.instance.createExpense({
          ...data,
          'created_at': DateTime.now().toIso8601String(),
        });
      }
      if (mounted) Navigator.pop(context, true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_isEditing ? 'Edit Expense' : 'Add Expense')),
      body: AdaptiveBackgroundText(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              Row(
                children: [
                  Expanded(
                    child: AdaptiveDropdownButtonFormField<int>(
                      value: _selectedCategoryId,
                      decoration: const InputDecoration(labelText: 'Category'),
                      items: _categories.map((category) => DropdownMenuItem<int>(value: category['id'] as int, child: Text(category['name']))).toList(),
                      onChanged: (value) => setState(() => _selectedCategoryId = value),
                    ),
                  ),
                  IconButton(icon: const Icon(Icons.add_circle_outline), tooltip: 'Add category', onPressed: _addCategory),
                ],
              ),
              const SizedBox(height: 12),
              AdaptiveDropdownButtonFormField<int?>(
                value: _selectedBalanceId,
                decoration: const InputDecoration(labelText: 'Deduct from balance (optional)'),
                items: [
                  const DropdownMenuItem<int?>(value: null, child: Text('No balance selected')),
                  ..._balances.map((balance) => DropdownMenuItem<int?>(
                        value: balance['id'] as int,
                        child: Text('${balance['name']} (${(balance['current_balance'] as num).toStringAsFixed(2)})'),
                      )),
                ],
                onChanged: (value) => setState(() => _selectedBalanceId = value),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(labelText: 'Description (optional)'),
                maxLines: 3,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _amountController,
                decoration: const InputDecoration(labelText: 'Amount'),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                validator: (value) {
                  final amount = double.tryParse(value?.trim() ?? '');
                  return amount == null || amount <= 0 ? 'Enter an amount greater than zero.' : null;
                },
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: _pickDate,
                icon: const Icon(Icons.calendar_today),
                label: Text('Date: ${_expenseDate.toString().split(' ').first}'),
              ),
              const SizedBox(height: 24),
              GlassActionButton(
                onPressed: _saving ? null : _save,
                icon: Icons.save,
                color: Colors.deepOrange,
                expand: true,
                label: Text(_saving ? 'Saving...' : (_isEditing ? 'Save Changes' : 'Add Expense')),
              ),
            ],
          ),
        ),
      ),
      ),
    );
  }
}
