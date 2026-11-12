import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/palette_bar.dart';
import '../../wardrobe/data/item_repository.dart';
import '../../wardrobe/domain/item.dart';
import '../../wear_log/data/wear_log_repository.dart';
import '../../wear_log/domain/wear_entry.dart';
import '../data/outfit_repository.dart';
import '../data/uniform_providers.dart';
import '../domain/outfit.dart';
import 'widgets/outfit_collage.dart';

class OutfitsScreen extends ConsumerWidget {
  const OutfitsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final outfits = ref.watch(outfitsProvider);
    final items = ref.watch(itemsProvider).valueOrNull ?? const <Item>[];
    final byId = {for (final i in items) i.id!: i};
    final wears = ref.watch(wearLogProvider).valueOrNull ?? const [];
    final wearingId = ref.watch(currentWearProvider)?.outfitId;

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
              return _OutfitCard(
                outfit: outfit,
                byId: byId,
                timesWorn: outfitWearCount(wears, outfit.id!),
                wearing: outfit.id == wearingId,
              );
            },
          );
        },
      ),
    );
  }
}

class _OutfitCard extends ConsumerWidget {
  const _OutfitCard({
    required this.outfit,
    required this.byId,
    required this.timesWorn,
    required this.wearing,
  });

  final Outfit outfit;
  final Map<int, Item> byId;
  final int timesWorn;

  /// The outfit being worn today: outlined and badged.
  final bool wearing;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    // A uniform shows today's pick.
    final items = orderForDisplay(ref
        .watch(todaysPiecesProvider(outfit.id!))
        .map((id) => byId[id])
        .whereType<Item>());
    final details = [
      if (outfit.isUniform)
        'uniform'
      else
        '${items.length} ${items.length == 1 ? 'piece' : 'pieces'}',
      if ((outfit.occasion ?? '').isNotEmpty) outfit.occasion!,
      if (timesWorn > 0) 'worn $timesWorn×',
    ].join(' · ');

    final scheme = theme.colorScheme;
    return Card(
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: wearing
            ? BorderSide(color: scheme.primary, width: 3)
            : BorderSide.none,
      ),
      child: InkWell(
        onTap: () => context.push('/outfits/${outfit.id}'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  OutfitCollage(items: items),
                  if (outfit.isUniform)
                    Positioned(
                      top: 6,
                      right: 6,
                      child: Tooltip(
                        message: 'Uniform: shows today\'s pick',
                        child: CircleAvatar(
                          radius: 13,
                          backgroundColor: scheme.secondaryContainer,
                          child: Icon(Icons.swap_horiz,
                              size: 16, color: scheme.onSecondaryContainer),
                        ),
                      ),
                    ),
                  if (wearing)
                    Positioned(
                      top: 6,
                      left: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: scheme.primary,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.check,
                                size: 14, color: scheme.onPrimary),
                            const SizedBox(width: 4),
                            Text('Wearing',
                                style: theme.textTheme.labelSmall
                                    ?.copyWith(color: scheme.onPrimary)),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
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
