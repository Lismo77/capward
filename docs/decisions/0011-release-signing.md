# 11. Sign releases with our own long-term key

Date: 2026-11-11 · Status: accepted

## Context
Android only installs an update if it is signed with the same key as the
installed app. Until now release builds were signed with the debug key,
which differs per machine, and releases didn't include an APK at all, so
testers outside the developer's laptop couldn't install the app.

F-Droid normally builds and signs apps with its own key. If the build is
reproducible, it can instead publish the developer-signed APK, so users can
move between GitHub releases and F-Droid without reinstalling.

## Decision
- Releases are signed with one long-term key (RSA 4096, PKCS12, alias
  `gansey`, valid about 27 years), created and kept by the maintainer.
- The keystore and its password live in a password manager plus an offline
  copy. They are never committed, and never shared with tools or assistants.
- CI gets the key from three repository secrets: `ANDROID_KEYSTORE_BASE64`,
  `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_ALIAS`.
- Every release attaches a universal signed APK and its SHA-256 checksum to
  the GitHub release (`.github/workflows/android.yml`), so testers can
  install it directly or through Obtainium.
- Two guards stop a debug-signed APK from being published: Gradle fails
  when `ANDROID_REQUIRE_RELEASE_KEY=true` and no key is set, and the
  workflow rejects an APK whose certificate is the Android debug one.
- Local release builds read the key from `android/key.properties`
  (git-ignored) and fall back to the debug key without it.

## Consequences
- Losing the key or its password means no existing install can ever be
  updated again. The backups are the most important part of this decision.
- Aim for reproducible builds before submitting to F-Droid, so it can ship
  this same signature. Otherwise users switching to F-Droid reinstall once.
- The universal APK is about 65 MB because it bundles three CPU
  architectures. Per-architecture APKs (about a third of the size each) can
  be added later if size becomes a complaint.
