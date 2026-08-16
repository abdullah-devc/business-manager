import 'package:flutter/material.dart';
import 'delete_confirm.dart';
import 'add_company_screen.dart';
import 'add_material_screen.dart';
import 'add_product_screen.dart';
import 'database_helper.dart';
import 'invoice_pdf_service.dart';
import 'invoice_preview_screen.dart';
import 'widgets/glass.dart';

class AddInvoiceScreen extends StatefulWidget {
  final Map<String, dynamic>? existingInvoice;

  const AddInvoiceScreen({super.key, this.existingInvoice});

  @override
  State<AddInvoiceScreen> createState() => _AddInvoiceScreenState();
}

class _AddInvoiceScreenState extends State<AddInvoiceScreen> {
  List<Map<String, dynamic>> _companies = [];
  List<Map<String, dynamic>> _materials = [];
  List<Map<String, dynamic>> _products = [];
  List<Map<String, dynamic>> _lineItems = [];

  int? _selectedCompanyId;
  DateTime _issueDate = DateTime.now();
  DateTime? _dueDate;
  DateTime? _validUntil;
  String _documentType = 'invoice';
  final _notesController = TextEditingController();
  final _invoiceNumberController = TextEditingController();
  final _termsController = TextEditingController();

  int? _selectedMaterialId;
  int? _selectedProductId;
  String _itemType = 'material';
  final _qtyController = TextEditingController();
  final _priceController = TextEditingController();

  int? _invoiceId;
  String _status = 'draft';
  String _invoiceNumber = '';
  bool _saving = false;
  bool _confirming = false;

  bool get _isEditing => widget.existingInvoice != null;
  bool get _isLocked => _status == 'confirmed';

  @override
  void initState() {
    super.initState();
    _loadDropdownData(applyDraftDefaults: true);
    if (_isEditing) {
      _invoiceId = widget.existingInvoice!['id'];
      _selectedCompanyId = widget.existingInvoice!['company_id'];
      _status = widget.existingInvoice!['status'];
      _documentType = widget.existingInvoice!['document_type'] ?? 'invoice';
      _invoiceNumber = widget.existingInvoice!['invoice_number'];
      _invoiceNumberController.text = _invoiceNumber;
      _issueDate = DateTime.parse(widget.existingInvoice!['issue_date']);
      if (widget.existingInvoice!['due_date'] != null) {
        _dueDate = DateTime.parse(widget.existingInvoice!['due_date']);
      }
      if (widget.existingInvoice!['valid_until'] != null) {
        _validUntil = DateTime.parse(widget.existingInvoice!['valid_until']);
      }
      _notesController.text = widget.existingInvoice!['notes'] ?? '';
      _termsController.text = widget.existingInvoice!['terms'] ?? '';
      _loadLineItems();
    }
  }

  Future<void> _loadDropdownData({bool applyDraftDefaults = false}) async {
    final companies = await DatabaseHelper.instance.getAllCompanies();
    final materials = await DatabaseHelper.instance.getAllMaterials();
    final products = await DatabaseHelper.instance.getAllProducts();
    final profile = await DatabaseHelper.instance.getBusinessProfile();
    if (!mounted) return;
    final paymentDays = (profile['default_payment_days'] as num?)?.toInt() ?? 0;
    setState(() {
      _companies = companies;
      _materials = materials;
      _products = products;
      if (applyDraftDefaults && !_isEditing && paymentDays > 0) {
        _dueDate = _issueDate.add(Duration(days: paymentDays));
      }
      if (applyDraftDefaults && !_isEditing) {
        _termsController.text = profile['default_invoice_terms'] ?? '';
      }
    });
  }

  Future<void> _loadLineItems() async {
    if (_invoiceId == null) return;
    final items = await DatabaseHelper.instance.getInvoiceItems(_invoiceId!);
    setState(() => _lineItems = items);
  }

  void _onMaterialSelected(int? materialId) {
    setState(() { _selectedMaterialId = materialId; _selectedProductId = null; });
    if (materialId != null && _priceController.text.trim().isEmpty) {
      final material = _materials.firstWhere((m) => m['id'] == materialId);
      if (material['default_price'] != null) _priceController.text = material['default_price'].toString();
    }
  }

  void _onProductSelected(int? productId) {
    setState(() { _selectedProductId = productId; _selectedMaterialId = null; });
    if (productId != null && _priceController.text.trim().isEmpty) {
      final product = _products.firstWhere((p) => p['id'] == productId);
      if (product['default_price'] != null) _priceController.text = product['default_price'].toString();
    }
  }

  Future<void> _addCompany() async {
    final companyId = await Navigator.push<int>(context, MaterialPageRoute(builder: (_) => const AddCompanyScreen()));
    if (companyId == null || !mounted) return;
    await _loadDropdownData();
    if (mounted) setState(() => _selectedCompanyId = companyId);
  }

  Future<void> _addMaterial() async {
    final materialId = await Navigator.push<int>(context, MaterialPageRoute(builder: (_) => const AddMaterialScreen()));
    if (materialId == null || !mounted) return;
    await _loadDropdownData();
    if (mounted) _onMaterialSelected(materialId);
  }

  Future<void> _addProduct() async {
    final productId = await Navigator.push<int>(context, MaterialPageRoute(builder: (_) => const AddProductScreen()));
    if (productId == null || !mounted) return;
    await _loadDropdownData();
    if (mounted) _onProductSelected(productId);
  }

  Future<int> _ensureInvoiceCreated() async {
    if (_invoiceId != null) return _invoiceId!;

    if (!await _validateInvoiceNumber()) throw Exception('Choose a unique invoice number.');
    final requestedNumber = _invoiceNumberController.text.trim();
    final invoiceNumber = requestedNumber.isEmpty
        ? await DatabaseHelper.instance.generateNextInvoiceNumber()
        : requestedNumber;
    final id = await DatabaseHelper.instance.insertInvoice({
      'company_id': _selectedCompanyId,
      'invoice_number': invoiceNumber,
      'status': 'draft',
      'document_type': _documentType,
      'issue_date': _issueDate.toIso8601String(),
      'due_date': _dueDate?.toIso8601String(),
      'valid_until': _validUntil?.toIso8601String(),
      'notes': _notesController.text.trim(),
      'terms': _termsController.text.trim(),
      'created_at': DateTime.now().toIso8601String(),
    });
    setState(() {
      _invoiceId = id;
      _invoiceNumber = invoiceNumber;
      _invoiceNumberController.text = invoiceNumber;
    });
    return id;
  }

  Future<void> _addLineItem() async {
    if (_selectedCompanyId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select a company first.')));
      return;
    }
    final selectedId = _itemType == 'product' ? _selectedProductId : _selectedMaterialId;
    if (selectedId == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Please select a ${_itemType == 'product' ? 'product' : 'material'}.')));
      return;
    }
    final quantity = double.tryParse(_qtyController.text.trim());
    if (quantity == null || quantity <= 0) {
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
    setState(() => _saving = true);
    try {
      final invoiceId = await _ensureInvoiceCreated();
      await DatabaseHelper.instance.insertInvoiceItem({
        'invoice_id': invoiceId,
        'material_id': _itemType == 'material' ? _selectedMaterialId : null,
        'product_id': _itemType == 'product' ? _selectedProductId : null,
        'item_type': _itemType,
        'quantity': quantity,
        'price': price,
      });
      _qtyController.clear();
      _priceController.clear();
      setState(() { _selectedMaterialId = null; _selectedProductId = null; });
      await _loadLineItems();
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error adding line item: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _removeLineItem(int itemId) async {
    final allowed = await confirmDeleteWithPassword(context, title: 'Delete Invoice Item?', warning: 'This line item will be permanently removed from the invoice.');
    if (!allowed) return;
    await DatabaseHelper.instance.deleteInvoiceItem(itemId);
    _loadLineItems();
  }

  Future<void> _pickIssueDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _issueDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _issueDate = picked);
  }

  Future<void> _pickDueDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dueDate ?? _issueDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _dueDate = picked);
  }

  Future<void> _pickValidUntil() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _validUntil ?? _issueDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _validUntil = picked);
  }

  double get _grandTotal {
    double total = 0;
    for (final item in _lineItems) {
      final qty = (item['quantity'] as num).toDouble();
      final price = item['price'] != null ? (item['price'] as num).toDouble() : 0.0;
      total += qty * price;
    }
    return total;
  }

  Future<void> _saveDraftAndExit() async {
    if (_invoiceId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select a company and add at least one line item before saving.')),
      );
      return;
    }
    if (!await _validateInvoiceNumber()) return;
    await DatabaseHelper.instance.updateInvoice(_invoiceId!, {
      'company_id': _selectedCompanyId,
      'invoice_number': _invoiceNumberController.text.trim(),
      'document_type': _documentType,
      'issue_date': _issueDate.toIso8601String(),
      'due_date': _dueDate?.toIso8601String(),
      'valid_until': _validUntil?.toIso8601String(),
      'notes': _notesController.text.trim(),
      'terms': _termsController.text.trim(),
    });
    if (context.mounted) Navigator.pop(context, true);
  }

  Future<void> _confirmInvoice() async {
    if (_invoiceId == null || _lineItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add at least one line item before confirming.')),
      );
      return;
    }
    if (_documentType != 'invoice') {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Change the document type to Invoice before confirming a sale.')));
      return;
    }
    if (!await _validateInvoiceNumber()) return;

    // Aggregate requested quantity per item type/id.
    final Map<String, double> requested = {};
    for (final item in _lineItems) {
      final itemType = item['item_type'] ?? 'material';
      final itemId = itemType == 'product' ? item['product_id'] : item['material_id'];
      final qty = (item['quantity'] as num).toDouble();
      requested['$itemType:$itemId'] = (requested['$itemType:$itemId'] ?? 0) + qty;
    }

    final List<String> insufficient = [];
    requested.forEach((key, qty) {
      final parts = key.split(':');
      final itemType = parts[0];
      final id = int.parse(parts[1]);
      // Products do not use the inventory stock system. Only materials
      // participate in stock validation.
      if (itemType != 'material') return;
      final item = _materials.firstWhere((m) => m['id'] == id, orElse: () => {});
      if (item.isEmpty) return;
      final stock = (item['current_stock'] as num).toDouble();
      if (qty > stock) {
        insufficient.add('${item['name']}: need $qty ${item['unit']}, only $stock available');
      }
    });

    if (insufficient.isNotEmpty) {
      final proceed = await showDialog<bool>(
        context: context,
        builder: (context) => PinnedDarkText(child: AlertDialog(
          title: const Text('Insufficient Stock'),
          content: Text(
            'The following materials don\'t have enough stock:\n\n${insufficient.join('\n')}\n\n'
            'Confirming anyway will allow stock to go negative. Continue?',
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Confirm Anyway', style: TextStyle(color: Colors.red)),
            ),
          ],
        )),
      );
      if (proceed != true) return;
    } else {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => PinnedDarkText(child: AlertDialog(
          title: const Text('Confirm Invoice?'),
          content: Text(
            'This will create transactions for each line item, update material stock where applicable, and lock the invoice for editing. '
            'Total: ${_grandTotal.toStringAsFixed(2)}',
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
            TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Confirm')),
          ],
        )),
      );
      if (confirm != true) return;
    }

    setState(() => _confirming = true);
    try {
      await DatabaseHelper.instance.updateInvoice(_invoiceId!, {
        'invoice_number': _invoiceNumberController.text.trim(),
        'document_type': _documentType,
        'issue_date': _issueDate.toIso8601String(),
        'due_date': _dueDate?.toIso8601String(),
        'valid_until': _validUntil?.toIso8601String(),
        'notes': _notesController.text.trim(),
        'terms': _termsController.text.trim(),
      });
      await DatabaseHelper.instance.confirmInvoice(_invoiceId!);
      if (context.mounted) Navigator.pop(context, true);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error confirming invoice: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _confirming = false);
    }
  }

  Map<String, dynamic> _invoiceForDocument() {
    final company = _companies.firstWhere(
      (item) => item['id'] == _selectedCompanyId,
      orElse: () => <String, dynamic>{},
    );
    return {
      'invoice_number': _invoiceNumberController.text.trim().isEmpty ? _invoiceNumber : _invoiceNumberController.text.trim(),
      'status': _status,
      'document_type': _documentType,
      'issue_date': _issueDate.toIso8601String(),
      'due_date': _dueDate?.toIso8601String(),
      'valid_until': _validUntil?.toIso8601String(),
      'notes': _notesController.text.trim(),
      'terms': _termsController.text.trim(),
      'company_name': company['name'],
      'contact_person': company['contact_person'],
      'phone': company['phone'],
      'address': company['address'],
    };
  }

  Future<bool> _validateInvoiceNumber() async {
    final invoiceNumber = _invoiceNumberController.text.trim();
    if (invoiceNumber.isEmpty) {
      if (_invoiceId == null) return true;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Invoice number cannot be empty.')));
      }
      return false;
    }
    final exists = await DatabaseHelper.instance.invoiceNumberExists(invoiceNumber, excludingId: _invoiceId);
    if (exists) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('That invoice number already exists.')));
      }
      return false;
    }
    return true;
  }

  Future<void> _savePdf() async {
    try {
      final path = await InvoicePdfService.save(
        invoice: _invoiceForDocument(),
        lineItems: _lineItems,
      );
      if (path != null && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('PDF saved to $path')));
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not save PDF: $error')));
      }
    }
  }

  Future<void> _sharePdf() async {
    try {
      final shared = await InvoicePdfService.share(
        invoice: _invoiceForDocument(),
        lineItems: _lineItems,
      );
      if (shared && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Invoice PDF shared')));
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not share PDF: $error')));
      }
    }
  }

  Future<void> _printPdf() async {
    try {
      await InvoicePdfService.print(invoice: _invoiceForDocument(), lineItems: _lineItems);
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not print invoice: $error')));
      }
    }
  }

  @override
  void dispose() {
    _notesController.dispose();
    _invoiceNumberController.dispose();
    _termsController.dispose();
    _qtyController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Line items are persisted as they are added, so any exit path must
    // notify the invoices list to refresh when a draft has been created.
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        Navigator.pop(context, _invoiceId != null);
      },
      child: Scaffold(
        appBar: AppBar(
        actions: [
          if (_invoiceId != null && _lineItems.isNotEmpty) ...[
            IconButton(
              icon: const Icon(Icons.picture_as_pdf),
              tooltip: 'Save PDF',
              onPressed: _savePdf,
            ),
            IconButton(
              icon: const Icon(Icons.share),
              tooltip: 'Share PDF',
              onPressed: _sharePdf,
            ),
            IconButton(
              icon: const Icon(Icons.preview),
              tooltip: 'Preview document',
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => InvoicePreviewScreen(invoice: _invoiceForDocument(), lineItems: _lineItems)),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.print),
              tooltip: 'Print invoice',
              onPressed: _printPdf,
            ),
          ],
        ],
        title: Text(_isLocked ? '$_invoiceNumber — Confirmed' : (_isEditing ? 'Edit Invoice (Draft)' : 'New Invoice')),
      ),
        body: AdaptiveBackgroundText(
        child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView(
          children: [
            if (_isLocked)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  border: Border.all(color: Colors.green),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.check_circle, color: Colors.green),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'This invoice is confirmed and locked. Its line items are now real transactions — manage payments from the Transactions or Ledger screens.',
                      ),
                    ),
                  ],
                ),
              ),
            if (!_isLocked && _invoiceId != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  border: Border.all(color: Colors.blue.shade200),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Draft $_invoiceNumber is already saved — line items save as you add them. '
                  '“Save Draft” saves the company, dates, and notes below.',
                  style: const TextStyle(fontSize: 12, color: Colors.blueGrey),
                ),
              ),
            if (!_isLocked) ...[
              const SizedBox(height: 12),
              TextField(
                controller: _invoiceNumberController,
                decoration: InputDecoration(
                  labelText: 'Invoice Number',
                  hintText: 'Leave empty to auto-generate',
                  helperText: _invoiceId == null ? 'An invoice number is created when you add the first line item.' : null,
                ),
                textCapitalization: TextCapitalization.characters,
              ),
              const SizedBox(height: 12),
              AdaptiveDropdownButtonFormField<String>(
                value: _documentType,
                decoration: const InputDecoration(labelText: 'Document Type'),
                items: const [
                  DropdownMenuItem(value: 'invoice', child: Text('Invoice')),
                  DropdownMenuItem(value: 'quote', child: Text('Quote')),
                  DropdownMenuItem(value: 'proforma', child: Text('Proforma Invoice')),
                ],
                onChanged: (value) => setState(() => _documentType = value ?? 'invoice'),
              ),
            ],
            Row(
              children: [
                Expanded(
                  child: AdaptiveDropdownButtonFormField<int>(
                    value: _selectedCompanyId,
                    decoration: const InputDecoration(labelText: 'Company'),
                    items: _companies.map((c) {
                      return DropdownMenuItem<int>(value: c['id'] as int, child: Text(c['name']));
                    }).toList(),
                    onChanged: (_isLocked || _invoiceId != null)
                        ? null
                        : (value) => setState(() => _selectedCompanyId = value),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.add_circle_outline),
                  tooltip: 'Add new company',
                  onPressed: (_isLocked || _invoiceId != null) ? null : _addCompany,
                ),
              ],
            ),
            if (!_isLocked && _invoiceId != null)
              const Padding(
                padding: EdgeInsets.only(top: 4.0),
                child: Text(
                  'Company is locked once the invoice is started. Delete and recreate to change it.',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _isLocked ? null : _pickIssueDate,
                    icon: const Icon(Icons.calendar_today),
                    label: Text('Issue: ${_issueDate.toString().split(' ').first}'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _isLocked ? null : _pickDueDate,
                    icon: const Icon(Icons.event),
                    label: Text(_dueDate == null ? 'Due Date (optional)' : _dueDate!.toString().split(' ').first),
                  ),
                ),
            if (_dueDate != null && !_isLocked)
                  IconButton(
                    icon: const Icon(Icons.clear, size: 18),
                    onPressed: () => setState(() => _dueDate = null),
                  ),
              ],
            ),
            if ((_documentType == 'quote' || _documentType == 'proforma') && !_isLocked) ...[
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _pickValidUntil,
                icon: const Icon(Icons.event_available),
                label: Text(_validUntil == null ? 'Valid Until (optional)' : 'Valid Until: ${_validUntil!.toString().split(' ').first}'),
              ),
            ],
            if (!_isLocked) ...[
              const SizedBox(height: 16),
              const Divider(),
              const Text('Add Line Item', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(child: RadioListTile<String>(title: const Text('Material'), value: 'material', groupValue: _itemType, onChanged: (value) => setState(() { _itemType = value!; _selectedMaterialId = null; _selectedProductId = null; _priceController.clear(); }))),
                  Expanded(child: RadioListTile<String>(title: const Text('Product'), value: 'product', groupValue: _itemType, onChanged: (value) => setState(() { _itemType = value!; _selectedMaterialId = null; _selectedProductId = null; _priceController.clear(); }))),
                ],
              ),
              Row(
                children: [
                  Expanded(
                    child: AdaptiveDropdownButtonFormField<int>(
                      value: _itemType == 'material' ? _selectedMaterialId : _selectedProductId,
                      decoration: InputDecoration(labelText: _itemType == 'material' ? 'Material' : 'Product'),
                      items: (_itemType == 'material' ? _materials : _products).map((item) {
                        return DropdownMenuItem<int>(value: item['id'] as int, child: Text('${item['name']} (${item['unit']})'));
                      }).toList(),
                      onChanged: _itemType == 'material' ? _onMaterialSelected : _onProductSelected,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.add_circle_outline),
                    tooltip: 'Add ${_itemType == 'material' ? 'material' : 'product'}',
                    onPressed: _itemType == 'material' ? _addMaterial : _addProduct,
                  ),
                ],
              ),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _qtyController,
                      decoration: const InputDecoration(labelText: 'Quantity'),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _priceController,
                      decoration: const InputDecoration(labelText: 'Price (auto-filled, editable)'),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              GlassActionButton(
                onPressed: _saving ? null : _addLineItem,
                icon: Icons.add,
                color: Colors.purple,
                expand: true,
                label: Text(_saving ? 'Adding...' : 'Add Line Item'),
              ),
            ],
            const SizedBox(height: 16),
            const Divider(),
            const Text('Line Items', style: TextStyle(fontWeight: FontWeight.bold)),
            if (_lineItems.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12.0),
                child: Text('No line items yet.', style: TextStyle(color: Colors.grey)),
              )
            else
              ..._lineItems.map((item) {
                final qty = (item['quantity'] as num).toDouble();
                final price = item['price'] != null ? (item['price'] as num).toDouble() : null;
                final lineTotal = price != null ? qty * price : null;
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text('${item['material_name']} — $qty ${item['material_unit']}'),
                  leading: Chip(label: Text((item['item_type'] ?? 'material') == 'product' ? 'Product' : 'Material')),
                  subtitle: Text(price != null ? 'Price: ${price.toStringAsFixed(2)} • Total: ${lineTotal!.toStringAsFixed(2)}' : 'No price set'),
                  trailing: _isLocked
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () => _removeLineItem(item['id']),
                        ),
                );
              }),
            const Divider(),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Text(
                'Grand Total: ${_grandTotal.toStringAsFixed(2)}',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            TextField(
              controller: _notesController,
              enabled: !_isLocked,
              decoration: const InputDecoration(labelText: 'Notes (optional)'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _termsController,
              enabled: !_isLocked,
              decoration: const InputDecoration(labelText: 'Terms / Payment Instructions (optional)'),
              maxLines: 3,
            ),
            const SizedBox(height: 16),
            if (!_isLocked) ...[
              GlassActionButton(
                onPressed: _saveDraftAndExit,
                icon: Icons.save,
                color: Colors.purple,
                expand: true,
                label: Text(_documentType == 'quote' ? 'Save Quote' : _documentType == 'proforma' ? 'Save Proforma Invoice' : 'Save Draft'),
              ),
              const SizedBox(height: 8),
              if (_documentType == 'invoice')
                GlassActionButton(
                  onPressed: _confirming ? null : _confirmInvoice,
                  icon: Icons.check_circle,
                  color: Colors.green,
                  expand: true,
                  label: Text(_confirming ? 'Confirming...' : 'Confirm Invoice'),
                ),
              if (_documentType != 'invoice')
                const Text(
                  'Quotes and proforma invoices do not change stock. Change Document Type to Invoice when you are ready to confirm the sale.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
            ],
          ],
        ),
      ),
      ),
      ),
    );
  }
}
