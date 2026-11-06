import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/format.dart';
import '../../../core/widgets/top_toast.dart';
import '../data/wear_log_repository.dart';
import '../domain/wear_entry.dart';

// These take a BuildContext and use the provider container rather than a
// WidgetRef, because the calling screen may be gone by the time an await
// finishes.

/// Marks an outfit as the one being worn: logs it with the current time.
/// The previous outfit stays in the history but is no longer "wearing". No
/// pop-up: the today bar and the outfit's button show the new state.
Future<void> wearOutfit(
  BuildContext context, {
  required int outfitId,
  required List<int> itemIds,
}) async {
  if (itemIds.isEmpty) return;
  final container = ProviderScope.containerOf(context, listen: false);
  final now = DateTime.now();
  final entries = await container.read(wearLogProvider.future);
  if (currentOutfitWear(entries, now)?.outfitId == outfitId) return;
  final repo = await container.read(wearLogRepositoryProvider.future);
  await repo.log(WearEntry.now(outfitId: outfitId, itemIds: itemIds, now: now));
  container.invalidate(wearLogProvider);
}

/// Undoes [wearOutfit] for today's current outfit: removes that entry, so
/// whatever was worn before it becomes current again.
Future<void> stopWearingOutfit(BuildContext context) async {
  final container = ProviderScope.containerOf(context, listen: false);
  final entries = await container.read(wearLogProvider.future);
  final current = currentOutfitWear(entries, DateTime.now());
  if (current?.id == null) return;
  final repo = await container.read(wearLogRepositoryProvider.future);
  await repo.delete(current!.id!);
  container.invalidate(wearLogProvider);
}

/// Logs loose items as worn now. Skips (and says so) when all of them are
/// already logged for today.
Future<void> logItemsWorn(
  BuildContext context, {
  required List<int> itemIds,
}) async {
  if (itemIds.isEmpty) return;
  final container = ProviderScope.containerOf(context, listen: false);
  final now = DateTime.now();
  final entries = await container.read(wearLogProvider.future);
  if (!context.mounted) return;
  if (alreadyLogged(entries, itemIds, now)) {
    showTopToast(context, 'Already logged today', icon: Icons.info_outline);
    return;
  }
  final repo = await container.read(wearLogRepositoryProvider.future);
  await repo.log(WearEntry.now(itemIds: itemIds, now: now));
  container.invalidate(wearLogProvider);
  final what = itemIds.length == 1 ? 'Item' : '${itemIds.length} items';
  if (context.mounted) {
    showTopToast(context, '${weekdayDate(now)} · $what logged');
  }
}
