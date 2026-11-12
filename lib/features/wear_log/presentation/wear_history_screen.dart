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
import '../domain/wear_entry.dart';

/// Every logged wear, newest first. Swipe an entry away to delete it.
class WearHistoryScreen extends ConsumerStatefulWidget {
  const WearHistoryScreen({super.key});

  @override
  ConsumerState<WearHistoryScreen> createState() => _WearHistoryScreenState();
}

class _WearHistoryScreenState extends ConsumerState<WearHistoryScreen> {
  /// Swiped-away entries, hidden at once so the Dismissible leaves the tree
  /// before the provider has reloaded.
  final _hidden = <int>{};

  Future<void> _delete(WearEntry entry) async {
    setState(() => _hidden.add(entry.id!));
    final messenger = ScaffoldMessenger.of(context);
    final container = ProviderScope.containerOf(context, listen: false);
    final repo = await ref.read(wearLogRepositoryProvider.future);
    await repo.delete(entry.id!);
    container.invalidate(wearLogProvider);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(SnackBar(
      content: const Text('Entry deleted'),
      // With an action, a snack bar stays until dismissed unless told not to.
      persist: false,
      action: SnackBarAction(
        label: 'Undo',
        onPressed: () async {
          await repo.log(entry);
          container.invalidate(wearLogProvider);
        },
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final entries = ref.watch(wearLogProvider);
    final items = ref.watch(itemsProvider).valueOrNull ?? const <Item>[];
    final outfits = ref.watch(outfitsProvider).valueOrNull ?? const <Outfit>[];
    final itemsById = {for (final i in items) i.id!: i};
    final outfitsById = {for (final o in outfits) o.id!: o};
    final today = DateTime.now();

    return Scaffold(
      appBar: AppBar(title: const Text('Wear history')),
      body: entries.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Could not load history: $e')),
        data: (all) {
          final list = all.where((e) => !_hidden.contains(e.id)).toList();
          if (list.isEmpty) {
            return const EmptyState(
              icon: Icons.history,
              title: 'No wears logged',
              message: 'Entries appear here when you wear an outfit or log '
                  'an item.',
            );
          }
          // Date headings between entries, newest day first.
          final rows = <Object>[];
          DateTime? day;
          for (final e in list) {
            if (e.wornOn != day) rows.add(day = e.wornOn);
            rows.add(e);
          }
          final currentId = ref.watch(currentWearProvider)?.id;
          final localizations = MaterialLocalizations.of(context);
          final use24h = MediaQuery.alwaysUse24HourFormatOf(context);
          final theme = Theme.of(context);

          return ListView.builder(
            padding: const EdgeInsets.only(bottom: 32),
            itemCount: rows.length,
            itemBuilder: (context, i) {
              final row = rows[i];
              if (row is DateTime) {
                final friendly = friendlyDate(row, today: today);
                final label = friendly.contains(' ')
                    ? weekdayDate(row) +
                        (row.year == today.year ? '' : ' ${row.year}')
                    : '$friendly · ${weekdayDate(row)}';
                return Padding(
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
                  child: Text(label,
                      style: theme.textTheme.titleSmall
                          ?.copyWith(color: theme.colorScheme.primary)),
                );
              }
              final entry = row as WearEntry;
              final pieces = orderForDisplay(
                  entry.itemIds.map((id) => itemsById[id]).whereType<Item>());
              final outfit = outfitsById[entry.outfitId];
              final title = outfit?.name ??
                  (pieces.isEmpty
                      ? 'Removed items'
                      : defaultOutfitName(pieces));
              final details = [
                if (entry.wornAt != null)
                  localizations.formatTimeOfDay(
                      TimeOfDay.fromDateTime(entry.wornAt!),
                      alwaysUse24HourFormat: use24h),
                '${pieces.length} ${pieces.length == 1 ? 'piece' : 'pieces'}',
                if (entry.outfitId == null) 'loose items',
              ].join(' · ');
              return Dismissible(
                key: ValueKey(entry.id),
                direction: DismissDirection.endToStart,
                background: Container(
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  color: theme.colorScheme.errorContainer,
                  child: const Icon(Icons.delete_outline),
                ),
                onDismissed: (_) => _delete(entry),
                // Tap to see the pieces; each opens its item.
                child: ExpansionTile(
                  shape: const Border(),
                  collapsedShape: const Border(),
                  leading: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: SizedBox.square(
                      dimension: 48,
                      child: OutfitCollage(items: pieces, iconSize: 14),
                    ),
                  ),
                  title:
                      Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
                  subtitle: Text(details),
                  trailing: entry.id == currentId
                      ? const Chip(
                          avatar: Icon(Icons.check, size: 16),
                          label: Text('Wearing'),
                          visualDensity: VisualDensity.compact,
                        )
                      : null,
                  children: [
                    for (final item in pieces)
                      ListTile(
                        dense: true,
                        contentPadding:
                            const EdgeInsets.only(left: 32, right: 16),
                        leading: ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: SizedBox.square(
                            dimension: 36,
                            child: ItemThumbnail(item: item, iconSize: 16),
                          ),
                        ),
                        title: Text(item.name),
                        subtitle: Text(item.category.label),
                        onTap: () => context.push('/wardrobe/${item.id}'),
                      ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
