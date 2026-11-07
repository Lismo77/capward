# 8. Uniforms are outfits with option slots

Date: 2026-11-06 · Status: accepted

## Context
A uniform is a repeatable way of dressing: the same formula most days, with
small variations (e.g. one of several oxford shirts, a layer that changes
with the season). Saving every combination as an outfit doesn't scale:
4 shirts × 3 ties × 2 vests is 24 near-identical outfits, each needing edits
when an item is added.

We considered three shapes:

- A separate Uniforms feature with its own screens and tables.
- Uniforms as a sub-feature of capsules. Rejected: capsules are about what
  you own (a pool of items), uniforms about how you wear it (a formula).
  Nesting them would force a capsule before a uniform.
- Uniforms as outfits whose slots can hold several options.

The app should stay small, so fewer concepts is better.

## Decision
A uniform is an outfit where at least one slot holds several items marked as
"pick one". It lives in the Outfits tab, is shown with a uniform label, and
reuses the outfit builder.

- `outfit_items` gets a flag (new migration) that separates options from
  items worn together (e.g. a shirt under a cardigan).
- Picking skips options not tagged for the current season, using the
  existing `seasons` field. A slot with nothing in season stays empty.
- The default pick is the option worn least recently (from the wear log). A
  shuffle button gives a random pick.
- Logging a uniform records the exact items picked.

Slots are filled by hand. Rule-based slots ("any oxford shirt") are left out
because items have no subtype or tags field.

## Consequences
- One fewer screen and concept. Any outfit becomes a uniform by adding an
  option to a slot.
- Wear stats stay accurate because the log stores the items actually worn.
- Code that reads `outfit_items` must respect the flag: for example, AI
  prompts shouldn't treat options as items worn together.
- A uniform's palette bar shows the fixed items plus today's pick, so it
  matches what would be worn today, the same as an outfit's. It updates on
  shuffle and changes with the season. Today's pick is worked out from the
  wear log and item seasons, so only a shuffle result needs keeping.
- Old backups still import: the new column takes its default (not an
  option), so existing outfits are unchanged.
- Colour and fit preferences live in the style profile and the body and fit
  profile, not on the uniform.
- Capsules can later limit outfits and uniforms to their items, without
  depending on them.
