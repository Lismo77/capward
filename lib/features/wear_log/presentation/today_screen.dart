import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/format.dart';
import '../../../core/widgets/empty_state.dart';
import '../../outfits/data/outfit_repository.dart';
import '../../outfits/domain/outfit.dart';
import '../../outfits/presentation/widgets/outfit_collage.dart';
import '../../wardrobe/data/item_repository.dart';
import '../../wardrobe/domain/item.dart';
import '../../wardrobe/presentation/widgets/item_thumbnail.dart';
import '../data/wear_log_repository.dart';
import 'log_wear.dart';
import 'today_bar.dart';

/// What's being worn today, opened from the today bar. Pieces can be added
/// or taken out as the day goes on. This edits the day's log, never the
/// saved outfit it came from.
class TodayScreen extends ConsumerWidget {
  const TodayScreen({super.key});

  Future<void> _remove(BuildContext context, Item item, int pieceCount) async {
    // The last piece takes the whole wear with it, which Undo can't restore.
    if (pieceCount <= 1) return _confirmRemoveAll(context);
    final messenger = ScaffoldMessenger.of(context);
    if (!await removeFromTodaysWear(context, itemId: item.id!)) return;
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text('${item.name} removed from today'),
        // With an action, a snack bar stays until dismissed unless told not to.
        persist: false,
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () {
            if (context.mounted) {
              addToTodaysWear(context, itemIds: [item.id!]);
            }
          },
        ),
      ));
  }

  Future<void> _confirmRemoveAll(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Remove today's outfit?"),
        content: const Text('That was the last piece, so nothing will be '
            'logged as worn today.'),
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
    if (confirmed == true && context.mounted) await removeTodaysWear(context);
  }

  Future<void> _add(BuildContext context, List<Item> all, Set<int> worn) async {
    final picked = await showAddPiecesSheet(
      context,
      candidates: [
        for (final i in all)
          if (!worn.contains(i.id) &&
              i.status != ItemStatus.wishlist &&
              i.status != ItemStatus.retired)
            i,
      ],
    );
    if (picked == null || picked.isEmpty || !context.mounted) return;
    await addToTodaysWear(context, itemIds: picked);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final current = ref.watch(currentWearProvider);
    final items = ref.watch(itemsProvider).valueOrNull ?? const <Item>[];
    final outfits = ref.watch(outfitsProvider).valueOrNull ?? const <Outfit>[];
    final now = DateTime.now();

    if (current == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Today')),
        body: EmptyState(
          icon: Icons.checkroom_outlined,
          title: 'Nothing logged today',
          message: 'Pick an outfit, or log pieces from the wardrobe.',
          action: FilledButton.tonal(
            onPressed: () => showQuickChooseSheet(context),
            child: const Text('Choose outfit'),
          ),
        ),
      );
    }

    final byId = {for (final i in items) i.id!: i};
    final pieces = orderForDisplay(
        current.itemIds.map((id) => byId[id]).whereType<Item>());
    final outfit = outfits.where((o) => o.id == current.outfitId).firstOrNull;
    final name = outfit?.name ??
        (pieces.isEmpty ? "Today's outfit" : defaultOutfitName(pieces));
    final wornAt = current.wornAt;
    final since = wornAt == null
        ? ''
        : ' · since ${MaterialLocalizations.of(context).formatTimeOfDay(
            TimeOfDay.fromDateTime(wornAt),
            alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context),
          )}';
    final source = outfit == null ? 'Loose pieces' : 'From your outfits';

    return Scaffold(
      appBar: AppBar(title: Text(weekdayDate(now))),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: SizedBox.square(
                    dimension: 72,
                    child: OutfitCollage(items: pieces, iconSize: 20),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name, style: theme.textTheme.titleMedium),
                      const SizedBox(height: 2),
                      Text('$source$since', style: theme.textTheme.bodySmall),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.tonalIcon(
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Add item'),
                  onPressed: () =>
                      _add(context, items, current.itemIds.toSet()),
                ),
                OutlinedButton.icon(
                  icon: const Icon(Icons.swap_horiz, size: 18),
                  label: const Text('Change outfit'),
                  onPressed: () => showQuickChooseSheet(context),
                ),
                if (outfit == null && pieces.isNotEmpty)
                  OutlinedButton.icon(
                    icon: const Icon(Icons.bookmark_add_outlined, size: 18),
                    label: const Text('Save as outfit'),
                    onPressed: () => context.push('/outfits/new',
                        extra: [for (final p in pieces) p.id!]),
                  ),
              ],
            ),
          ),
          const Divider(height: 24),
          for (final item in pieces)
            ListTile(
              leading: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox.square(
                  dimension: 48,
                  child: ItemThumbnail(item: item, iconSize: 20),
                ),
              ),
              title: Text(item.name),
              subtitle: Text(item.category.label),
              onTap: () => context.push('/wardrobe/${item.id}'),
              trailing: IconButton(
                icon: const Icon(Icons.remove_circle_outline),
                tooltip: 'Remove: not worn today',
                onPressed: () => _remove(context, item, pieces.length),
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Text(
              'Removing a piece means it wasn\'t worn today, so it '
              'doesn\'t count in stats. Saved outfits aren\'t changed.',
              style: theme.textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}

/// Owned pieces to add to today's outfit, with a name search. Returns the
/// ticked ids in tick order, or null if dismissed.
Future<List<int>?> showAddPiecesSheet(
  BuildContext context, {
  required List<Item> candidates,
}) {
  return showModalBottomSheet<List<int>>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (context) => _AddPiecesSheet(candidates: candidates),
  );
}

class _AddPiecesSheet extends StatefulWidget {
  const _AddPiecesSheet({required this.candidates});

  final List<Item> candidates;

  @override
  State<_AddPiecesSheet> createState() => _AddPiecesSheetState();
}

class _AddPiecesSheetState extends State<_AddPiecesSheet> {
  final _picked = <int>[];
  var _query = '';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final shown = orderForDisplay(widget.candidates.where((i) =>
        _query.isEmpty || i.name.toLowerCase().contains(_query.toLowerCase())));
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.8,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      builder: (context, controller) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Add to today's outfit",
                    style: theme.textTheme.titleMedium),
                const SizedBox(height: 8),
                TextField(
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search),
                    hintText: 'Search your wardrobe',
                    isDense: true,
                  ),
                  onChanged: (v) => setState(() => _query = v.trim()),
                ),
              ],
            ),
          ),
          Expanded(
            child: shown.isEmpty
                ? Center(
                    child: Text(widget.candidates.isEmpty
                        ? 'Everything you own is already in it.'
                        : 'No pieces match.'))
                : ListView(
                    controller: controller,
                    children: [
                      for (final item in shown)
                        CheckboxListTile(
                          value: _picked.contains(item.id),
                          onChanged: (v) => setState(() {
                            if (v == true) {
                              _picked.add(item.id!);
                            } else {
                              _picked.remove(item.id);
                            }
                          }),
                          secondary: ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: SizedBox.square(
                              dimension: 40,
                              child: ItemThumbnail(item: item, iconSize: 18),
                            ),
                          ),
                          title: Text(item.name),
                          subtitle: Text(item.category.label),
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
                  onPressed: _picked.isEmpty
                      ? null
                      : () => Navigator.pop(context, _picked),
                  child: Text(switch (_picked.length) {
                    0 => 'Pick pieces to add',
                    1 => 'Add 1 piece',
                    final n => 'Add $n pieces',
                  }),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
