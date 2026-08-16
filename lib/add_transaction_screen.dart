import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';

import 'add_company_screen.dart';
import 'add_material_screen.dart';
import 'add_product_screen.dart';
import 'database_helper.dart';
import 'widgets/glass.dart';

class AddTransactionScreen extends StatefulWidget {
  const AddTransactionScreen({super.key});

  @override
  State<AddTransactionScreen> createState() => _AddTransactionScreenState();
}

class _AddTransactionScreenState extends State<AddTransactionScreen> {
  List<Map<String, dynamic>> _companies = [];
  List<Map<String, dynamic>> _materials = [];
  List<Map<String, dynamic>> _products = [];
  List<Map<String, dynamic>> _units = [];
  int? _selectedCompanyId;
  int? _selectedMaterialId;
  int? _selectedProductId;
  String _itemType = 'material';
  String _type = 'in';
  bool _markPaidNow = false;
  String? _attachmentPath;

  final _quantityController = TextEditingController();
  final _priceController = TextEditingController();
  final _transactionNumberController = TextEditingController();
  final _notesController = TextEditingController();

  bool get _hasPrice => _priceController.text.trim().isNotEmpty;
  bool get _isSale => _type == 'out';

  @override
  void initState() {
    super.initState();
    _loadDropdownData();
    _priceController.addListener(_onPriceChanged);
  }

  void _onPriceChanged() {
    if (!_hasPrice && _markPaidNow) {
      setState(() => _markPaidNow = false);
    } else {
      setState(() {});
    }
  }

  Future<void> _loadDropdownData() async {
    final companies = await DatabaseHelper.instance.getAllCompanies();
    final materials = await DatabaseHelper.instance.getAllMaterials();
    final products = await DatabaseHelper.instance.getAllProducts();
    final units = await DatabaseHelper.instance.getAllUnits();
    if (!mounted) return;
    setState(() {
      _companies = companies;
      _materials = materials;
      _products = products;
      _units = units;
    });
  }

  void _onMaterialSelected(int? materialId) {
    setState(() {
      _selectedMaterialId = materialId;
      _selectedProductId = null;
    });
    if (materialId != null && _priceController.text.trim().isEmpty) {
      final material = _materials.firstWhere((m) => m['id'] == materialId);
      if (material['default_price'] != null) _priceController.text = material['default_price'].toString();
    }
  }

  void _onProductSelected(int? productId) {
    setState(() {
      _selectedProductId = productId;
      _selectedMaterialId = null;
    });
    if (productId != null && _priceController.text.trim().isEmpty) {
      final product = _products.firstWhere((p) => p['id'] == productId);
      if (product['default_price'] != null) _priceController.text = product['default_price'].toString();
    }
  }

  Future<void> _addCompany() async {
    final companyId = await Navigator.push<int>(
      context,
      MaterialPageRoute(builder: (_) => const AddCompanyScreen()),
    );
    if (companyId == null || !mounted) return;
    await _loadDropdownData();
    if (mounted) setState(() => _selectedCompanyId = companyId);
  }

  Future<void> _addMaterial() async {
    final materialId = await Navigator.push<int>(
      context,
      MaterialPageRoute(builder: (_) => const AddMaterialScreen()),
    );
    if (materialId == null || !mounted) return;
    await _loadDropdownData();
    if (mounted) _onMaterialSelected(materialId);
  }

  Future<void> _addProduct() async {
    final productId = await Navigator.push<int>(
      context,
      MaterialPageRoute(builder: (_) => const AddProductScreen()),
    );
    if (productId == null || !mounted) return;
    await _loadDropdownData();
    if (mounted) _onProductSelected(productId);
  }

  Future<void> _chooseAttachment() async {
    final file = await openFile(
      acceptedTypeGroups: const [
        XTypeGroup(label: 'Bill images', extensions: ['png', 'jpg', 'jpeg', 'webp']),
      ],
    );
    if (file == null) return;
    try {
      final savedPath = await DatabaseHelper.instance.saveTransactionAttachment(file.path);
      if (mounted) setState(() => _attachmentPath = savedPath);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not save the bill image: $error')),
        );
      }
    }
  }

  Future<void> _save() async {
    if (_selectedCompanyId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select a company.')));
      return;
    }
    final selectedId = _itemType == 'product' ? _selectedProductId : _selectedMaterialId;
    if (selectedId == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Please select a ${_itemType == 'product' ? 'product' : 'material'}.')));
      return;
    }
    final quantityText = _quantityController.text.trim();
    final quantity = double.tryParse(quantityText);
    if (quantityText.isEmpty || quantity == null || quantity <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter a valid quantity greater than 0.')));
      return;
    }
    double? price;
    if (_priceController.text.trim().isNotEmpty) {
      price = double.tryParse(_priceController.text.trim());
      if (price == null || price < 0) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Price must be a valid non-negative number.')));
        return;
      }
    }

    final item = _itemType == 'product'
        ? _products.firstWhere((p) => p['id'] == _selectedProductId)
        : _materials.firstWhere((m) => m['id'] == _selectedMaterialId);
    final transactionId = await DatabaseHelper.instance.insertTransaction({
      'company_id': _selectedCompanyId,
      'material_id': _itemType == 'material' ? _selectedMaterialId : null,
      'product_id': _itemType == 'product' ? _selectedProductId : null,
      'item_type': _itemType,
      'type': _type,
      'quantity': quantity,
      'price': price,
      'paid': 0,
      'transaction_date': DateTime.now().toIso8601String(),
      'transaction_number': _transactionNumberController.text.trim().isEmpty ? null : _transactionNumberController.text.trim(),
      'attachment_path': _attachmentPath,
      'notes': _notesController.text.trim(),
    });
    if (price != null && _markPaidNow) {
      await DatabaseHelper.instance.insertPayment({
        'transaction_id': transactionId,
        'amount': quantity * price,
        'payment_date': DateTime.now().toIso8601String(),
        'notes': 'Paid in full at time of transaction',
      });
    }
    if (_itemType == 'material') {
      await DatabaseHelper.instance.updateMaterialStock(selectedId as int, _type == 'in' ? quantity : -quantity);
    }
    if (context.mounted) Navigator.pop(context, true);
  }

  @override
  void dispose() {
    _priceController.removeListener(_onPriceChanged);
    _quantityController.dispose();
    _priceController.dispose();
    _transactionNumberController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Add Transaction')),
        body: AdaptiveBackgroundText(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: ListView(children: [
              Row(children: [
                Expanded(child: AdaptiveDropdownButtonFormField<int>(
                  value: _selectedCompanyId,
                  decoration: InputDecoration(labelText: _type == 'in' ? 'Bought From (Company)' : 'Sold To (Company)'),
                  items: _companies.map((c) => DropdownMenuItem<int>(value: c['id'] as int, child: Text(c['name']))).toList(),
                  onChanged: (value) => setState(() => _selectedCompanyId = value),
                )),
                IconButton(icon: const Icon(Icons.add_circle_outline), tooltip: 'Add new company', onPressed: _addCompany),
              ]),
              Row(children: [
                Expanded(child: RadioListTile<String>(title: const Text('In (Buy)'), value: 'in', groupValue: _type, onChanged: (value) => setState(() { _type = value!; }))),
                Expanded(child: RadioListTile<String>(title: const Text('Out (Sell)'), value: 'out', groupValue: _type, onChanged: (value) => setState(() => _type = value!))),
              ]),
              Row(
                children: [
                  Expanded(child: RadioListTile<String>(title: const Text('Material'), value: 'material', groupValue: _itemType, onChanged: (value) => setState(() { _itemType = value!; _selectedMaterialId = null; _selectedProductId = null; _priceController.clear(); }))),
                  Expanded(child: RadioListTile<String>(title: const Text('Product'), value: 'product', groupValue: _itemType, onChanged: (value) => setState(() { _itemType = value!; _selectedMaterialId = null; _selectedProductId = null; _priceController.clear(); }))),
                ],
              ),
              Row(children: [
                Expanded(child: AdaptiveDropdownButtonFormField<int>(
                  value: _itemType == 'material' ? _selectedMaterialId : _selectedProductId,
                  decoration: InputDecoration(labelText: _itemType == 'material' ? 'Material' : 'Product'),
                  items: (_itemType == 'material' ? _materials : _products).map((item) => DropdownMenuItem<int>(value: item['id'] as int, child: Text('${item['name']} (${item['unit']})'))).toList(),
                  onChanged: _itemType == 'material' ? _onMaterialSelected : _onProductSelected,
                )),
                IconButton(icon: const Icon(Icons.add_circle_outline), tooltip: 'Add ${_itemType == 'material' ? 'material' : 'product'}', onPressed: _itemType == 'material' ? _addMaterial : _addProduct),
              ]),
              TextField(controller: _quantityController, decoration: const InputDecoration(labelText: 'Quantity / Number of Units'), keyboardType: TextInputType.number),
              TextField(controller: _priceController, decoration: const InputDecoration(labelText: 'Price'), keyboardType: TextInputType.number),
              TextField(controller: _transactionNumberController, decoration: const InputDecoration(labelText: 'Transaction Number (optional)')),
              const SizedBox(height: 8),
              OutlinedButton.icon(onPressed: _chooseAttachment, icon: const Icon(Icons.upload_file), label: Text(_attachmentPath == null ? 'Upload bill or receipt image' : 'Bill image selected')),
              if (_attachmentPath != null) Text(_attachmentPath!, maxLines: 1, overflow: TextOverflow.ellipsis),
              SwitchListTile(title: const Text('Mark as Paid Now'), subtitle: Text(_hasPrice ? 'You can add partial payments later from the transaction' : 'Enter a price first'), value: _markPaidNow, onChanged: _hasPrice ? (v) => setState(() => _markPaidNow = v) : null),
              ValueListenableBuilder<TextEditingValue>(valueListenable: _quantityController, builder: (context, q, _) => ValueListenableBuilder<TextEditingValue>(valueListenable: _priceController, builder: (context, p, _) { final qty = double.tryParse(q.text); final price = double.tryParse(p.text); return qty != null && price != null ? Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Text('Amount: ${(qty * price).toStringAsFixed(2)}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold))) : const SizedBox.shrink(); })),
              TextField(controller: _notesController, decoration: const InputDecoration(labelText: 'Notes (optional)')),
              const SizedBox(height: 16),
              GlassActionButton(onPressed: _save, icon: Icons.save, color: Colors.blue, expand: true, label: const Text('Save Transaction')),
            ]),
          ),
        ),
      );

}
