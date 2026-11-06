import 'package:flutter/material.dart';

import '../../../core/widgets/empty_state.dart';

// Planned for v0.2: build outfits from items and log what you wear.
// The tables (outfits, outfit_items, wear_log, wear_log_items) already exist.
class OutfitsScreen extends StatelessWidget {
  const OutfitsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Outfits')),
      body: const EmptyState(
        icon: Icons.style_outlined,
        title: 'Outfits are coming in v0.2',
        message: 'Combine items into outfits and log what you wear, to see '
            'cost-per-wear and which pieces never leave the closet.',
      ),
    );
  }
}
