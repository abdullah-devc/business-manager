import 'package:flutter/material.dart';
import 'database_helper.dart';
import 'add_unit_dialog.dart';
import 'widgets/glass.dart';

class AddMaterialScreen extends StatefulWidget {
  const AddMaterialScreen({super.key});

  @override
  State<AddMaterialScreen> createState() => _AddMaterialScreenState();
}

class _AddMaterialScreenState extends State<AddMaterialScreen> {
  final _nameController = TextEditingController();
  final _stockController = TextEditingController();
  final _priceController = TextEditingController();
  final _thresholdController = TextEditingController();

  List<Map<String, dynamic>> _units = [];
  String? _selectedUnit;

  @override
  void initState() {
    super.initState();
    _loadUnits();
  }

  Future<void> _loadUnits() async {
    final units = await DatabaseHelper.instance.getAllUnits();
    setState(() => _units = units);
  }

  Future<void> _addUnit() async {
    final name = await showAddUnitDialog(context);
    if (name != null) {
      await _loadUnits();
      setState(() => _selectedUnit = name);
    }
  }

  Future<void> _save() async {
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a material name.')),
      );
      return;
    }
    if (_selectedUnit == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a unit.')),
      );
      return;
    }

    final stockText = _stockController.text.trim();
    double stock = 0.0;
    if (stockText.isNotEmpty) {
      final parsed = double.tryParse(stockText);
      if (parsed == null || parsed < 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Starting stock must be a valid non-negative number.')),
        );
        return;
      }
      stock = parsed;
    }

    final priceText = _priceController.text.trim();
    double? defaultPrice;
    if (priceText.isNotEmpty) {
      defaultPrice = double.tryParse(priceText);
      if (defaultPrice == null || defaultPrice < 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Default price must be a valid non-negative number.')),
        );
        return;
      }
    }

    final thresholdText = _thresholdController.text.trim();
    double? lowStockThreshold;
    if (thresholdText.isNotEmpty) {
      lowStockThreshold = double.tryParse(thresholdText);
      if (lowStockThreshold == null || lowStockThreshold < 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Low stock warning level must be a valid non-negative number.')),
        );
        return;
      }
    }

    final materialId = await DatabaseHelper.instance.insertMaterial({
      'name': _nameController.text.trim(),
      'unit': _selectedUnit,
      'current_stock': stock,
      'default_price': defaultPrice,
      'low_stock_threshold': lowStockThreshold,
      'created_at': DateTime.now().toIso8601String(),
    });

    if (context.mounted) Navigator.pop(context, materialId);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _stockController.dispose();
    _priceController.dispose();
    _thresholdController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add Material')),
      body: AdaptiveBackgroundText(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(controller: _nameController, decoration: const InputDecoration(labelText: 'Material Name')),
            Row(
              children: [
                Expanded(
                  child: AdaptiveDropdownButtonFormField<String>(
                    value: _selectedUnit,
                    decoration: const InputDecoration(labelText: 'Unit'),
                    items: _units.map((unit) {
                      return DropdownMenuItem<String>(
                        value: unit['name'] as String,
                        child: Text(unit['name']),
                      );
                    }).toList(),
                    onChanged: (value) => setState(() => _selectedUnit = value),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.add_circle_outline),
                  tooltip: 'Add new unit',
                  onPressed: _addUnit,
                ),
              ],
            ),
            TextField(
              controller: _stockController,
              decoration: const InputDecoration(labelText: 'Starting Stock'),
              keyboardType: TextInputType.number,
            ),
            TextField(
              controller: _priceController,
              decoration: const InputDecoration(labelText: 'Default Price (optional)'),
              keyboardType: TextInputType.number,
            ),
            TextField(
              controller: _thresholdController,
              decoration: const InputDecoration(
                labelText: 'Low Stock Warning Level (optional)',
                helperText: 'You\'ll be warned when stock falls to or below this amount',
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),
            GlassActionButton(onPressed: _save, icon: Icons.save, color: Colors.brown, expand: true, label: const Text('Save Material')),
          ],
        ),
      ),
      ),
    );
  }
}
