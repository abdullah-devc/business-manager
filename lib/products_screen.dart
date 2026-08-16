import 'package:flutter/material.dart';
import 'delete_confirm.dart';
import 'database_helper.dart';
import 'add_product_screen.dart';
import 'product_ledger_screen.dart';
import 'add_unit_dialog.dart';
import 'widgets/glass.dart';

class ProductsScreen extends StatefulWidget {
  final bool embedded;

  const ProductsScreen({super.key, this.embedded = false});

  @override
  State<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends State<ProductsScreen> {
  List<Map<String, dynamic>> _products = [];
  List<Map<String, dynamic>> _units = [];
  String _search = '';

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    final products = await DatabaseHelper.instance.getAllProducts();
    final units = await DatabaseHelper.instance.getAllUnits();
    setState(() {
      _products = products;
      _units = units;
    });
  }

  List<Map<String, dynamic>> get _filteredProducts {
    return _products.where((m) {
      if (_search.trim().isNotEmpty) {
        final q = _search.trim().toLowerCase();
        if (!(m['name'] ?? '').toString().toLowerCase().contains(q)) return false;
      }
      return true;
    }).toList();
  }

  Future<void> _editProductDialog(Map<String, dynamic> material) async {
    final nameCtrl = TextEditingController(text: material['name']);
    final priceCtrl = TextEditingController(
      text: material['default_price'] != null ? material['default_price'].toString() : '',
    );
    String? editUnit = material['unit'];

    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => PinnedDarkText(child: AlertDialog(
          title: const Text('Edit Product'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Product Name')),
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
                TextField(controller: priceCtrl,
                  decoration: const InputDecoration(labelText: 'Default Price (optional)'),
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
      await DatabaseHelper.instance.updateProduct(material['id'], {
        'name': nameCtrl.text.trim(),
        'unit': editUnit,
        'default_price': price,
      });
      _loadAll();
    }
  }

  Future<void> _deleteProductDialog(Map<String, dynamic> material) async {
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
      await DatabaseHelper.instance.softDeleteProduct(material['id']);
      _loadAll();
    } else if (choice == 'delete_all') {
      final allowed = await confirmDeleteWithPassword(context, title: 'Confirm Permanent Delete', warning: 'This permanently deletes this item and its related data. This cannot be undone.');
      if (!allowed) return;
      await DatabaseHelper.instance.hardDeleteProductWithTransactions(material['id']);
      _loadAll();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: widget.embedded ? null : AppBar(title: const Text('Products')),
      floatingActionButton: Padding(
        // Shift left of the main tab scaffold's round "Quick Add" FAB
        // (same bottom-right corner) so the two buttons don't overlap.
        padding: EdgeInsets.only(right: widget.embedded ? 72.0 : 0.0),
        child: FloatingActionButton.extended(
          onPressed: () async {
            final added = await Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const AddProductScreen()),
            );
            if (added != null) _loadAll();
          },
          icon: const Icon(Icons.add),
          label: const Text('Add Product'),
        ),
      ),
      body: AdaptiveBackgroundText(
        child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              decoration: const InputDecoration(
                labelText: 'Search products',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (value) => setState(() => _search = value),
            ),
            const SizedBox(height: 12),

            const SizedBox(height: 12),
            Expanded(
              child: _filteredProducts.isEmpty
                  ? const Center(child: Text('No products found.'))
                  : ListView.builder(
                      itemCount: _filteredProducts.length,
                      itemBuilder: (context, index) {
                        final material = _filteredProducts[index];
                        final price = material['default_price'];
                        return ListTile(
                          leading: IconButton(
                            icon: const Icon(Icons.receipt_long),
                            tooltip: 'View Ledger',
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => ProductLedgerScreen(
                                    productId: material['id'],
                                    productName: material['name'],
                                  ),
                                ),
                              );
                            },
                          ),
                          title: Text(material['name']),
                          subtitle: Text(
                            '${price != null ? 'Price: $price' : 'No default price'} • Unit: ${material['unit']}',
                          ),
                          onTap: () => _editProductDialog(material),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () => _deleteProductDialog(material),
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
