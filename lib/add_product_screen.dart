import 'package:flutter/material.dart';
import 'database_helper.dart';
import 'add_unit_dialog.dart';
import 'widgets/glass.dart';

class AddProductScreen extends StatefulWidget {
  const AddProductScreen({super.key});

  @override
  State<AddProductScreen> createState() => _AddProductScreenState();
}

class _AddProductScreenState extends State<AddProductScreen> {
  final _nameController = TextEditingController();
  final _priceController = TextEditingController();

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
        const SnackBar(content: Text('Please enter a product name.')),
      );
      return;
    }
    if (_selectedUnit == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a unit.')),
      );
      return;
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

    final productId = await DatabaseHelper.instance.insertProduct({
      'name': _nameController.text.trim(),
      'unit': _selectedUnit,
      'default_price': defaultPrice,
      'created_at': DateTime.now().toIso8601String(),
    });

    if (context.mounted) Navigator.pop(context, productId);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add Product')),
      body: AdaptiveBackgroundText(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(controller: _nameController, decoration: const InputDecoration(labelText: 'Product Name')),
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
              controller: _priceController,
              decoration: const InputDecoration(labelText: 'Default Price (optional)'),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),
            GlassActionButton(onPressed: _save, icon: Icons.save, color: Colors.brown, expand: true, label: const Text('Save Product')),
          ],
        ),
      ),
      ),
    );
  }
}
