import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';

/// A Gansey backup is a zip:
///
/// ```
/// manifest.json         format, versions, export time, row counts
/// data/<table>.json     one JSON array of rows per table
/// photos/<item id>.jpg  item photos; items.photo_path points here
/// ```
///
/// Plain JSON rather than a copy of the SQLite file, so the same backup
/// works on Android and the web (which store photos differently) and can be
/// opened and read by hand.
const backupFormat = 'gansey-backup';

/// Format names written by earlier versions, which import the same way.
/// The app was called Capward before 0.6 (ADR 0010).
const legacyBackupFormats = {'capward-backup'};

/// Bump when the zip layout changes in a way older apps can't read.
const backupFormatVersion = 1;

/// Tables in a backup, parents before children (the insert order).
/// The web-only `photos` table isn't listed: photos travel as files.
const backupTables = [
  'items',
  'outfits',
  'outfit_items',
  'capsules',
  'capsule_items',
  'wear_log',
  'wear_log_items',
  'style_profile',
];

const _manifestName = 'manifest.json';
const _photosDir = 'photos/';

typedef BackupRow = Map<String, Object?>;

class Backup {
  Backup({
    required this.schemaVersion,
    required this.exportedAt,
    this.appVersion,
    required this.tables,
    this.photos = const {},
  });

  /// Database schema version (number of migrations) it was exported from.
  final int schemaVersion;
  final DateTime exportedAt;
  final String? appVersion;
  final Map<String, List<BackupRow>> tables;

  /// Zip path ("photos/12.jpg") to image bytes.
  final Map<String, Uint8List> photos;

  int count(String table) => tables[table]?.length ?? 0;
}

/// A file that can't be imported. [message] is shown to the user.
class BackupException implements Exception {
  const BackupException(this.message);

  final String message;

  @override
  String toString() => 'BackupException: $message';
}

Uint8List encodeBackup(Backup backup) {
  final archive = Archive();
  void addJson(String name, Object value) => archive.addFile(ArchiveFile.string(
      name, const JsonEncoder.withIndent('  ').convert(value)));

  addJson(_manifestName, {
    'format': backupFormat,
    'formatVersion': backupFormatVersion,
    'schemaVersion': backup.schemaVersion,
    'appVersion': backup.appVersion,
    'exportedAt': backup.exportedAt.toUtc().toIso8601String(),
    'counts': {for (final t in backupTables) t: backup.count(t)},
    'photos': backup.photos.length,
  });
  for (final table in backupTables) {
    addJson('data/$table.json', backup.tables[table] ?? const <BackupRow>[]);
  }
  for (final MapEntry(key: name, value: bytes) in backup.photos.entries) {
    // Photos are already compressed; zipping them again only costs time.
    archive.addFile(
        ArchiveFile.bytes(name, bytes)..compression = CompressionType.none);
  }
  return ZipEncoder().encodeBytes(archive);
}

/// Reads a backup made by [encodeBackup]. Throws [BackupException] if the
/// file isn't a backup, is damaged, or comes from a newer app.
Backup decodeBackup(Uint8List bytes, {required int currentSchemaVersion}) {
  const notBackup = BackupException("This file isn't a Gansey backup.");
  const tooNew = BackupException('This backup was made by a newer version of '
      'Gansey. Update the app, then try again.');

  final Archive archive;
  try {
    archive = ZipDecoder().decodeBytes(bytes);
  } catch (_) {
    throw notBackup;
  }

  Object? readJson(String name) {
    final file = archive.findFile(name);
    if (file == null) return null;
    try {
      return jsonDecode(utf8.decode(file.content));
    } catch (_) {
      throw BackupException('The backup is damaged ($name is unreadable).');
    }
  }

  final manifest = readJson(_manifestName);
  if (manifest is! Map) throw notBackup;
  final format = manifest['format'];
  if (format != backupFormat && !legacyBackupFormats.contains(format)) {
    throw notBackup;
  }
  final formatVersion = manifest['formatVersion'];
  final schemaVersion = manifest['schemaVersion'];
  if (formatVersion is! int || schemaVersion is! int) throw notBackup;
  if (formatVersion > backupFormatVersion ||
      schemaVersion > currentSchemaVersion) {
    throw tooNew;
  }

  final tables = <String, List<BackupRow>>{};
  for (final table in backupTables) {
    final rows = readJson('data/$table.json');
    if (rows == null) continue; // older backups may lack newer tables
    if (rows is! List || rows.any((r) => r is! Map)) {
      throw BackupException('The backup is damaged (bad $table data).');
    }
    tables[table] = [for (final r in rows) BackupRow.from(r as Map)];
  }

  return Backup(
    schemaVersion: schemaVersion,
    exportedAt:
        DateTime.tryParse(manifest['exportedAt'] as String? ?? '')?.toLocal() ??
            DateTime.fromMillisecondsSinceEpoch(0),
    appVersion: manifest['appVersion'] as String?,
    tables: tables,
    photos: {
      for (final f in archive.files)
        if (f.isFile && f.name.startsWith(_photosDir)) f.name: f.content,
    },
  );
}

/// ".jpg", ".png" or ".webp", guessed from the file's first bytes.
String photoExtension(Uint8List bytes) {
  bool startsWith(List<int> sig, [int offset = 0]) =>
      bytes.length >= offset + sig.length &&
      [for (var i = 0; i < sig.length; i++) bytes[offset + i] == sig[i]]
          .every((b) => b);
  if (startsWith([0x89, 0x50, 0x4E, 0x47])) return '.png';
  if (startsWith(ascii.encode('RIFF')) && startsWith(ascii.encode('WEBP'), 8)) {
    return '.webp';
  }
  return '.jpg';
}

/// "gansey-backup-2026-11-06.zip"
String backupFileName(DateTime now) {
  String two(int n) => n.toString().padLeft(2, '0');
  return 'gansey-backup-${now.year}-${two(now.month)}-${two(now.day)}.zip';
}
