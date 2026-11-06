# 4. SQLite with plain SQL (sqflite)

Date: 2026-11-05 · Status: accepted

## Context
The data is relational: items, outfits, capsules and wear logs, with
many-to-many links, and stats like cost per wear. Options were sqflite with
raw SQL, drift (typed queries through code generation), or a NoSQL store.

## Decision
Use `sqflite` with hand-written SQL and versioned migrations in
`lib/core/database/migrations.dart`.

## Consequences
- The schema and stats queries are plain SQL and easy to read. No code
  generation step.
- Fewer compile-time checks on queries, so repository tests matter.
- Web needs `sqflite_common_ffi_web` later. If the queries grow complex, we
  can revisit drift.
