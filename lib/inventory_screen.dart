import 'package:flutter/material.dart';

import 'materials_screen.dart';
import 'products_screen.dart';
import 'units_screen.dart';
import 'widgets/glass.dart';

/// Combines Materials and Units under one "Inventory" tab via a small
/// segmented switcher, so both fit in the new named-section nav without
/// needing their own top-level tabs.
class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  int _segment = 0;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
          child: AdaptiveBackgroundText(
            child: SegmentedButton<int>(
              segments: const [
                ButtonSegment(value: 0, label: Text('Materials'), icon: Icon(Icons.inventory_2)),
                ButtonSegment(value: 1, label: Text('Products'), icon: Icon(Icons.shopping_bag_outlined)),
                ButtonSegment(value: 2, label: Text('Units'), icon: Icon(Icons.straighten)),
              ],
              selected: {_segment},
              onSelectionChanged: (s) => setState(() => _segment = s.first),
            ),
          ),
        ),
        Expanded(
          child: _segment == 0
              ? const MaterialsScreen(embedded: true)
              : _segment == 1
                  ? const ProductsScreen(embedded: true)
                  : const UnitsScreen(embedded: true),
        ),
      ],
    );
  }
}
