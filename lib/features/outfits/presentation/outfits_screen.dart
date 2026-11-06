import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/palette_bar.dart';
import '../../wardrobe/data/item_repository.dart';
import '../../wardrobe/domain/item.dart';
import '../data/outfit_repository.dart';
import '../domain/outfit.dart';
import 'widgets/outfit_collage.dart';

class OutfitsScreen extends ConsumerWidget {
  const OutfitsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final outfits = ref.watch(outfitsProvider);
    final items = ref.watch(itemsProvider).valueOrNull ?? const <Item>[];
    final byId = {for (final i in items) i.id!: i};

    return Scaffold(
      appBar: AppBar(title: const Text('Outfits')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/outfits/new'),
        icon: const Icon(Icons.add),
        label: const Text('New outfit'),
      ),
      body: outfits.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Could not load outfits: $e')),
        data: (list) {
          if (list.isEmpty) {
            return const EmptyState(
              icon: Icons.style_outlined,
              title: 'No outfits yet',
              message: 'Combine pieces you already own into outfits you '
                  'like, so getting dressed is one tap.',
            );
          }
          return GridView.builder(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 96),
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 220,
              childAspectRatio: 0.72,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
            ),
            itemCount: list.length,
            itemBuilder: (context, i) {
              final outfit = list[i];
              final outfitItems = orderForDisplay(
                  outfit.itemIds.map((id) => byId[id]).whereType<Item>());
              return _OutfitCard(outfit: outfit, items: outfitItems);
            },
          );
        },
      ),
    );
  }
}

class _OutfitCard extends StatelessWidget {
  const _OutfitCard({required this.outfit, required this.items});

  final Outfit outfit;
  final List<Item> items;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final details = [
      '${items.length} ${items.length == 1 ? 'piece' : 'pieces'}',
      if ((outfit.occasion ?? '').isNotEmpty) outfit.occasion!,
    ].join(' · ');

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push('/outfits/${outfit.id}'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(child: OutfitCollage(items: items)),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  PaletteBar(colors: outfitPalette(items), height: 8),
                  const SizedBox(height: 6),
                  Text(outfit.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall),
                  Text(details,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
