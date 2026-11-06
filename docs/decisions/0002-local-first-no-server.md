# 2. Local-first, no app server

Date: 2026-11-05 · Status: accepted

## Context
The app must be free with no ads. Servers cost money, and they hold user data
that has to be protected.

## Decision
All data is stored on the device (SQLite plus a photos folder). No accounts.
AI requests go directly from the device to the provider the user picks.

## Consequences
- No running costs. Strong privacy story. F-Droid friendly.
- No built-in sync between devices. We'll start with export/import and later
  offer sync through storage the user controls.
