import 'package:flutter/material.dart';
import 'delete_confirm.dart';
import 'database_helper.dart';
import 'add_unit_dialog.dart';
import 'widgets/glass.dart';

class UnitsScreen extends StatefulWidget {
  final bool embedded;

  const UnitsScreen({super.key, this.embedded = false});

  @override
  State<UnitsScreen> createState() => _UnitsScreenState();
}

class _UnitsScreenState extends State<UnitsScreen> {
  List<Map<String, dynamic>> _units = [];

  @override
  void initState() {
    super.initState();
    _loadUnits();
  }

  Future<void> _loadUnits() async {
    final data = await DatabaseHelper.instance.getAllUnits();
    setState(() => _units = data);
  }

  Future<void> _addUnit() async {
    final name = await showAddUnitDialog(context);
    if (name != null) {
      _loadUnits();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: widget.embedded ? null : AppBar(title: const Text('Manage Units')),
      floatingActionButton: Padding(
        // Shift left of the main tab scaffold's round "Quick Add" FAB
        // (same bottom-right corner) so the two buttons don't overlap.
        padding: EdgeInsets.only(right: widget.embedded ? 72.0 : 0.0),
        child: FloatingActionButton.extended(
          onPressed: _addUnit,
          icon: const Icon(Icons.add),
          label: const Text('Add Unit'),
        ),
      ),
      body: AdaptiveBackgroundText(
        child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView.builder(
          itemCount: _units.length,
          itemBuilder: (context, index) {
            final unit = _units[index];
            return ListTile(
              title: Text(unit['name']),
              trailing: IconButton(
                icon: const Icon(Icons.delete, color: Colors.red),
                onPressed: () async {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (context) => PinnedDarkText(child: AlertDialog(
                      title: const Text('Delete Unit?'),
                      content: Text('Delete "${unit['name']}"? Materials already using it will keep the old value.'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('Cancel'),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(context, true),
                          child: const Text('Delete'),
                        ),
                      ],
                    )),
                  );
                  if (confirm == true) {
                    final allowed = await confirmDeleteWithPassword(context, title: 'Confirm Delete Unit', warning: 'This unit will be permanently deleted. This cannot be undone.');
                    if (!allowed) return;
                    await DatabaseHelper.instance.deleteUnit(unit['id']);
                    _loadUnits();
                  }
                },
              ),
            );
          },
        ),
        ),
      ),
    );
  }
}
