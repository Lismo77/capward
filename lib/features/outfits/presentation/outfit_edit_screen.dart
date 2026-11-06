import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/palette_bar.dart';
import '../../wardrobe/data/item_repository.dart';
import '../../wardrobe/domain/item.dart';
import '../../wardrobe/presentation/widgets/item_thumbnail.dart';
import '../data/outfit_repository.dart';
import '../domain/outfit.dart';
import 'widgets/outfit_collage.dart';

/// Manual outfit builder: pick pieces slot by slot and watch the preview and
/// palette update.
class OutfitEditScreen extends ConsumerStatefulWidget {
  const OutfitEditScreen({super.key, this.outfitId});

  final int? outfitId;

  @override
  ConsumerState<OutfitEditScreen> createState() => _OutfitEditScreenState();
}

class _OutfitEditScreenState extends ConsumerState<OutfitEditScreen> {
  final _name = TextEditingController();
  final _occasion = TextEditingController();
  Set<int> _selected = {};
  OutfitSource _source = OutfitSource.user;
  String? _notes;
  bool _loading = true;
  bool _saving = false;

  bool get _isNew => widget.outfitId == null;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (!_isNew) {
      final repo = await ref.read(outfitRepositoryProvider.future);
      final outfit = await repo.byId(widget.outfitId!);
      if (outfit != null) {
        _name.text = outfit.name;
        _occasion.text = outfit.occasion ?? '';
        _selected = outfit.itemIds.toSet();
        _source = outfit.source;
        _notes = outfit.notes;
      }
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  void dispose() {
    _name.dispose();
    _occasion.dispose();
    super.dispose();
  }

  Future<void> _save(Map<int, Item> byId) async {
    final ordered =
        orderForDisplay(_selected.map((id) => byId[id]).whereType<Item>());
    if (ordered.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Pick at least one piece')));
      return;
    }
    setState(() => _saving = true);
    final name = _name.text.trim();
    final occasion = _occasion.text.trim();
    final repo = await ref.read(outfitRepositoryProvider.future);
    await repo.save(Outfit(
      id: widget.outfitId,
      name: name.isEmpty ? defaultOutfitName(ordered) : name,
      occasion: occasion.isEmpty ? null : occasion,
      notes: _notes,
      source: _source,
      itemIds: [for (final i in ordered) i.id!],
    ));
    ref.invalidate(outfitsProvider);
    if (mounted) context.pop();
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete this outfit?'),
        content: const Text('The pieces stay in your wardrobe.'),
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
    final repo = await ref.read(outfitRepositoryProvider.future);
    await repo.delete(widget.outfitId!);
    ref.invalidate(outfitsProvider);
    if (mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final all = ref.watch(itemsProvider).valueOrNull;
    if (_loading || all == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final byId = {for (final i in all) i.id!: i};
    // Only items in rotation, plus anything already in this outfit.
    final candidates = all
        .where((i) => i.status == ItemStatus.active || _selected.contains(i.id))
        .toList();
    final bySlot = <OutfitSlot, List<Item>>{};
    for (final item in candidates) {
      bySlot
          .putIfAbsent(OutfitSlot.forCategory(item.category), () => [])
          .add(item);
    }
    final selectedItems =
        orderForDisplay(_selected.map((id) => byId[id]).whereType<Item>());

    return Scaffold(
      appBar: AppBar(
        title: Text(_isNew ? 'New outfit' : 'Edit outfit'),
        actions: [
          if (!_isNew)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: 'Delete',
              onPressed: _delete,
            ),
          TextButton(
            onPressed: _saving ? null : () => _save(byId),
            child: const Text('Save'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          _Preview(items: selectedItems),
          const SizedBox(height: 16),
          TextField(
            controller: _name,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Name',
              hintText: 'Leave blank to name it after its pieces',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _occasion,
            decoration: const InputDecoration(
              labelText: 'Occasion (optional)',
              hintText: 'office, weekend, dinner...',
            ),
          ),
          if (candidates.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 24),
              child: Text('Add some items to your wardrobe first.'),
            ),
          for (final slot in OutfitSlot.values)
            if (bySlot[slot]?.isNotEmpty ?? false)
              _SlotPicker(
                slot: slot,
                items: bySlot[slot]!,
                selected: _selected,
                onTap: (item) => setState(
                    () => _selected = toggleOutfitItem(_selected, item, byId)),
              ),
        ],
      ),
    );
  }
}

class _Preview extends StatelessWidget {
  const _Preview({required this.items});

  final List<Item> items;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
              height: 220, child: OutfitCollage(items: items, iconSize: 40)),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                PaletteBar(colors: outfitPalette(items), height: 14),
                const SizedBox(height: 8),
                Text(
                  items.isEmpty
                      ? 'Tap pieces below to build an outfit'
                      : '${items.length} ${items.length == 1 ? 'piece' : 'pieces'}',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SlotPicker extends StatelessWidget {
  const _SlotPicker({
    required this.slot,
    required this.items,
    required this.selected,
    required this.onTap,
  });

  final OutfitSlot slot;
  final List<Item> items;
  final Set<int> selected;
  final ValueChanged<Item> onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 20, bottom: 8),
          child: Text.rich(TextSpan(children: [
            TextSpan(text: slot.label, style: theme.textTheme.titleSmall),
            TextSpan(
              text: slot.multi ? '  ·  pick any' : '  ·  pick one',
              style: theme.textTheme.bodySmall,
            ),
          ])),
        ),
        SizedBox(
          height: 136,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: items.length,
            separatorBuilder: (context, i) => const SizedBox(width: 8),
            itemBuilder: (context, i) => _PickTile(
              item: items[i],
              selected: selected.contains(items[i].id),
              onTap: () => onTap(items[i]),
            ),
          ),
        ),
      ],
    );
  }
}

class _PickTile extends StatelessWidget {
  const _PickTile({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final Item item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final radius = BorderRadius.circular(10);
    return SizedBox(
      width: 96,
      child: InkWell(
        borderRadius: radius,
        onTap: onTap,
        child: Column(
          children: [
            SizedBox(
              width: 96,
              height: 96,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ClipRRect(
                    borderRadius: radius,
                    child: ItemThumbnail(item: item, iconSize: 32),
                  ),
                  if (selected) ...[
                    DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: radius,
                        border: Border.all(color: scheme.primary, width: 3),
                      ),
                    ),
                    Positioned(
                      top: 4,
                      right: 4,
                      child: CircleAvatar(
                        radius: 11,
                        backgroundColor: scheme.primary,
                        child: Icon(Icons.check,
                            size: 14, color: scheme.onPrimary),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 4),
            Text(
              item.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}
