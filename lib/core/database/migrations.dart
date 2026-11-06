/// Schema migrations, applied in order. Index 0 is database version 1.
///
/// Rules:
/// - Never edit a migration that has shipped in a release. Add a new one.
/// - Each migration is a list of single SQL statements (sqflite runs one
///   statement per execute call).
const List<List<String>> migrations = [
  _v1,
  _v2,
  _v3,
];

/// v3: the time an outfit or item was put on (local ISO date-time), so a day
/// can hold several outfits in order. Null on rows logged before v3.
const _v3 = <String>[
  'ALTER TABLE wear_log ADD COLUMN worn_at TEXT',
];

/// v2: real colour swatches. JSON list of {"name": "navy", "hex": "#1F2A44"}.
/// The old `colors` column stays as a comma-separated list of the names, so
/// plain SQL queries like "how many navy items" still work.
const _v2 = <String>[
  "ALTER TABLE items ADD COLUMN swatches TEXT NOT NULL DEFAULT '[]'",
];

const _v1 = <String>[
  '''
  CREATE TABLE items (
    id                   INTEGER PRIMARY KEY AUTOINCREMENT,
    name                 TEXT    NOT NULL,
    category             TEXT    NOT NULL,
    colors               TEXT    NOT NULL DEFAULT '',  -- comma-separated
    material             TEXT,
    seasons              TEXT    NOT NULL DEFAULT '',  -- comma-separated
    formality            INTEGER NOT NULL DEFAULT 3 CHECK (formality BETWEEN 1 AND 5),
    brand                TEXT,
    purchase_price_cents INTEGER,
    purchase_date        TEXT,                         -- ISO date
    photo_path           TEXT,
    status               TEXT    NOT NULL DEFAULT 'active',
    notes                TEXT,
    created_at           TEXT    NOT NULL DEFAULT (datetime('now')),
    updated_at           TEXT    NOT NULL DEFAULT (datetime('now'))
  )
  ''',
  'CREATE INDEX idx_items_category ON items(category)',
  '''
  CREATE TABLE outfits (
    id         INTEGER PRIMARY KEY AUTOINCREMENT,
    name       TEXT NOT NULL,
    occasion   TEXT,
    notes      TEXT,
    source     TEXT NOT NULL DEFAULT 'user',  -- 'user' or 'ai'
    created_at TEXT NOT NULL DEFAULT (datetime('now'))
  )
  ''',
  '''
  CREATE TABLE outfit_items (
    outfit_id INTEGER NOT NULL REFERENCES outfits(id) ON DELETE CASCADE,
    item_id   INTEGER NOT NULL REFERENCES items(id)   ON DELETE CASCADE,
    PRIMARY KEY (outfit_id, item_id)
  )
  ''',
  '''
  CREATE TABLE capsules (
    id          INTEGER PRIMARY KEY AUTOINCREMENT,
    name        TEXT NOT NULL,
    description TEXT,
    season      TEXT,
    starts_on   TEXT,
    ends_on     TEXT,
    target_size INTEGER,
    created_at  TEXT NOT NULL DEFAULT (datetime('now'))
  )
  ''',
  '''
  CREATE TABLE capsule_items (
    capsule_id INTEGER NOT NULL REFERENCES capsules(id) ON DELETE CASCADE,
    item_id    INTEGER NOT NULL REFERENCES items(id)    ON DELETE CASCADE,
    PRIMARY KEY (capsule_id, item_id)
  )
  ''',
  '''
  CREATE TABLE wear_log (
    id         INTEGER PRIMARY KEY AUTOINCREMENT,
    worn_on    TEXT NOT NULL,  -- ISO date
    outfit_id  INTEGER REFERENCES outfits(id) ON DELETE SET NULL,
    notes      TEXT,
    created_at TEXT NOT NULL DEFAULT (datetime('now'))
  )
  ''',
  'CREATE INDEX idx_wear_log_worn_on ON wear_log(worn_on)',
  '''
  CREATE TABLE wear_log_items (
    wear_id INTEGER NOT NULL REFERENCES wear_log(id) ON DELETE CASCADE,
    item_id INTEGER NOT NULL REFERENCES items(id)    ON DELETE CASCADE,
    PRIMARY KEY (wear_id, item_id)
  )
  ''',
  '''
  CREATE TABLE style_profile (
    id          INTEGER PRIMARY KEY CHECK (id = 1),  -- single row
    style_words TEXT,
    palette     TEXT,
    silhouettes TEXT,
    avoid       TEXT,
    lifestyle   TEXT,
    notes       TEXT,
    updated_at  TEXT
  )
  ''',
  'INSERT INTO style_profile (id) VALUES (1)',
  '''
  CREATE VIEW item_wear_stats AS
  SELECT
    i.id                    AS item_id,
    COUNT(wli.wear_id)      AS times_worn,
    MAX(w.worn_on)          AS last_worn_on,
    CASE
      WHEN COUNT(wli.wear_id) > 0 AND i.purchase_price_cents IS NOT NULL
      THEN i.purchase_price_cents / COUNT(wli.wear_id)
    END                     AS cost_per_wear_cents
  FROM items i
  LEFT JOIN wear_log_items wli ON wli.item_id = i.id
  LEFT JOIN wear_log w         ON w.id = wli.wear_id
  GROUP BY i.id
  ''',
];
