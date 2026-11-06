# Architecture

## Big picture

```
┌──────────────────── Device ────────────────────┐
│  Screens (presentation/)                       │
│     │ watch / read                             │
│  Riverpod providers (data/)                    │
│     │                                          │
│  Repositories ── SQLite (sqflite)              │
│               └─ photos in app documents dir   │
│                                                │
│  AiClient (lib/ai) ── only if the user opts in │
└─────────────────────┬──────────────────────────┘
                      │ HTTPS, the user's own key
                      ▼
      Claude / OpenAI / Gemini / OpenRouter / Ollama ...
```

There is no backend. That keeps the app free to run, private, and acceptable
to F-Droid.

## Data model

| Table | Purpose |
|---|---|
| `items` | One row per piece of clothing. Colours and seasons are comma-separated text. |
| `outfits`, `outfit_items` | Named groups of items (many-to-many). `source` records whether the user or the AI made it. |
| `capsules`, `capsule_items` | Collections with a season, dates and target size. An item can be in several. |
| `wear_log`, `wear_log_items` | What was worn on which day. Drives every stat. |
| `style_profile` | One row: palette, style words, silhouettes, things to avoid, lifestyle. |
| `item_wear_stats` (view) | Times worn, last worn and cost per wear for each item. Counts rows, not days, so the app doesn't use it (see ADR 0005). Handy for ad-hoc SQL. |

Money is stored as integer cents. Dates are ISO-8601 text.

## AI layer

- `AiClient.complete(system, messages)` returns text. Two adapters:
  - `AnthropicClient`: `POST {base}/v1/messages`, `x-api-key` and
    `anthropic-version` headers. On models that support it, server-side
    refusal fallbacks are turned on.
  - `OpenAiCompatibleClient`: `POST {base}/chat/completions`, Bearer key.
    This covers most other providers and local servers.
- `AiPreset` fills in a provider's base URL and suggested model. Users can
  still change both.
- Settings: on/off, provider, URL and model live in `shared_preferences`.
  The key lives in `flutter_secure_storage` and is only read when a request
  is built.
- `aiClientProvider` returns `null` when AI is off or not set up. Every
  AI feature checks for this.
- Grounding: `buildCoachSystemPrompt` sends the style profile plus one text
  line per item (`[id] name - category; colors; ...`). Items are referred to
  by id so replies can later be turned into real outfit records.

## Next structural steps

- **Structured output.** For "suggest an outfit", ask for JSON (item ids and
  a reason) and render outfit cards that can be saved, instead of chat text.
- **Photo tagging.** Send one photo plus a schema and pre-fill the item form.
- **Export/import.** A zip of the database plus photos. This is the backup
  and the first sync story.
## Web build

A PWA for iPhone testers, published to GitHub Pages by
`.github/workflows/web.yml` whenever a release is made (see ADR 0006). Android stays the main
product; web-only code sits behind conditional imports
(`if (dart.library.js_interop)`) so it never reaches the APK.

- **Database:** `lib/core/database/platform/` picks the factory. The web uses
  `sqflite_common_ffi_web`: SQLite compiled to WebAssembly, saved in
  IndexedDB. Same schema and migrations as Android.
- **Photos:** `lib/core/photos/PhotoStore`. Android saves files and stores the
  path. The web stores bytes in the `photos` table (migration v4) and stores
  `photo:<id>`.
- **Binaries:** `web/sqlite3.wasm` and `web/sqflite_sw.js` aren't committed.
  `tool/build_web.sh` fetches the wasm matching `sqlite3` in `pubspec.lock`.
- **AI:** Anthropic needs the `anthropic-dangerous-direct-browser-access`
  header from a browser. The key sits in browser storage (weaker than the
  Android keystore), and the AI settings screen says so.
- **Data lives in one browser.** Safari may clear site data for a site that
  isn't added to the Home Screen and goes unused for a while. Testers should
  install it ("Add to Home Screen"). Export/import will be the backup.
