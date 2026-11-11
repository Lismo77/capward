# Roadmap

**Gansey**, formerly Capward (ADR 0010).

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

## Uniforms *(done, in 0.4.0)*
A uniform is an outfit with option groups: sets of interchangeable items, one
of which is worn (e.g. shirt = any of 4 oxfords; shoes = brown Gibsons). It
is built on outfits, not as a separate system (ADR 0008). No AI needed.

- [x] Option groups: in the outfit builder, tap ⇄ on a piece to add options.
  Stored as `outfit_items.option_group` (migration v5). Groups rather than one
  choice per slot, so shirts and sweaters (both Tops) can each have options.
- [x] Season-aware: picking skips options out of season or not in rotation. A
  group with nothing in season is left out (e.g. no layer in summer).
  Southern hemisphere switch in Settings.
- [x] Today's pick: the option worn longest ago. "Shuffle" rerolls at random.
- [x] Palette bar and collage show the fixed items plus today's pick.
- [x] Wear it: logging a uniform records the exact items picked.
- [x] Turn any saved outfit into a uniform by adding options to a piece.
- [x] Uniform stats: wear count, and options that never get picked.

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
- [ ] Grow the AI settings screen (`/settings/ai`, provider setup only today)
  into the home for all AI options: move the on/off switch there from the
  main Settings screen, and add room for more later (photos, body details,
  model choices).
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

## Rename to Gansey *(done)*
A gansey is the traditional Irish and British fisherman's jumper: made to
last for decades and mended rather than replaced. Wornwell, Wovenwell and
Tenue were ruled out (an existing Play app, a pending USPTO filing, and a
direct AI-stylist competitor).

Do this before the app is posted anywhere. Changing the Android application
id later makes the new build a separate app, so installed testers would lose
their data on upgrade. With no outside testers yet, it costs nothing now.

- [x] Availability check (2026-11-10): no app on F-Droid or Play, 10 unrelated
  GitHub repos, no USPTO filing. `gansey.app` was unregistered.
- [x] App label, Android `applicationId` and `namespace` (now
  `io.github.lismo77.gansey`), web manifest and title, about screen, docs
  and CLAUDE.md.
- [x] Dart package name (`gansey`), which touches imports in `lib/` and
  `test/`.
- [x] Rename the GitHub repo to `gansey` (old links redirect, except the
  Pages site). Update `issuesNewUrl` and the GitHub Pages link testers use.
- [x] Backup files: write `gansey-backup-...zip`, but keep importing the
  old `capward-backup` format.
- [x] Leave the on-device database filename alone. It is internal, and
  renaming it would risk losing existing data.
- [x] Record the decision as an ADR (0010).

## Tester readiness *(priority)*
- [x] Bug and idea report screen: Settings → Help opens a prefilled GitHub
  issue or email (ganseyapp@gmail.com), or copies the text.
- [x] Gap check (2026-11-11). Findings below, roughly in order.
- [x] Signed APK attached to every release, installable directly or through
  Obtainium (ADR 0011). Install steps for testers in the README.
- [ ] Error screen: catch crashes and offer "Report" that opens the feedback
  screen with the error details filled in (no crash reporting service).
- [ ] Backup reminder after two weeks without a backup. iPhone testers must
  add the web app to the Home Screen or Safari may delete its data.
- [ ] Welcome screen, and "Try with sample items" in release builds.
- [ ] Log a wear for an earlier day (moved up from Later).
- [ ] Full-screen photo view (see "Photos").
- [ ] Nice to have: search in the wardrobe.

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
- [ ] Uniforms: a row of swatches per option group in the detail view,
  showing the uniform's full colour range
- [ ] Uniforms: rule-based option groups ("any oxford shirt") that pick up
  new items automatically. Needs a subtype or tags field on items first.
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
- [x] Final icon: a cream gansey with a cursive g on lichen green. Generated by
  `tool/make_icons.py` (Android adaptive and themed icon, web icons).
- [ ] F-Droid metadata (`fastlane/metadata/android/...`), screenshots, reproducible build
- [ ] Submit to F-Droid. Expect the "NonFreeNet" anti-feature label because the app can talk to proprietary AI services.
