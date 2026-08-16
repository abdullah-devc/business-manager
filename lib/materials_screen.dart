import 'package:flutter/material.dart';
import 'delete_confirm.dart';
import 'database_helper.dart';
import 'add_material_screen.dart';
import 'material_ledger_screen.dart';
import 'add_unit_dialog.dart';
import 'widgets/glass.dart';

enum StockFilter { all, low, notLow }

class MaterialsScreen extends StatefulWidget {
  final bool embedded;

  const MaterialsScreen({super.key, this.embedded = false});

  @override
  State<MaterialsScreen> createState() => _MaterialsScreenState();
}

class _MaterialsScreenState extends State<MaterialsScreen> {
  List<Map<String, dynamic>> _materials = [];
  List<Map<String, dynamic>> _units = [];
  String _search = '';
  StockFilter _stockFilter = StockFilter.all;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    final materials = await DatabaseHelper.instance.getAllMaterials();
    final units = await DatabaseHelper.instance.getAllUnits();
    setState(() {
      _materials = materials;
      _units = units;
    });
  }

  bool _isLowStock(Map<String, dynamic> m) {
    final threshold = m['low_stock_threshold'];
    if (threshold == null) return false;
    final stock = (m['current_stock'] as num).toDouble();
    return stock <= (threshold as num).toDouble();
  }

  List<Map<String, dynamic>> get _filteredMaterials {
    return _materials.where((m) {
      if (_search.trim().isNotEmpty) {
        final q = _search.trim().toLowerCase();
        if (!(m['name'] ?? '').toString().toLowerCase().contains(q)) return false;
      }
      if (_stockFilter == StockFilter.low && !_isLowStock(m)) return false;
      if (_stockFilter == StockFilter.notLow && _isLowStock(m)) return false;
      return true;
    }).toList();
  }

  Future<void> _editMaterialDialog(Map<String, dynamic> material) async {
    final nameCtrl = TextEditingController(text: material['name']);
    final stockCtrl = TextEditingController(text: material['current_stock'].toString());
    final priceCtrl = TextEditingController(
      text: material['default_price'] != null ? material['default_price'].toString() : '',
    );
    final thresholdCtrl = TextEditingController(
      text: material['low_stock_threshold'] != null ? material['low_stock_threshold'].toString() : '',
    );
    String? editUnit = material['unit'];

    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => PinnedDarkText(child: AlertDialog(
          title: const Text('Edit Material'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Material Name')),
                Row(
                  children: [
                    Expanded(
                      child: AdaptiveDropdownButtonFormField<String>(
                        value: editUnit,
                        decoration: const InputDecoration(labelText: 'Unit'),
                        items: _units.map((unit) {
                          return DropdownMenuItem<String>(
                            value: unit['name'] as String,
                            child: Text(unit['name']),
                          );
                        }).toList(),
                        onChanged: (value) => setDialogState(() => editUnit = value),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.add_circle_outline),
                      tooltip: 'Add new unit',
                      onPressed: () async {
                        final name = await showAddUnitDialog(context);
                        if (name != null) {
                          await _loadAll();
                          setDialogState(() => editUnit = name);
                        }
                      },
                    ),
                  ],
                ),
                TextField(
                  controller: stockCtrl,
                  decoration: const InputDecoration(labelText: 'Current Stock'),
                  keyboardType: TextInputType.number,
                ),
                TextField(
                  controller: priceCtrl,
                  decoration: const InputDecoration(labelText: 'Default Price (optional)'),
                  keyboardType: TextInputType.number,
                ),
                TextField(
                  controller: thresholdCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Low Stock Warning Level (optional)',
                    helperText: 'You\'ll be warned when stock falls to or below this amount',
                  ),
                  keyboardType: TextInputType.number,
                ),
                const Padding(
                  padding: EdgeInsets.only(top: 8.0),
                  child: Text(
                    'Note: changing the default price only affects future transactions, not ones already saved.',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
            TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Save')),
          ],
        )),
      ),
    );

    if (saved == true) {
      if (nameCtrl.text.trim().isEmpty || editUnit == null) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Name and unit are required.')),
          );
        }
        return;
      }
      final stock = double.tryParse(stockCtrl.text.trim());
      if (stock == null || stock < 0) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Stock must be a valid non-negative number.')),
          );
        }
        return;
      }
      double? price;
      if (priceCtrl.text.trim().isNotEmpty) {
        price = double.tryParse(priceCtrl.text.trim());
        if (price == null || price < 0) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Price must be a valid non-negative number.')),
            );
          }
          return;
        }
      }
      double? threshold;
      if (thresholdCtrl.text.trim().isNotEmpty) {
        threshold = double.tryParse(thresholdCtrl.text.trim());
        if (threshold == null || threshold < 0) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Low stock warning level must be a valid non-negative number.')),
            );
          }
          return;
        }
      }

      await DatabaseHelper.instance.updateMaterial(material['id'], {
        'name': nameCtrl.text.trim(),
        'unit': editUnit,
        'current_stock': stock,
        'default_price': price,
        'low_stock_threshold': threshold,
      });
      _loadAll();
    }
  }

  Future<void> _deleteMaterialDialog(Map<String, dynamic> material) async {
    final choice = await showDialog<String>(
      context: context,
      builder: (context) => PinnedDarkText(child: AlertDialog(
        title: Text('Delete "${material['name']}"?'),
        content: const Text(
          'Choose how to delete this material:\n\n'
          '• Keep History: removes it from lists and dropdowns, but its past transactions stay intact in ledgers.\n\n'
          '• Delete Everything: also permanently deletes all its transactions. This cannot be undone.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, 'cancel'), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, 'keep'), child: const Text('Keep History')),
          TextButton(
            onPressed: () => Navigator.pop(context, 'delete_all'),
            child: const Text('Delete Everything', style: TextStyle(color: Colors.red)),
          ),
        ],
      )),
    );

    if (choice == 'keep') {
      final allowed = await confirmDeleteWithPassword(context, title: 'Confirm Delete', warning: 'This will remove this item from lists. Its history will be kept.');
      if (!allowed) return;
      await DatabaseHelper.instance.softDeleteMaterial(material['id']);
      _loadAll();
    } else if (choice == 'delete_all') {
      final allowed = await confirmDeleteWithPassword(context, title: 'Confirm Permanent Delete', warning: 'This permanently deletes this item and its related data. This cannot be undone.');
      if (!allowed) return;
      await DatabaseHelper.instance.hardDeleteMaterialWithTransactions(material['id']);
      _loadAll();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: widget.embedded ? null : AppBar(title: const Text('Materials')),
      floatingActionButton: Padding(
        // Shift left of the main tab scaffold's round "Quick Add" FAB
        // (same bottom-right corner) so the two buttons don't overlap.
        padding: EdgeInsets.only(right: widget.embedded ? 72.0 : 0.0),
        child: FloatingActionButton.extended(
          onPressed: () async {
            final added = await Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const AddMaterialScreen()),
            );
            if (added != null) _loadAll();
          },
          icon: const Icon(Icons.add),
          label: const Text('Add Material'),
        ),
      ),
      body: AdaptiveBackgroundText(
        child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              decoration: const InputDecoration(
                labelText: 'Search materials',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (value) => setState(() => _search = value),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Text('Stock Status:'),
                const SizedBox(width: 12),
                Expanded(
                  child: AdaptiveDropdownButtonFormField<StockFilter>(
                    value: _stockFilter,
                    items: const [
                      DropdownMenuItem(value: StockFilter.all, child: Text('All')),
                      DropdownMenuItem(value: StockFilter.low, child: Text('Low Stock')),
                      DropdownMenuItem(value: StockFilter.notLow, child: Text('Not Low Stock')),
                    ],
                    onChanged: (value) => setState(() => _stockFilter = value ?? StockFilter.all),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: _filteredMaterials.isEmpty
                  ? const Center(child: Text('No materials found.'))
                  : ListView.builder(
                      itemCount: _filteredMaterials.length,
                      itemBuilder: (context, index) {
                        final material = _filteredMaterials[index];
                        final price = material['default_price'];
                        final isLowStock = _isLowStock(material);
                        return ListTile(
                          leading: IconButton(
                            icon: const Icon(Icons.receipt_long),
                            tooltip: 'View Ledger',
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => MaterialLedgerScreen(
                                    materialId: material['id'],
                                    materialName: material['name'],
                                  ),
                                ),
                              );
                            },
                          ),
                          title: Row(
                            children: [
                              Flexible(child: Text(material['name'])),
                              if (isLowStock) ...[
                                const SizedBox(width: 6),
                                const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 18),
                              ],
                            ],
                          ),
                          subtitle: Text(
                            'Stock: ${material['current_stock']} ${material['unit']}'
                            '${price != null ? ' • Price: $price' : ''}'
                            '${isLowStock ? ' • Low stock!' : ''}',
                            style: isLowStock
                                ? const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold)
                                : null,
                          ),
                          onTap: () => _editMaterialDialog(material),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () => _deleteMaterialDialog(material),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
        ),
      ),
    );
  }
}
