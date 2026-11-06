import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/format.dart';
import '../../outfits/data/outfit_repository.dart';
import '../../outfits/domain/outfit.dart';
import '../../outfits/presentation/widgets/outfit_collage.dart';
import '../../wardrobe/data/item_repository.dart';
import '../../wardrobe/domain/item.dart';
import '../data/wear_log_repository.dart';
import '../domain/wear_entry.dart';
import 'log_wear.dart';

/// Strip across the top of the main tabs: today's date and either a
/// "Choose outfit" button or the outfit being worn. Tapping it opens the
/// quick-choose sheet.
class TodayBar extends ConsumerWidget {
  const TodayBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final now = DateTime.now();
    final current = ref.watch(currentOutfitWearProvider);
    final outfits = ref.watch(outfitsProvider).valueOrNull ?? const <Outfit>[];
    final items = ref.watch(itemsProvider).valueOrNull ?? const <Item>[];
    final outfit = current == null
        ? null
        : outfits.where((o) => o.id == current.outfitId).firstOrNull;

    final Widget content;
    if (outfit == null) {
      content = Row(
        children: [
          Expanded(
            child: Text(weekdayDate(now), style: theme.textTheme.titleSmall),
          ),
          FilledButton.tonalIcon(
            icon: const Icon(Icons.checkroom_outlined, size: 18),
            label: const Text('Choose outfit'),
            onPressed: () => showQuickChooseSheet(context),
          ),
        ],
      );
    } else {
      final byId = {for (final i in items) i.id!: i};
      final pieces = orderForDisplay(
          outfit.itemIds.map((id) => byId[id]).whereType<Item>());
      final since = current!.wornAt == null
          ? ''
          : ' · since ${_time(context, current.wornAt!)}';
      content = Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: SizedBox.square(
              dimension: 36,
              child: OutfitCollage(items: pieces, iconSize: 12),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(outfit.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleSmall),
                    ),
                    const SizedBox(width: 6),
                    Icon(Icons.check_circle, size: 16, color: scheme.primary),
                  ],
                ),
                Text('${weekdayDate(now)}$since',
                    style: theme.textTheme.bodySmall),
              ],
            ),
          ),
          TextButton(
            onPressed: () => showQuickChooseSheet(context),
            child: const Text('Change'),
          ),
        ],
      );
    }

    return Material(
      color: scheme.surfaceContainerHigh,
      child: SafeArea(
        bottom: false,
        child: InkWell(
          onTap: () => showQuickChooseSheet(context),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 8, 6),
            child: SizedBox(height: 44, child: content),
          ),
        ),
      ),
    );
  }
}

/// Scrollable list of outfits, most worn first. Tapping one marks it as
/// being worn right away.
Future<void> showQuickChooseSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      minChildSize: 0.3,
      maxChildSize: 0.9,
      builder: (_, controller) =>
          _QuickChooseList(controller: controller, outerContext: context),
    ),
  );
}

class _QuickChooseList extends ConsumerWidget {
  const _QuickChooseList({
    required this.controller,
    required this.outerContext,
  });

  final ScrollController controller;

  /// Context of the screen that opened the sheet. Still mounted after the
  /// sheet closes, so logging and navigation go through it.
  final BuildContext outerContext;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final outfits = ref.watch(outfitsProvider).valueOrNull ?? const <Outfit>[];
    final items = ref.watch(itemsProvider).valueOrNull ?? const <Item>[];
    final entries = ref.watch(wearLogProvider).valueOrNull ?? const [];
    final current = ref.watch(currentOutfitWearProvider);
    final byId = {for (final i in items) i.id!: i};
    final sorted = sortByMostWorn(
      outfits.where((o) => o.itemIds.isNotEmpty),
      entries,
    );
    final today = DateTime.now();

    void newOutfit() {
      Navigator.pop(context);
      outerContext.push('/outfits/new');
    }

    return ListView(
      controller: controller,
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Text('What are you wearing today?',
              style: theme.textTheme.titleMedium),
        ),
        if (sorted.isEmpty)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                const Text('No outfits yet. Put one together from what you '
                    'own, then pick it here.'),
                const SizedBox(height: 12),
                FilledButton.tonal(
                    onPressed: newOutfit, child: const Text('New outfit')),
              ],
            ),
          ),
        for (final outfit in sorted)
          _OutfitOption(
            outfit: outfit,
            pieces: orderForDisplay(
                outfit.itemIds.map((id) => byId[id]).whereType<Item>()),
            timesWorn: outfitWearCount(entries, outfit.id!),
            lastWorn: lastWornOn(entries, outfit.id!),
            today: today,
            wearing: current?.outfitId == outfit.id,
            onTap: () {
              Navigator.pop(context);
              if (current?.outfitId != outfit.id) {
                wearOutfit(outerContext,
                    outfitId: outfit.id!, itemIds: outfit.itemIds);
              }
            },
          ),
        if (current != null) ...[
          const Divider(height: 24),
          ListTile(
            leading: const Icon(Icons.undo),
            title: const Text("Remove today's outfit"),
            subtitle: const Text('If you picked one by mistake'),
            onTap: () {
              Navigator.pop(context);
              stopWearingOutfit(outerContext);
            },
          ),
        ],
      ],
    );
  }
}

class _OutfitOption extends StatelessWidget {
  const _OutfitOption({
    required this.outfit,
    required this.pieces,
    required this.timesWorn,
    required this.lastWorn,
    required this.today,
    required this.wearing,
    required this.onTap,
  });

  final Outfit outfit;
  final List<Item> pieces;
  final int timesWorn;
  final DateTime? lastWorn;
  final DateTime today;
  final bool wearing;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final subtitle = timesWorn == 0
        ? 'Not worn yet'
        : '${timesWorn == 1 ? 'Worn once' : 'Worn $timesWorn times'} · '
            'last ${inlineDate(lastWorn!, today: today)}';
    return ListTile(
      selected: wearing,
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: SizedBox.square(
          dimension: 52,
          child: OutfitCollage(items: pieces, iconSize: 16),
        ),
      ),
      title: Text(outfit.name, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(wearing ? 'Wearing now' : subtitle),
      trailing:
          wearing ? Icon(Icons.check_circle, color: scheme.primary) : null,
      onTap: onTap,
    );
  }
}

String _time(BuildContext context, DateTime t) =>
    MaterialLocalizations.of(context).formatTimeOfDay(
      TimeOfDay.fromDateTime(t),
      alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context),
    );
