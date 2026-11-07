import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/format.dart';
import '../../../core/settings/season_settings.dart';
import '../../../core/widgets/palette_bar.dart';
import '../../wardrobe/data/item_repository.dart';
import '../../wardrobe/domain/item.dart';
import '../../wardrobe/presentation/widgets/item_thumbnail.dart';
import '../../wear_log/data/wear_log_repository.dart';
import '../../wear_log/domain/wear_entry.dart';
import '../../wear_log/presentation/log_wear.dart';
import '../data/outfit_repository.dart';
import '../data/uniform_providers.dart';
import '../domain/outfit.dart';
import '../domain/uniform.dart';
import 'widgets/outfit_collage.dart';
import 'widgets/outfit_pieces.dart';

/// Manual outfit builder: pick pieces slot by slot and watch the preview and
/// palette update. Adding options to a piece makes the outfit a uniform.
class OutfitEditScreen extends ConsumerStatefulWidget {
  const OutfitEditScreen({
    super.key,
    this.outfitId,
    this.initialItemIds = const [],
  });

  final int? outfitId;

  /// Pre-selected pieces for a new outfit (e.g. from wardrobe multi-select).
  final List<int> initialItemIds;

  @override
  ConsumerState<OutfitEditScreen> createState() => _OutfitEditScreenState();
}

class _OutfitEditScreenState extends ConsumerState<OutfitEditScreen> {
  final _name = TextEditingController();
  final _occasion = TextEditingController();
  Set<int> _selected = {};

  /// Item id to option group (see [Outfit.optionGroups]).
  Map<int, int> _groups = {};

  /// Pieces as last saved. Wears log these, not unsaved edits.
  List<int> _savedItemIds = const [];
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
    if (_isNew) {
      _selected = widget.initialItemIds.toSet();
    } else {
      final repo = await ref.read(outfitRepositoryProvider.future);
      final outfit = await repo.byId(widget.outfitId!);
      if (outfit != null) {
        _name.text = outfit.name;
        _occasion.text = outfit.occasion ?? '';
        _selected = outfit.itemIds.toSet();
        _groups = {...outfit.optionGroups};
        _savedItemIds = outfit.itemIds;
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
      optionGroups: normalizeOptionGroups(_selected, _groups),
    ));
    ref.invalidate(outfitsProvider);
    if (mounted) context.pop();
  }

  void _toggle(Item item, Map<int, Item> byId) => setState(() {
        _selected = toggleOutfitItem(_selected, item, byId);
        _groups = normalizeOptionGroups(_selected, _groups);
      });

  /// Opens the options sheet for a fixed piece ([ids] has one id) or an
  /// option group, and applies the result.
  Future<void> _editOptions(List<int> ids, List<Item> candidates) async {
    final all = ref.read(itemsProvider).valueOrNull ?? const <Item>[];
    final first = all.where((i) => i.id == ids.first).firstOrNull;
    if (first == null) return;
    final slot = OutfitSlot.forCategory(first.category);
    final others = _selected.difference(ids.toSet());
    final chosen = await showOptionsSheet(
      context,
      slotLabel: slot.label,
      candidates: [
        for (final item in candidates)
          if (OutfitSlot.forCategory(item.category) == slot &&
              !others.contains(item.id))
            item,
      ],
      initial: ids.toSet(),
    );
    if (chosen == null || !mounted) return;
    setState(() {
      final group = ids.map((id) => _groups[id]).whereType<int>().firstOrNull ??
          _groups.values.fold(0, (a, b) => a > b ? a : b) + 1;
      final groups = {..._groups}..removeWhere((id, _) => ids.contains(id));
      if (chosen.length > 1) {
        for (final id in chosen) {
          groups[id] = group;
        }
      }
      _selected = {...others, ...chosen};
      _groups = normalizeOptionGroups(_selected, groups);
    });
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
    ref.invalidate(wearLogProvider);
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
    final draft = Outfit(
      id: widget.outfitId,
      name: '',
      itemIds: [for (final i in selectedItems) i.id!],
      optionGroups: normalizeOptionGroups(_selected, _groups),
    );
    final entries = ref.watch(wearLogProvider).valueOrNull ?? const [];
    final season = ref.watch(currentSeasonProvider);
    final now = DateTime.now();
    final shuffle =
        _isNew ? null : ref.watch(shuffledPicksProvider)[widget.outfitId!];
    final todayIds = piecesForToday(
      draft,
      byId: byId,
      entries: entries,
      now: now,
      season: season,
      // A shuffle made before editing only counts if its pieces are all
      // still in the outfit.
      shuffled: shuffle != null &&
              shuffle.day == dateOnly(now) &&
              shuffle.itemIds.every(_selected.contains)
          ? shuffle.itemIds
          : null,
    );
    final todayItems =
        orderForDisplay(todayIds.map((id) => byId[id]).whereType<Item>());
    final noun = draft.isUniform ? 'uniform' : 'outfit';

    return Scaffold(
      appBar: AppBar(
        title: Text(_isNew ? 'New $noun' : 'Edit $noun'),
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
          _Preview(items: todayItems, uniform: draft.isUniform),
          if (!_isNew && _savedItemIds.isNotEmpty)
            _OutfitWearRow(outfitId: widget.outfitId!),
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
          OutfitPieces(
            outfit: draft,
            byId: byId,
            season: season,
            wearDays: _isNew ? const {} : optionWearDays(draft, entries),
            onEditOptions: (ids) => _editOptions(ids, candidates),
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
                onTap: (item) => _toggle(item, byId),
              ),
        ],
      ),
    );
  }
}

class _Preview extends StatelessWidget {
  const _Preview({required this.items, required this.uniform});

  /// For a uniform, today's pick.
  final List<Item> items;
  final bool uniform;

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
                      : '${uniform ? "Today's pick · " : ''}'
                          '${items.length} ${items.length == 1 ? 'piece' : 'pieces'}',
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

/// Wear count plus the "Wear this" / "Wearing" toggle, and "Shuffle" for a
/// uniform. Works on the saved outfit, not unsaved edits.
class _OutfitWearRow extends ConsumerWidget {
  const _OutfitWearRow({required this.outfitId});

  final int outfitId;

  Future<void> _confirmRemove(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove from today?'),
        content: const Text('Use this if you marked it by mistake. To '
            'change outfits, just wear another one.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Remove')),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      await stopWearingOutfit(context);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entries = ref.watch(wearLogProvider).valueOrNull ?? const [];
    final current = ref.watch(currentOutfitWearProvider);
    final wearing = current?.outfitId == outfitId;
    final count = outfitWearCount(entries, outfitId);
    final itemIds = ref.watch(todaysPiecesProvider(outfitId));
    final outfit = ref
        .watch(outfitsProvider)
        .valueOrNull
        ?.where((o) => o.id == outfitId)
        .firstOrNull;

    final String status;
    if (wearing && current!.wornAt != null) {
      final time = MaterialLocalizations.of(context).formatTimeOfDay(
        TimeOfDay.fromDateTime(current.wornAt!),
        alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context),
      );
      status = 'Wearing since $time';
    } else if (wearing) {
      status = 'Wearing today';
    } else {
      status = switch (count) {
        0 => 'Not worn yet',
        1 => 'Worn once',
        _ => 'Worn $count times',
      };
    }

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(status, style: Theme.of(context).textTheme.bodyMedium),
          ),
          if (outfit != null && outfit.isUniform && !wearing)
            IconButton(
              icon: const Icon(Icons.shuffle),
              tooltip: 'Shuffle today\'s pick',
              onPressed: () =>
                  ref.read(shuffledPicksProvider.notifier).shuffle(outfit),
            ),
          if (wearing)
            FilledButton.icon(
              icon: const Icon(Icons.check, size: 18),
              label: const Text('Wearing'),
              onPressed: () => _confirmRemove(context),
            )
          else
            FilledButton.tonalIcon(
              icon: const Icon(Icons.checkroom_outlined, size: 18),
              label: const Text('Wear this'),
              onPressed: () =>
                  wearOutfit(context, outfitId: outfitId, itemIds: itemIds),
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
