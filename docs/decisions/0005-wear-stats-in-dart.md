# 5. Wear stats are computed in Dart, counting days

Date: 2026-11-06 · Status: accepted

## Context
v0.2 adds the wear log and stats (most and least worn, not worn in 90 days,
cost per wear). The v1 schema already has an `item_wear_stats` view, but it
counts `wear_log_items` rows. An item logged on its own and again as part of
an outfit on the same day would count twice. Shipped migrations can't be
edited.

## Decision
- Load the wear log and compute stats in pure Dart
  (`lib/features/wear_log/domain/wear_stats.dart`), with unit tests.
- "Times worn" means distinct days worn.
- Logging stores the outfit id plus a copy of its item ids, so editing an
  outfit later doesn't rewrite history. Deleting an outfit keeps its wears.
- "Wearing" isn't stored. It's the last outfit logged today, by the time
  in `wear_log.worn_at` (added in migration v3). Wearing another outfit
  makes that one current and leaves the earlier one in the history. Loose
  items logged on their own don't change it. Nothing is "wearing" after
  midnight until an outfit is put on.
- Never-worn items are only flagged as "not worn in 90 days" once they've
  been in the app for 90 days (uses `items.created_at`).

## Consequences
- The stats rules are easy to test and change without a migration.
- The whole wear log is read into memory. That's fine for years of daily
  logs (a few thousand rows). If it ever isn't, move the queries to SQL with
  `COUNT(DISTINCT worn_on)`.
- The old view stays for ad-hoc SQL but isn't used by the app.
