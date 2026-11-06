import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/palette_bar.dart';
import '../../outfits/data/outfit_repository.dart';
import '../data/item_repository.dart';
import '../domain/item.dart';
import 'widgets/item_thumbnail.dart';

class WardrobeScreen extends ConsumerStatefulWidget {
  const WardrobeScreen({super.key});

  @override
  ConsumerState<WardrobeScreen> createState() => _WardrobeScreenState();
}

class _WardrobeScreenState extends ConsumerState<WardrobeScreen> {
  ItemCategory? _filter;

  /// Ids of selected items. Selection mode is on while this is non-empty.
  Set<int> _selected = {};

  bool get _selecting => _selected.isNotEmpty;

  void _toggle(Item item) {
    HapticFeedback.selectionClick();
    setState(() {
      final next = {..._selected};
      if (!next.remove(item.id!)) next.add(item.id!);
      _selected = next;
    });
  }

  void _clearSelection() => setState(() => _selected = {});

  void _setFilter(ItemCategory? filter, List<Item> all) {
    setState(() {
      _filter = filter;
      // Never keep hidden items selected - bulk actions should only touch
      // what the user can see.
      final visible = _visible(all).map((i) => i.id).toSet();
      _selected = _selected.where(visible.contains).toSet();
    });
  }

  List<Item> _visible(List<Item> all) =>
      _filter == null ? all : all.where((i) => i.category == _filter).toList();

  Future<void> _refresh() async {
    ref.invalidate(itemsProvider);
    ref.invalidate(outfitsProvider);
  }

  Future<void> _setStatus(ItemStatus status) async {
    final count = _selected.length;
    final repo = await ref.read(itemRepositoryProvider.future);
    await repo.setStatus(_selected, status);
    await _refresh();
    if (!mounted) return;
    _clearSelection();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('$count ${count == 1 ? 'item' : 'items'} '
            'set to ${status.label.toLowerCase()}')));
  }

  Future<void> _delete() async {
    final count = _selected.length;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete $count ${count == 1 ? 'item' : 'items'}?'),
        content: const Text('They are also removed from outfits and '
            'capsules. To keep their history, set them to Retired instead.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete')),
        ],
      ),
    );
    if (confirmed != true) return;
    final repo = await ref.read(itemRepositoryProvider.future);
    await repo.deleteMany(_selected);
    await _refresh();
    if (mounted) _clearSelection();
  }

  void _makeOutfit() {
    final ids = _selected.toList();
    _clearSelection();
    context.push('/outfits/new', extra: ids);
  }

  @override
  Widget build(BuildContext context) {
    final items = ref.watch(itemsProvider);
    final all = items.valueOrNull ?? const <Item>[];

    return PopScope(
      // Back leaves selection mode instead of leaving the screen.
      canPop: !_selecting,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _clearSelection();
      },
      child: Scaffold(
        appBar: _selecting
            ? _selectionBar(all)
            : AppBar(title: const Text('Wardrobe')),
        floatingActionButton: _selecting
            ? null
            : FloatingActionButton.extended(
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
            final shown = _visible(all);
            return Column(
              children: [
                SizedBox(
                  height: 56,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    children: [
                      _chip('All (${all.length})', _filter == null,
                          () => _setFilter(null, all)),
                      for (final c in ItemCategory.values)
                        if (all.any((i) => i.category == c))
                          _chip(
                              c.label, _filter == c, () => _setFilter(c, all)),
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
                    itemBuilder: (context, i) {
                      final item = shown[i];
                      return _ItemCard(
                        item: item,
                        selected: _selected.contains(item.id),
                        onTap: _selecting
                            ? () => _toggle(item)
                            : () => context.push('/wardrobe/${item.id}'),
                        onLongPress: () => _toggle(item),
                      );
                    },
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  PreferredSizeWidget _selectionBar(List<Item> all) {
    final visibleIds = {for (final i in _visible(all)) i.id!};
    final allSelected = visibleIds.every(_selected.contains);
    return AppBar(
      leading: IconButton(
        icon: const Icon(Icons.close),
        tooltip: 'Cancel selection',
        onPressed: _clearSelection,
      ),
      title: Text('${_selected.length} selected'),
      actions: [
        IconButton(
          icon: Icon(allSelected ? Icons.deselect : Icons.select_all),
          tooltip: allSelected ? 'Deselect all' : 'Select all',
          onPressed: () => setState(() =>
              _selected = allSelected ? {} : {..._selected, ...visibleIds}),
        ),
        IconButton(
          icon: const Icon(Icons.style_outlined),
          tooltip: 'Make an outfit',
          onPressed: _makeOutfit,
        ),
        PopupMenuButton<ItemStatus>(
          icon: const Icon(Icons.label_outline),
          tooltip: 'Set status',
          onSelected: _setStatus,
          itemBuilder: (context) => [
            for (final s in ItemStatus.values)
              PopupMenuItem(value: s, child: Text('Set to ${s.label}')),
          ],
        ),
        IconButton(
          icon: const Icon(Icons.delete_outline),
          tooltip: 'Delete',
          onPressed: _delete,
        ),
      ],
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
  const _ItemCard({
    required this.item,
    required this.selected,
    required this.onTap,
    required this.onLongPress,
  });

  final Item item;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Card(
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: selected
            ? BorderSide(color: scheme.primary, width: 3)
            : BorderSide.none,
      ),
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ItemThumbnail(item: item),
                  if (selected)
                    Positioned(
                      top: 6,
                      right: 6,
                      child: CircleAvatar(
                        radius: 12,
                        backgroundColor: scheme.primary,
                        child: Icon(Icons.check,
                            size: 16, color: scheme.onPrimary),
                      ),
                    ),
                ],
              ),
            ),
            if (item.colors.isNotEmpty)
              PaletteBar(
                colors: [for (final c in item.colors) c.value],
                height: 6,
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
