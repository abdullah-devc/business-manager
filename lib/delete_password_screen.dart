import 'package:flutter/material.dart';
import 'delete_protection_service.dart';

class DeletePasswordScreen extends StatefulWidget {
  const DeletePasswordScreen({super.key});
  @override
  State<DeletePasswordScreen> createState() => _DeletePasswordScreenState();
}

class _DeletePasswordScreenState extends State<DeletePasswordScreen> {
  final _current = TextEditingController();
  final _next = TextEditingController();
  final _confirm = TextEditingController();
  bool _configured = false;
  bool _loading = true;

  @override
  void initState() { super.initState(); _load(); }
  Future<void> _load() async {
    final configured = await DeleteProtectionService.instance.hasPassword();
    if (mounted) setState(() { _configured = configured; _loading = false; });
  }

  Future<void> _save() async {
    if (_next.text.length < 4) { _msg('Password must be at least 4 characters.'); return; }
    if (_next.text != _confirm.text) { _msg('New passwords do not match.'); return; }
    if (_configured) {
      if (!await DeleteProtectionService.instance.changePassword(_current.text, _next.text)) {
        _msg('Current delete password is incorrect.'); return;
      }
    } else {
      await DeleteProtectionService.instance.setPassword(_next.text);
    }
    if (mounted) { _msg('Delete password saved.'); Navigator.pop(context, true); }
  }

  void _msg(String text) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    return Scaffold(
      appBar: AppBar(title: Text(_configured ? 'Change Delete Password' : 'Set Delete Password')),
      body: ListView(padding: const EdgeInsets.all(20), children: [
        const Icon(Icons.delete_forever_outlined, size: 56),
        const SizedBox(height: 12),
        Text(_configured ? 'Change the separate password required before deleting data.' : 'Create a separate password that will be required before any delete action.', style: Theme.of(context).textTheme.bodyLarge),
        const SizedBox(height: 24),
        if (_configured) TextField(controller: _current, obscureText: true, decoration: const InputDecoration(labelText: 'Current delete password', border: OutlineInputBorder())),
        if (_configured) const SizedBox(height: 12),
        TextField(controller: _next, obscureText: true, decoration: const InputDecoration(labelText: 'New delete password', border: OutlineInputBorder())),
        const SizedBox(height: 12),
        TextField(controller: _confirm, obscureText: true, decoration: const InputDecoration(labelText: 'Confirm delete password', border: OutlineInputBorder())),
        const SizedBox(height: 20),
        FilledButton.icon(onPressed: _save, icon: const Icon(Icons.save_outlined), label: Text(_configured ? 'Change Password' : 'Set Delete Password')),
      ]),
    );
  }

  @override
  void dispose() { _current.dispose(); _next.dispose(); _confirm.dispose(); super.dispose(); }
}
