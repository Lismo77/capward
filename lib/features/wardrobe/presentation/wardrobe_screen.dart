import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/empty_state.dart';
import '../data/item_repository.dart';
import '../domain/item.dart';

class WardrobeScreen extends ConsumerStatefulWidget {
  const WardrobeScreen({super.key});

  @override
  ConsumerState<WardrobeScreen> createState() => _WardrobeScreenState();
}

class _WardrobeScreenState extends ConsumerState<WardrobeScreen> {
  ItemCategory? _filter;

  @override
  Widget build(BuildContext context) {
    final items = ref.watch(itemsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Wardrobe')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/wardrobe/new'),
        icon: const Icon(Icons.add),
        label: const Text('Add item'),
      ),
      body: items.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Could not load wardrobe: $e')),
        data: (all) {
          if (all.isEmpty) {
            return const EmptyState(
              icon: Icons.checkroom_outlined,
              title: 'Your wardrobe is empty',
              message: 'Add the pieces you own. Start with what you wear '
                  'most - a capsule is built from favourites.',
            );
          }
          final shown = _filter == null
              ? all
              : all.where((i) => i.category == _filter).toList();
          return Column(
            children: [
              SizedBox(
                height: 56,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  children: [
                    _chip('All (${all.length})', _filter == null,
                        () => setState(() => _filter = null)),
                    for (final c in ItemCategory.values)
                      if (all.any((i) => i.category == c))
                        _chip(c.label, _filter == c,
                            () => setState(() => _filter = c)),
                  ],
                ),
              ),
              Expanded(
                child: GridView.builder(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 96),
                  gridDelegate:
                      const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 200,
                    childAspectRatio: 0.75,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                  ),
                  itemCount: shown.length,
                  itemBuilder: (context, i) => _ItemCard(item: shown[i]),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _chip(String label, bool selected, VoidCallback onTap) => Padding(
        padding: const EdgeInsets.only(right: 8),
        child: ChoiceChip(
          label: Text(label),
          selected: selected,
          onSelected: (_) => onTap(),
        ),
      );
}

class _ItemCard extends StatelessWidget {
  const _ItemCard({required this.item});

  final Item item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push('/wardrobe/${item.id}'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: item.photoPath == null
                  ? const _PhotoPlaceholder()
                  : Image.file(
                      File(item.photoPath!),
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) =>
                          const _PhotoPlaceholder(),
                    ),
            ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall),
                  Text(
                    item.status == ItemStatus.active
                        ? item.category.label
                        : '${item.category.label} · ${item.status.label}',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PhotoPlaceholder extends StatelessWidget {
  const _PhotoPlaceholder();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ColoredBox(
      color: scheme.surfaceContainerHighest,
      child: Icon(Icons.checkroom, size: 48, color: scheme.outline),
    );
  }
}
