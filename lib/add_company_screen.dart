import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'database_helper.dart';
import 'widgets/glass.dart';

class AddCompanyScreen extends StatefulWidget {
  const AddCompanyScreen({super.key});

  @override
  State<AddCompanyScreen> createState() => _AddCompanyScreenState();
}

class _AddCompanyScreenState extends State<AddCompanyScreen> {
  final _nameController = TextEditingController();
  final _contactController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  String? _phoneErrorText;

  String? _validatePhone(String value) {
    if (value.isEmpty) return null;
    return RegExp(r'^[0-9+\-() ]*$').hasMatch(value)
        ? null
        : 'Phone can only contain digits, +, -, (), and spaces.';
  }

  Future<void> _save() async {
    final phone = _phoneController.text.trim();
    final phoneError = _validatePhone(phone);
    if (phoneError != null) {
      setState(() {
        _phoneErrorText = phoneError;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(phoneError)),
      );
      return;
    }

    if (_phoneErrorText != null) {
      setState(() {
        _phoneErrorText = null;
      });
    }

    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a company name.')),
      );
      return;
    }

    final companyId = await DatabaseHelper.instance.insertCompany({
      'name': _nameController.text.trim(),
      'contact_person': _contactController.text.trim(),
      'phone': _phoneController.text.trim(),
      'address': _addressController.text.trim(),
      'created_at': DateTime.now().toIso8601String(),
    });

    if (context.mounted) Navigator.pop(context, companyId);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _contactController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add Company')),
      body: AdaptiveBackgroundText(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(controller: _nameController, decoration: const InputDecoration(labelText: 'Company Name')),
            TextField(controller: _contactController, decoration: const InputDecoration(labelText: 'Contact Person')),
            TextField(
              controller: _phoneController,
              decoration: InputDecoration(
                labelText: 'Phone',
                errorText: _phoneErrorText,
              ),
              keyboardType: TextInputType.phone,
              onChanged: (value) {
                setState(() {
                  _phoneErrorText = _validatePhone(value);
                });
              },
            ),
            TextField(controller: _addressController, decoration: const InputDecoration(labelText: 'Address')),
            const SizedBox(height: 16),
            GlassActionButton(onPressed: _save, icon: Icons.save, color: Colors.blue, expand: true, label: const Text('Save Company')),
          ],
        ),
      ),
      ),
    );
  }
}
