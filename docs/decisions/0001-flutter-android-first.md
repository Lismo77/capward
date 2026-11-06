# 1. Flutter, Android-first

Date: 2026-11-05 · Status: accepted

## Context
We want an Android app now and possibly a web version later, from one
codebase, distributed on F-Droid.

## Decision
Use Flutter. Build for Android first and treat web as a later target.

## Consequences
- One Dart codebase. Many Flutter apps already ship on F-Droid.
- Some Android-only APIs (`dart:io` files, secure storage) are fine for now.
  They need abstractions before the web build.
- Rejected: React Native/Expo (Google dependencies cause F-Droid trouble),
  native Kotlin (web would need a second codebase), Capacitor (less native
  on the main platform).
