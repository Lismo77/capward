# 12. Item colours use standard swatches; the photo only suggests names

Date: 2026-11-12 · Status: accepted

## Context
Since v2 (0.2.0), "Detect from photo" stored each colour's exact shade from
the photo, named after the nearest preset. It also ran automatically on an
item's first photo. Testers found the shades often wrong: lighting and
cameras shift colour, so an olive jacket could show a grey swatch labelled
"olive" (#42). Picking "olive" by hand then added a second olive, because
the two differed in shade.

## Decision
- The user decides an item's colours. Detection suggests colour names and
  stores the standard swatch for each, the same one the picker uses.
- Migration v7 clears every stored shade, so items fall back to the
  standard swatch for their colour names. Backups from before v7 get the
  same treatment on import (`upgradeBackupRow`). No item had a hand-picked
  custom shade at this point, so nothing the user chose is lost.
- The colour sheet works by name (multi-select), so one name is one colour.

## Consequences
- Palette bars show idealised colours rather than the photo's. That's less
  precise when the photo is good, but consistent and never misleading.
- The `swatches` column and `ItemColor.fromValue` stay. A later "adjust the
  shade" option (lighter/darker, warmer/cooler) can store a custom shade
  again, chosen by the user rather than the camera. Not planned before 1.0.
