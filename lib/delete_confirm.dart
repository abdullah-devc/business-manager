import 'package:flutter/material.dart';
import 'delete_protection_service.dart';

Future<bool> confirmDeleteWithPassword(BuildContext context, {required String title, required String warning}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Text(warning),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Continue')),
      ],
    ),
  );
  if (confirmed != true || !context.mounted) return false;

  if (!await DeleteProtectionService.instance.hasPassword()) {
    if (!context.mounted) return false;
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Password Not Set'),
        content: const Text('Set a separate delete password in Settings before deleting anything.'),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK'))],
      ),
    );
    return false;
  }

  final controller = TextEditingController();
  final passwordOk = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Enter Delete Password'),
      content: TextField(controller: controller, autofocus: true, obscureText: true, onSubmitted: (_) async {
        final ok = await DeleteProtectionService.instance.verifyPassword(controller.text);
        if (context.mounted) Navigator.pop(context, ok);
      }, decoration: const InputDecoration(labelText: 'Delete password', border: OutlineInputBorder())),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
        FilledButton(onPressed: () async {
          final ok = await DeleteProtectionService.instance.verifyPassword(controller.text);
          if (context.mounted) Navigator.pop(context, ok);
        }, child: const Text('Verify')),
      ],
    ),
  );
  controller.dispose();
  if (passwordOk != true && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Incorrect delete password. Nothing was deleted.')));
  }
  return passwordOk == true;
}
