import 'package:flutter/material.dart';

import '../../../wardrobe/domain/item.dart';
import '../../../wardrobe/presentation/widgets/item_thumbnail.dart';
import '../../domain/outfit.dart';
import '../../domain/uniform.dart';

/// The outfit's pieces, top to bottom. Fixed pieces have an "Add options"
/// button; option groups ("pick one") show what's in them and how often each
/// option gets worn. Adding options is what turns an outfit into a uniform.
class OutfitPieces extends StatelessWidget {
  const OutfitPieces({
    super.key,
    required this.outfit,
    required this.byId,
    required this.season,
    required this.wearDays,
    required this.onEditOptions,
  });

  final Outfit outfit;
  final Map<int, Item> byId;
  final Season season;

  /// Days each option was worn in this uniform (see [optionWearDays]).
  final Map<int, int> wearDays;

  /// Called with a fixed piece's id, or every id in an option group.
  final ValueChanged<List<int>> onEditOptions;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    List<Item> resolve(Iterable<int> ids) =>
        orderForDisplay(ids.map((id) => byId[id]).whereType<Item>());

    final rows = <List<Item>>[
      for (final item in resolve(outfit.fixedItemIds)) [item],
      for (final group in outfit.groups)
        if (resolve(group) case final items when items.isNotEmpty) items,
    ]..sort((a, b) => OutfitSlot.forCategory(a.first.category)
        .index
        .compareTo(OutfitSlot.forCategory(b.first.category).index));
    if (rows.isEmpty) return const SizedBox.shrink();

    final anyWorn = wearDays.values.any((d) => d > 0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 20, bottom: 4),
          child: Text('Pieces', style: theme.textTheme.titleSmall),
        ),
        Text(
          outfit.isUniform
              ? 'A uniform: each "pick one" row is a set of options. Today\'s '
                  'pick takes the in-season option you wore longest ago.'
              : 'Tap ⇄ on a piece to add options you swap between. That '
                  'turns this outfit into a uniform.',
          style: theme.textTheme.bodySmall,
        ),
        const SizedBox(height: 4),
        for (final row in rows)
          if (row.length == 1 && !outfit.optionGroups.containsKey(row.first.id))
            _FixedRow(
                item: row.first,
                onAddOptions: () => onEditOptions([row.first.id!]))
          else
            _GroupRow(
              items: row,
              season: season,
              wearDays: anyWorn ? wearDays : const {},
              onEdit: () => onEditOptions([for (final i in row) i.id!]),
            ),
      ],
    );
  }
}

class _FixedRow extends StatelessWidget {
  const _FixedRow({required this.item, required this.onAddOptions});

  final Item item;
  final VoidCallback onAddOptions;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: _Thumb(item: item),
      title: Text(item.name, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(OutfitSlot.forCategory(item.category).label),
      trailing: IconButton(
        icon: const Icon(Icons.swap_horiz),
        tooltip: 'Add options',
        onPressed: onAddOptions,
      ),
    );
  }
}

class _GroupRow extends StatelessWidget {
  const _GroupRow({
    required this.items,
    required this.season,
    required this.wearDays,
    required this.onEdit,
  });

  final List<Item> items;
  final Season season;

  /// Empty until the uniform has been worn at least once.
  final Map<int, int> wearDays;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final outOfSeason = items.where((i) => !wearableIn(i, season)).length;
    final neverPicked = [
      for (final i in items)
        if (wearDays[i.id] == 0) i.name,
    ];
    final details = [
      'Pick one of ${items.length}',
      if (outOfSeason == items.length)
        'none in season, skipped for now'
      else if (outOfSeason > 0)
        '$outOfSeason out of season',
    ].join(' · ');

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Badge(
        label: Text('${items.length}'),
        child: _Thumb(item: items.first),
      ),
      title: Text(items.map((i) => i.name).join(' / '),
          maxLines: 2, overflow: TextOverflow.ellipsis),
      subtitle: Text.rich(TextSpan(children: [
        TextSpan(text: details),
        if (neverPicked.isNotEmpty)
          TextSpan(
            text: '\nNever picked: ${neverPicked.join(', ')}',
            style: TextStyle(color: theme.colorScheme.tertiary),
          ),
      ])),
      trailing: IconButton(
        icon: const Icon(Icons.edit_outlined),
        tooltip: 'Edit options',
        onPressed: onEdit,
      ),
      onTap: onEdit,
    );
  }
}

class _Thumb extends StatelessWidget {
  const _Thumb({required this.item});

  final Item item;

  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: SizedBox.square(
          dimension: 44,
          child: ItemThumbnail(item: item, iconSize: 18),
        ),
      );
}

/// Multi-select sheet for one option group. [candidates] are the items that
/// can be options (same slot). Returns the chosen ids, or null if dismissed.
/// One chosen item means a plain fixed piece; none removes the piece.
Future<Set<int>?> showOptionsSheet(
  BuildContext context, {
  required String slotLabel,
  required List<Item> candidates,
  required Set<int> initial,
}) {
  return showModalBottomSheet<Set<int>>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (context) {
      var chosen = {...initial};
      return StatefulBuilder(
        builder: (context, setState) => DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.7,
          minChildSize: 0.4,
          maxChildSize: 0.95,
          builder: (context, controller) {
            final theme = Theme.of(context);
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Options: ${slotLabel.toLowerCase()}',
                          style: theme.textTheme.titleMedium),
                      const SizedBox(height: 4),
                      Text(
                        'Tick the pieces you swap between. One is picked '
                        'each day, skipping anything out of season.',
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView(
                    controller: controller,
                    children: [
                      for (final item in candidates)
                        CheckboxListTile(
                          value: chosen.contains(item.id),
                          onChanged: (v) => setState(() => v == true
                              ? chosen.add(item.id!)
                              : chosen.remove(item.id)),
                          secondary: _Thumb(item: item),
                          title: Text(item.name),
                          subtitle: Text(item.seasons.isEmpty
                              ? 'Any season'
                              : (item.seasons.toList()
                                    ..sort(
                                        (a, b) => a.index.compareTo(b.index)))
                                  .map((s) => s.label)
                                  .join(', ')),
                        ),
                    ],
                  ),
                ),
                SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                    child: SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: () => Navigator.pop(context, chosen),
                        child: Text(switch (chosen.length) {
                          0 => 'Remove piece',
                          1 => 'Done',
                          final n => 'Use $n options',
                        }),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      );
    },
  );
}
