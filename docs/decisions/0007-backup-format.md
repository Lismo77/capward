# 7. Backups are a zip of JSON tables and photos

Date: 2026-11-06 · Status: accepted

## Context
All data lives on one device (or one browser). People need a backup, a way
to move to a new phone, and testers on the web version need protection
against Safari clearing site data. Photos are files on Android and database
rows on the web.

## Decision
A backup is a `.zip`:

- `manifest.json`: format name and version, schema version (number of
  migrations), app version, export time, row counts.
- `data/<table>.json`: every row of each table as a JSON array.
- `photos/<item id>.<ext>`: item photos; `items.photo_path` points here.

Import replaces everything (not a merge), in one database transaction.
Photos are saved before the transaction and deleted again if it fails; the
old photos are deleted only after it succeeds.

## Consequences
- The same backup moves between Android and the web, and can be read by
  hand. A raw SQLite copy couldn't, because photo references differ by
  platform.
- Old backups import into newer apps: migrations only add columns, and
  unknown or missing columns are handled (missing get defaults, unknown are
  dropped). Backups from a newer schema are refused with "update the app".
- If a migration ever renames or reshapes a column, import needs a matching
  conversion step keyed on the backup's schema version.
- Merging two wardrobes isn't supported. Ids are kept as-is so links between
  tables stay valid.
- The AI key and settings are not exported.
