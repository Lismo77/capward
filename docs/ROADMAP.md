# Roadmap

Working name: **Capward** (capsule + wardrobe).

Direction: minimalist and anti-consumption. Help people wear what they own and
build a consistent "uniform". AI features are hidden when AI is off.

Sections are milestones, listed roughly in order. They aren't version
numbers: release-please sets versions from commit types (ADR 0006), and
[CHANGELOG.md](../CHANGELOG.md) lists what each release contained.

## Wardrobe basics *(done, in 0.2.0)*
- [x] Project scaffold, database schema, navigation
- [x] Add, edit and delete items with photo, colours, material, seasons, formality, price
- [x] Filter the wardrobe by category
- [x] Style profile
- [x] AI provider settings (opt-in, bring your own key, connection test)
- [x] Coach chat grounded in wardrobe and style profile

## Outfits and colour *(done, in 0.2.0)*
- [x] Item colours as real swatches (hex). Pick from the photo or a colour picker, or auto-detect the main colours on-device.
- [x] Manual outfit builder: pick items by slot (top, bottom, shoes, layer, accessories)
- [x] Palette bar: a strip of each outfit's colours on its thumbnail and in the detail view. No AI needed.
- [x] Wear log: mark an outfit as "wearing" (switching outfits keeps both, with times) or log single items. History grouped by day.
- [x] Stats: cost per wear, most and least worn, not worn in 90 days

## Web preview for iPhone testers *(done, backups in 0.3.0)*
- [x] Web build: SQLite in the browser, photos in the database, GitHub Pages deploy
- [x] Turn on GitHub Pages and share the link with testers
- [x] Export/import backup: a .zip of all data and photos (Settings → Your data)

## Uniforms *(next)*
A uniform is an outfit where some slots hold several interchangeable options
instead of one item (e.g. shirt = any of 4 oxfords; shoes = brown Gibsons).
It is built on outfits, not as a separate system: one entry replaces dozens
of near-identical saved outfits. No AI needed.

- [ ] Option slots: in the outfit builder, a slot can hold several items marked
  as "pick one". Needs a per-item flag on `outfit_items` (new migration) so
  options are kept apart from items worn together (e.g. a shirt under a
  cardigan). An outfit with at least one option slot shows as a uniform.
- [ ] Season-aware: when picking, skip options not tagged for the current
  season. A slot with no in-season options is left empty (e.g. no layer in
  summer). Uses the existing `seasons` field on items.
- [ ] Today's pick: choose the option worn least recently (from the wear log),
  so wear is spread evenly. A "shuffle" button rerolls with a random pick.
- [ ] Palette bar: shows the fixed items plus today's pick, and updates on
  shuffle. Nice-to-have: in the detail view, a small row of swatches per
  option slot showing all its options.
- [ ] Wear it: logging a uniform records the exact items picked, so cost per
  wear and other stats stay accurate.
- [ ] Turn any saved outfit into a uniform by adding options to a slot.
- [ ] Uniform stats: how often each uniform is worn, and options that never
  get picked.

Not in this milestone: rule-based slots ("any oxford shirt") that pick up new items
automatically. Items have no subtype or tags field yet, so slots are filled by
hand. Colour and fit preferences belong in the style profile and the body and
fit profile, not in the uniform.

## Body and fit profile
- [ ] Optional: height, build, proportions, fit preferences, skin undertone and colouring
- [ ] Separate switch to share it with the AI coach (off by default)

## AI outfit shortcuts (hidden when AI is off)
- [ ] Random outfit: the AI picks a good combination from what you own, with a short reason
- [ ] Outfit vibe: describe a vibe ("cosy library day", "sharp but relaxed dinner") and the AI builds it from your wardrobe
- [ ] Both return structured JSON (item ids and a reason) and appear as outfit cards you can save
- [x] **Must have.** "Create outfit" from coach chat: when the coach suggests
  an outfit from the user's items, a button under the reply opens the outfit
  builder pre-filled with those items, to check and save. The prompt already
  gives each item an `[id]`; the coach adds a small machine-readable block
  of ids, which the app hides from the reply text. The builder already takes
  pre-selected items (`initialItemIds`).
- [ ] "Fill in from photo": the AI suggests category, colours, material and seasons
- [ ] Gap analysis and purchase check ("does this fit my capsule or uniform, or duplicate something?")

## AI coach photos and threads *(priority, tester feedback)*
- [ ] Dedicated AI settings screen. Holds the provider setup now on the main
  Settings screen, and gives room for more AI options later (photos, body
  details, model choices).
- [ ] Photo sharing setting: a separate "Let the AI see photos" switch in AI
  settings, off by default, hidden controls when off (ADR 0009).
- [ ] Attach photos in coach chat, per message. Two uses: a piece you're
  thinking of buying (does it fit the wardrobe, is the price and quality
  good), and you wearing an item (fit, body type, colouring).
- [ ] Saveable coach threads: continue a styling session later. Photos in a
  thread are stored locally with it so it stays readable.
- [ ] Archive thread: when archiving, delete the thread's photos or keep
  downscaled copies, to save space.
- [ ] Coach asks clarifying questions before building an outfit (e.g. the
  dress code for a wedding).

## Photos
- [ ] Background removal, on-device. Needs an open-licensed model (e.g. U²-Net, Apache-2.0) and no Google ML Kit. Expect it to add a few MB to the app.
- [ ] Rotate item photos in-app. Maybe also auto rotate/crop on upload,
  possibly as part of the background-removal tool.
- [ ] Easier to see the whole photo inside an item or outfit.

## Tester readiness *(priority)*
- [ ] Bug and missing-feature report route for testers, plus a gap check on
  anything else needed before recruiting testers in forums.

## Item details
- [ ] Sizing: record the size, and flag pieces that may not currently fit.
- [ ] Hats as their own category (you can only wear one).
- [ ] Price paid: blank means unknown, 0 means free or gift.
- [ ] Retired items hidden from the main dashboard, reachable from another menu.
- [ ] Colour picker accuracy (reported as imprecise).
- [ ] Full-screen outfit view with the palette bar on top or bottom.

## Capsules
- [ ] To be designed. Its placeholder tab was replaced by Stats in 0.2.0 and
  comes back when capsules are built. Starting idea: a capsule is a subset of items with a target size and season, and outfits and uniforms can be limited to one capsule.

## Later
- [ ] Log a wear for an earlier day (only today can be logged for now)
- [ ] Calendar: plan outfits on days (planned vs worn)
- [ ] Scheduled outfit check-in: on the day, ask "Wearing this?" Yes logs it;
  "No, I wore something else" lets the user pick the outfit they wore
- [ ] Events with dress codes. The AI assigns an existing outfit, or builds one, to fit the dress code.
- [ ] Optional sync through a folder the user controls (Syncthing, Nextcloud, WebDAV)

## Maintenance
- [x] `flutter_secure_storage` 10, `file_picker` 13, `package_info_plus` 10.
  Removed the Kotlin workaround and the "plugins apply KGP" build warning.
- [ ] `flutter_secure_storage` 11, but only after a release with v10 is out:
  v10 converts stored keys to the new ciphers when they're read, and v11
  can't read the old format. Going 9 → 11 directly would lose saved API keys.

## First public release (1.0)
- [ ] Final name and icon. Check that "Capward" isn't taken on F-Droid or Play before committing to it.
- [ ] F-Droid metadata (`fastlane/metadata/android/...`), screenshots, reproducible build
- [ ] Submit to F-Droid. Expect the "NonFreeNet" anti-feature label because the app can talk to proprietary AI services.
