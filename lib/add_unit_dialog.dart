import 'package:flutter/material.dart';
import 'database_helper.dart';
import 'widgets/glass.dart';

/// Shows a dialog to add a new unit. Returns the new unit's name if it was
/// added successfully, or null if the user cancelled or the name was invalid.
Future<String?> showAddUnitDialog(BuildContext context) async {
  final controller = TextEditingController();

  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => PinnedDarkText(child: AlertDialog(
      title: const Text('Add New Unit'),
      content: TextField(
        controller: controller,
        decoration: const InputDecoration(labelText: 'Unit name (e.g. tons)'),
        autofocus: true,
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
        TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Add')),
      ],
    )),
  );

  if (confirmed != true) return null;

  final name = controller.text.trim();
  if (name.isEmpty) return null;

  try {
    await DatabaseHelper.instance.insertUnit(name);
    return name;
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('"$name" already exists or is invalid.')),
      );
    }
    return null;
  }
}
