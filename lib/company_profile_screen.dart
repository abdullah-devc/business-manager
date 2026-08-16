import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';

import 'database_helper.dart';
import 'widgets/glass.dart';
import 'widgets/app_loading_indicator.dart';

class CompanyProfileScreen extends StatefulWidget {
  final bool embedded;

  const CompanyProfileScreen({super.key, this.embedded = false});

  @override
  State<CompanyProfileScreen> createState() => _CompanyProfileScreenState();
}

class _CompanyProfileScreenState extends State<CompanyProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _businessName = TextEditingController();
  final _contactPerson = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  final _address = TextEditingController();
  final _taxNumber = TextEditingController();
  final _invoicePrefix = TextEditingController();
  final _paymentDays = TextEditingController();
  final _invoiceFooter = TextEditingController();
  final _defaultInvoiceTerms = TextEditingController();
  final _paymentInstructions = TextEditingController();
  String? _logoPath;
  String? _signaturePath;
  String _accentColor = '#1F5AA6';
  String _invoiceTemplate = 'classic';
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final profile = await DatabaseHelper.instance.getBusinessProfile();
    _businessName.text = profile['business_name'] ?? '';
    _contactPerson.text = profile['contact_person'] ?? '';
    _phone.text = profile['phone'] ?? '';
    _email.text = profile['email'] ?? '';
    _address.text = profile['address'] ?? '';
    _taxNumber.text = profile['tax_number'] ?? '';
    _invoicePrefix.text = profile['invoice_prefix'] ?? 'INV';
    _paymentDays.text = (profile['default_payment_days'] ?? 0).toString();
    _invoiceFooter.text = profile['invoice_footer'] ?? '';
    _defaultInvoiceTerms.text = profile['default_invoice_terms'] ?? '';
    _paymentInstructions.text = profile['payment_instructions'] ?? '';
    _logoPath = profile['logo_path']?.toString().trim();
    _signaturePath = await DatabaseHelper.instance.getAppSetting('invoice_signature_path');
    _accentColor = profile['accent_color'] ?? '#1F5AA6';
    _invoiceTemplate = profile['invoice_template'] ?? 'classic';
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await DatabaseHelper.instance.saveBusinessProfile({
        'business_name': _businessName.text.trim(),
        'contact_person': _contactPerson.text.trim(),
        'phone': _phone.text.trim(),
        'email': _email.text.trim(),
        'address': _address.text.trim(),
        'tax_number': _taxNumber.text.trim(),
        'invoice_prefix': _invoicePrefix.text.trim().toUpperCase(),
        'default_payment_days': int.parse(_paymentDays.text.trim()),
        'invoice_footer': _invoiceFooter.text.trim(),
        'logo_path': _logoPath ?? '',
        'accent_color': _accentColor,
        'invoice_template': _invoiceTemplate,
        'default_invoice_terms': _defaultInvoiceTerms.text.trim(),
        'payment_instructions': _paymentInstructions.text.trim(),
      });
      await DatabaseHelper.instance.setAppSetting('invoice_signature_path', _signaturePath ?? '');
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Company profile saved.')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _selectSignature() async {
    final file = await openFile(
      acceptedTypeGroups: const [
        XTypeGroup(label: 'Image files', extensions: ['png', 'jpg', 'jpeg']),
      ],
    );
    if (file != null && mounted) setState(() => _signaturePath = file.path);
  }

  Future<void> _selectLogo() async {
    final file = await openFile(
      acceptedTypeGroups: const [
        XTypeGroup(label: 'Image files', extensions: ['png', 'jpg', 'jpeg']),
      ],
    );
    if (file != null && mounted) setState(() => _logoPath = file.path);
  }

  @override
  void dispose() {
    _businessName.dispose();
    _contactPerson.dispose();
    _phone.dispose();
    _email.dispose();
    _address.dispose();
    _taxNumber.dispose();
    _invoicePrefix.dispose();
    _paymentDays.dispose();
    _invoiceFooter.dispose();
    _defaultInvoiceTerms.dispose();
    _paymentInstructions.dispose();
    super.dispose();
  }

  Widget _buildContent(BuildContext context) {
    if (_loading)
      return const AppLoadingView(label: 'Loading business profile');
    return AdaptiveBackgroundText(
      // Builder gives us a BuildContext below the adaptive Theme that
      // AdaptiveBackgroundText inserts — otherwise `Theme.of(context)`
      // in the headings below resolves against the stale outer context
      // and stays the app's static (dark-text) light theme regardless
      // of background brightness.
      child: Builder(
        builder: (context) => Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                'Business Details',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              GlassContainer(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    SizedBox(
                      width: 84,
                      height: 64,
                      child:
                          _logoPath != null &&
                              _logoPath!.isNotEmpty &&
                              File(_logoPath!).existsSync()
                          ? Image.file(File(_logoPath!), fit: BoxFit.contain)
                          : const Center(
                              child: Icon(Icons.image_outlined, size: 36),
                            ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Business Logo',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const Text(
                            'Shown at the top of invoice PDFs.',
                            style: TextStyle(fontSize: 12),
                          ),
                          Wrap(
                            spacing: 8,
                            children: [
                              TextButton.icon(
                                onPressed: _selectLogo,
                                icon: const Icon(Icons.upload_file),
                                label: const Text('Choose Logo'),
                              ),
                              if (_logoPath != null && _logoPath!.isNotEmpty)
                                TextButton.icon(
                                  onPressed: () =>
                                      setState(() => _logoPath = ''),
                                  icon: const Icon(Icons.clear),
                                  label: const Text('Remove'),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              GlassContainer(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    SizedBox(
                      width: 140,
                      height: 64,
                      child: _signaturePath != null &&
                              _signaturePath!.isNotEmpty &&
                              File(_signaturePath!).existsSync()
                          ? Image.file(File(_signaturePath!), fit: BoxFit.contain)
                          : const Center(child: Icon(Icons.draw_outlined, size: 36)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Invoice Signature', style: TextStyle(fontWeight: FontWeight.bold)),
                          const Text('Shown at the bottom-right of invoice PDFs.'),
                          Wrap(
                            spacing: 8,
                            children: [
                              TextButton.icon(
                                onPressed: _selectSignature,
                                icon: const Icon(Icons.upload_file),
                                label: const Text('Choose Signature'),
                              ),
                              if (_signaturePath != null && _signaturePath!.isNotEmpty)
                                TextButton.icon(
                                  onPressed: () => setState(() => _signaturePath = ''),
                                  icon: const Icon(Icons.clear),
                                  label: const Text('Remove'),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _businessName,
                decoration: const InputDecoration(labelText: 'Business Name'),
                textCapitalization: TextCapitalization.words,
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Enter your business name.'
                    : null,
              ),
              TextFormField(
                controller: _contactPerson,
                decoration: const InputDecoration(
                  labelText: 'Contact Person (optional)',
                ),
              ),
              TextFormField(
                controller: _phone,
                decoration: const InputDecoration(
                  labelText: 'Phone (optional)',
                ),
                keyboardType: TextInputType.phone,
              ),
              TextFormField(
                controller: _email,
                decoration: const InputDecoration(
                  labelText: 'Email (optional)',
                ),
                keyboardType: TextInputType.emailAddress,
                validator: (value) {
                  final email = value?.trim() ?? '';
                  return email.isNotEmpty && !email.contains('@')
                      ? 'Enter a valid email address.'
                      : null;
                },
              ),
              TextFormField(
                controller: _address,
                decoration: const InputDecoration(
                  labelText: 'Address (optional)',
                ),
                maxLines: 2,
              ),
              TextFormField(
                controller: _taxNumber,
                decoration: const InputDecoration(
                  labelText: 'Tax / Registration Number (optional)',
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Invoice Defaults',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _invoicePrefix,
                decoration: const InputDecoration(
                  labelText: 'Invoice Prefix',
                  hintText: 'INV',
                ),
                textCapitalization: TextCapitalization.characters,
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Enter an invoice prefix.'
                    : null,
              ),
              TextFormField(
                controller: _paymentDays,
                decoration: const InputDecoration(
                  labelText: 'Default Payment Days',
                  helperText: '0 leaves the due date empty',
                ),
                keyboardType: TextInputType.number,
                validator: (value) {
                  final days = int.tryParse(value?.trim() ?? '');
                  return days == null || days < 0
                      ? 'Enter zero or a positive whole number.'
                      : null;
                },
              ),
              TextFormField(
                controller: _invoiceFooter,
                decoration: const InputDecoration(
                  labelText: 'Invoice Footer (optional)',
                  hintText: 'Thank you for your business.',
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 24),
              Text(
                'Invoice Design',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              const Text('Accent Color'),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  for (final option in const <(String, Color)>[
                    ('#1F5AA6', Colors.blue),
                    ('#00796B', Colors.teal),
                    ('#6A1B9A', Colors.purple),
                    ('#C62828', Colors.red),
                    ('#37474F', Colors.blueGrey),
                  ])
                    ChoiceChip(
                      label: Text(option.$1),
                      selected: _accentColor == option.$1,
                      selectedColor: option.$2.withOpacity(0.25),
                      avatar: CircleAvatar(
                        backgroundColor: option.$2,
                        radius: 10,
                      ),
                      onSelected: (_) =>
                          setState(() => _accentColor = option.$1),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              AdaptiveDropdownButtonFormField<String>(
                value: _invoiceTemplate,
                decoration: const InputDecoration(labelText: 'Invoice Design'),
                items: const [
                  DropdownMenuItem(
                    value: 'classic',
                    child: Text('Classic - simple business layout'),
                  ),
                  DropdownMenuItem(
                    value: 'modern',
                    child: Text('Modern - colored header accent'),
                  ),
                  DropdownMenuItem(
                    value: 'compact',
                    child: Text('Compact - concise receipt-style layout'),
                  ),
                  DropdownMenuItem(
                    value: 'detailed',
                    child: Text(
                      'Detailed - includes extra terms and business details',
                    ),
                  ),
                ],
                onChanged: (value) =>
                    setState(() => _invoiceTemplate = value ?? 'classic'),
              ),
              const SizedBox(height: 24),
              Text(
                'Default Terms & Payment',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _defaultInvoiceTerms,
                decoration: const InputDecoration(
                  labelText: 'Default Invoice Terms (optional)',
                ),
                maxLines: 3,
              ),
              TextFormField(
                controller: _paymentInstructions,
                decoration: const InputDecoration(
                  labelText: 'Payment Instructions / Bank Details (optional)',
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 24),
              GlassActionButton(
                onPressed: _saving ? null : _save,
                icon: Icons.save,
                color: Colors.blue,
                expand: true,
                label: Text(_saving ? 'Saving...' : 'Save Profile'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.embedded) return _buildContent(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Company Profile')),
      body: _buildContent(context),
    );
  }
}
