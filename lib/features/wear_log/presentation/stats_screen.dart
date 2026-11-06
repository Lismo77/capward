import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/format.dart';
import '../../../core/widgets/empty_state.dart';
import '../../wardrobe/presentation/widgets/item_thumbnail.dart';
import '../data/wear_log_repository.dart';
import '../domain/wear_stats.dart';

/// How the wardrobe actually gets used. Everything here comes from the wear
/// log; no AI involved.
class StatsScreen extends ConsumerWidget {
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(wardrobeStatsProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Stats'),
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            tooltip: 'Wear history',
            onPressed: () => context.push('/stats/history'),
          ),
        ],
      ),
      body: stats.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Could not load stats: $e')),
        data: (s) {
          if (s.totalWearDays == 0) {
            return const EmptyState(
              icon: Icons.insights_outlined,
              title: 'Nothing logged yet',
              message:
                  'Tap "Wear this" on an outfit, or log single items. After a '
                  'few weeks you\'ll see what you reach for and what sits '
                  'in the closet.',
            );
          }
          return _StatsList(stats: s);
        },
      ),
    );
  }
}

class _StatsList extends StatelessWidget {
  const _StatsList({required this.stats});

  final WardrobeStats stats;

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    String lastWorn(ItemWearStats s) => s.lastWornOn == null
        ? 'Never worn'
        : 'Last worn ${friendlyDate(s.lastWornOn!, today: today)}';
    String times(int n) => n == 1 ? 'Worn once' : 'Worn $n times';

    return ListView(
      padding: const EdgeInsets.only(bottom: 32),
      children: [
        _Summary(stats: stats),
        if (stats.mostWorn.isNotEmpty) ...[
          const _Header('Most worn'),
          for (final s in stats.mostWorn)
            _ItemRow(
                stats: s, subtitle: lastWorn(s), trailing: '${s.timesWorn}×'),
        ],
        if (stats.notWorn.isNotEmpty) ...[
          const _Header('Not worn in 90 days',
              note: 'Wear it, store it for the season, or let it go.'),
          for (final s in stats.notWorn)
            _ItemRow(stats: s, subtitle: lastWorn(s)),
        ],
        if (stats.leastWorn.isNotEmpty) ...[
          const _Header('Least worn'),
          for (final s in stats.leastWorn)
            _ItemRow(
                stats: s, subtitle: lastWorn(s), trailing: '${s.timesWorn}×'),
        ],
        if (stats.costPerWear.isNotEmpty) ...[
          const _Header('Cost per wear',
              note: 'Price paid divided by wears. Highest first.'),
          for (final s in stats.costPerWear)
            _ItemRow(
              stats: s,
              subtitle: s.timesWorn == 0
                  ? 'Not worn yet · paid ${formatCents(s.item.purchasePriceCents!)}'
                  : '${times(s.timesWorn)} · paid ${formatCents(s.item.purchasePriceCents!)}',
              trailing: formatCents(s.costPerWearCents!),
            ),
        ],
      ],
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary({required this.stats});

  final WardrobeStats stats;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final share = stats.activeCount == 0
        ? 0.0
        : stats.activeWornRecently / stats.activeCount;
    return Card(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${stats.activeWornRecently} of ${stats.activeCount} pieces',
              style: theme.textTheme.headlineSmall,
            ),
            Text('in rotation were worn in the last 30 days',
                style: theme.textTheme.bodyMedium),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(value: share, minHeight: 8),
            ),
            const SizedBox(height: 12),
            Text(
              '${stats.totalWearDays} '
              '${stats.totalWearDays == 1 ? 'day' : 'days'} logged',
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header(this.text, {this.note});

  final String text;
  final String? note;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(text,
              style: theme.textTheme.titleSmall
                  ?.copyWith(color: theme.colorScheme.primary)),
          if (note != null) Text(note!, style: theme.textTheme.bodySmall),
        ],
      ),
    );
  }
}

class _ItemRow extends StatelessWidget {
  const _ItemRow({required this.stats, required this.subtitle, this.trailing});

  final ItemWearStats stats;
  final String subtitle;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    final item = stats.item;
    return ListTile(
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: SizedBox.square(
            dimension: 44, child: ItemThumbnail(item: item, iconSize: 22)),
      ),
      title: Text(item.name, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(subtitle),
      trailing: trailing == null
          ? null
          : Text(trailing!, style: Theme.of(context).textTheme.titleSmall),
      onTap: () => context.push('/wardrobe/${item.id}'),
    );
  }
}
