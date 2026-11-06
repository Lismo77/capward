# Capward (working name) - notes for AI coding sessions

This project is built mostly by AI pair-programming. Write code directly; keep
explanations short.

## Product rules (don't break these)

1. **AI is optional.** Every feature must work fully by hand. AI only adds
   shortcuts (auto-fill, suggestions, chat). Code that uses AI must handle
   `aiClientProvider` returning `null`. When AI is off, AI buttons and screens
   are **hidden**, not greyed out. ("AI" here means the user's cloud or
   self-hosted model. Small on-device models, like background removal, are
   ordinary features.)
2. **Local-first, no app server.** Data stays on the device. AI calls go
   directly from the device to the user's chosen provider with their key.
3. **F-Droid compatible.** No Google Play Services, Firebase, ML Kit,
   proprietary analytics or crash reporting. Check a package's license and
   dependencies before adding it.
4. **Privacy by default.** Send the AI the least it needs: text metadata
   rather than photos, unless the feature is about a photo. Body details are
   only sent if the user has turned that on.
5. **Anti-consumption.** The app helps people wear what they own, not buy
   more. Suggestions use existing items first. Buying is framed as filling a
   real gap, never as browsing. No shopping links, no affiliate anything.
6. **Android comes first.** The F-Droid Android app is the main product. The
   web version (a PWA for iPhone testers) is secondary. If something works
   badly on the web, the web version gets the simpler option or goes without
   the feature, never the other way round. Keep web-only code behind
   conditional imports so it never reaches the Android build, and don't
   commit binary files (e.g. `sqlite3.wasm`). Fetch them at web build time.

## Stack

- Flutter, Android-first (web later). Dart 3.
- State: `flutter_riverpod` 2.x, no code generation.
- Routing: `go_router`.
- Storage: `sqflite` with plain SQL. Migrations in
  `lib/core/database/migrations.dart`. Append only - never edit a shipped one.
- AI: `lib/ai/`. `AiClient` interface with two adapters,
  `AnthropicClient` (Messages API, raw HTTP) and `OpenAiCompatibleClient`
  (chat completions).

## Layout

```
lib/
  ai/               provider-neutral AI client, adapters, settings
  core/             database, router, theme, shared widgets
  features/<name>/
    domain/         plain Dart models + pure logic (unit-tested)
    data/           repositories + Riverpod providers
    presentation/   screens and widgets
test/               mirrors lib/
docs/               ARCHITECTURE, ROADMAP, decisions/ (ADRs)
```

## Commands

```bash
flutter pub get
dart format lib test   # before committing
flutter analyze        # must be clean before committing
flutter test
flutter run
```

## Conventions

- Put pure logic (prompt building, stats, parsing) in `domain/` and test it.
- After a write, `ref.invalidate(...)` the provider that lists the data.
- Record notable decisions as a new ADR in `docs/decisions/`.
- Conventional commits (`feat:`, `fix:`, `docs:`...). Release tags `vX.Y.Z`,
  which F-Droid builds from.
