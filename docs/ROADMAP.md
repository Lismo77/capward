# Roadmap

Working name: **Capward** (capsule + wardrobe).

Direction: minimalist and anti-consumption. Help people wear what they own and
build a consistent "uniform". AI features are hidden when AI is off.

## v0.1 - Wardrobe basics *(done, running on device)*
- [x] Project scaffold, database schema, navigation
- [x] Add, edit and delete items with photo, colours, material, seasons, formality, price
- [x] Filter the wardrobe by category
- [x] Style profile
- [x] AI provider settings (opt-in, bring your own key, connection test)
- [x] Coach chat grounded in wardrobe and style profile

## v0.2 - Outfits and colour
- [ ] Item colours as real swatches (hex). Pick from the photo or a colour picker, or auto-detect the main colours on-device.
- [ ] Manual outfit builder: pick items by slot (top, bottom, shoes, layer, accessories)
- [ ] Palette bar: a strip of each outfit's colours on its thumbnail and in the detail view. No AI needed.
- [ ] "Wore this today" for an outfit or single items (wear log)
- [ ] Stats: cost per wear, most and least worn, not worn in 90 days

## v0.3 - Uniforms
- [ ] A uniform is a reusable formula: slots, each holding a few interchangeable items (e.g. top = white tee or grey tee; bottom = black jeans; shoes = white sneakers)
- [ ] Shuffle within a uniform for small daily variations (simple random pick, no AI)
- [ ] Turn any outfit into a uniform

## v0.4 - Body and fit profile
- [ ] Optional: height, build, proportions, fit preferences, skin undertone and colouring
- [ ] Separate switch to share it with the AI coach (off by default)

## v0.5 - AI outfit shortcuts (hidden when AI is off)
- [ ] Random outfit: the AI picks a good combination from what you own, with a short reason
- [ ] Outfit vibe: describe a vibe ("cosy library day", "sharp but relaxed dinner") and the AI builds it from your wardrobe
- [ ] Both return structured JSON (item ids and a reason) and appear as outfit cards you can save
- [ ] "Fill in from photo": the AI suggests category, colours, material and seasons
- [ ] Gap analysis and purchase check ("does this fit my capsule, or duplicate something?")

## v0.6 - Photos
- [ ] Background removal, on-device. Needs an open-licensed model (e.g. U²-Net, Apache-2.0) and no Google ML Kit. Expect it to add a few MB to the app.

## Capsules
- [ ] To be designed. Starting idea: a capsule is a subset of items with a target size and season, and outfits and uniforms can be limited to one capsule.

## Later
- [ ] Calendar: plan outfits on days (planned vs worn)
- [ ] Events with dress codes. The AI assigns an existing outfit, or builds one, to fit the dress code.
- [ ] Export/import (zip of the database plus photos)
- [ ] Optional sync through a folder the user controls (Syncthing, Nextcloud, WebDAV)

## v1.0 - Release
- [ ] Final name and icon. Check that "Capward" isn't taken on F-Droid or Play before committing to it.
- [ ] F-Droid metadata (`fastlane/metadata/android/...`), screenshots, reproducible build
- [ ] Submit to F-Droid. Expect the "NonFreeNet" anti-feature label because the app can talk to proprietary AI services.
- [ ] Web build (see ARCHITECTURE.md, "Next structural steps")
