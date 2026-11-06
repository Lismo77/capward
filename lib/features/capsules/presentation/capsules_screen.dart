import 'package:flutter/material.dart';

import '../../../core/widgets/empty_state.dart';

// Planned for v0.2: named collections of items, e.g. "Autumn 2026 - 33
// pieces". The tables (capsules, capsule_items) already exist.
class CapsulesScreen extends StatelessWidget {
  const CapsulesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Capsules')),
      body: const EmptyState(
        icon: Icons.inventory_2_outlined,
        title: 'Capsules are coming in v0.2',
        message: 'Group items into a capsule for a season or a trip, with a '
            'target size to keep it focused.',
      ),
    );
  }
}
