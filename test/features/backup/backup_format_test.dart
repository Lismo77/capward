import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:capsule_wardrobe/features/backup/domain/backup_format.dart';
import 'package:flutter_test/flutter_test.dart';

final jpeg = Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xE0, 1, 2, 3]);

Backup sample({int schemaVersion = 4}) => Backup(
      schemaVersion: schemaVersion,
      exportedAt: DateTime.utc(2026, 11, 6, 12),
      appVersion: '0.2.0 (2)',
      tables: {
        'items': [
          {
            'id': 1,
            'name': 'Tee',
            'category': 'top',
            'photo_path': 'photos/1.jpg'
          },
          {'id': 2, 'name': 'Jeans', 'category': 'bottom', 'photo_path': null},
        ],
        'wear_log': [
          {'id': 1, 'worn_on': '2026-11-06', 'worn_at': null},
        ],
      },
      photos: {'photos/1.jpg': jpeg},
    );

Uint8List zipOf(Map<String, String> files) {
  final archive = Archive();
  files
      .forEach((name, text) => archive.addFile(ArchiveFile.string(name, text)));
  return ZipEncoder().encodeBytes(archive);
}

void main() {
  test('round trip keeps rows, photos and metadata', () {
    final back = decodeBackup(encodeBackup(sample()), currentSchemaVersion: 4);
    expect(back.schemaVersion, 4);
    expect(back.appVersion, '0.2.0 (2)');
    expect(back.exportedAt.toUtc(), DateTime.utc(2026, 11, 6, 12));
    expect(back.tables['items'], sample().tables['items']);
    expect(back.count('wear_log'), 1);
    expect(back.count('outfits'), 0, reason: 'empty tables are still written');
    expect(back.photos['photos/1.jpg'], jpeg);
  });

  test('a backup from an older schema is accepted', () {
    final back = decodeBackup(encodeBackup(sample(schemaVersion: 2)),
        currentSchemaVersion: 4);
    expect(back.schemaVersion, 2);
  });

  test('a backup from a newer app is refused', () {
    expect(
      () => decodeBackup(encodeBackup(sample(schemaVersion: 9)),
          currentSchemaVersion: 4),
      throwsA(isA<BackupException>()
          .having((e) => e.message, 'message', contains('newer version'))),
    );
  });

  test('files that are not backups are refused', () {
    final notBackup = throwsA(isA<BackupException>()
        .having((e) => e.message, 'message', contains("isn't a Capward")));
    expect(
        () => decodeBackup(Uint8List.fromList(utf8.encode('hello')),
            currentSchemaVersion: 4),
        notBackup);
    expect(
        () =>
            decodeBackup(zipOf({'readme.txt': 'hi'}), currentSchemaVersion: 4),
        notBackup);
    expect(
        () => decodeBackup(zipOf({'manifest.json': '{"format": "other"}'}),
            currentSchemaVersion: 4),
        notBackup);
  });

  test('damaged table data is reported', () {
    final bytes = zipOf({
      'manifest.json': jsonEncode(
          {'format': backupFormat, 'formatVersion': 1, 'schemaVersion': 4}),
      'data/items.json': '{not json',
    });
    expect(
      () => decodeBackup(bytes, currentSchemaVersion: 4),
      throwsA(isA<BackupException>()
          .having((e) => e.message, 'message', contains('damaged'))),
    );
  });

  test('photoExtension sniffs the format', () {
    expect(photoExtension(jpeg), '.jpg');
    expect(photoExtension(Uint8List.fromList([0x89, 0x50, 0x4E, 0x47, 0])),
        '.png');
    expect(
        photoExtension(Uint8List.fromList(
            [...ascii.encode('RIFF'), 0, 0, 0, 0, ...ascii.encode('WEBP')])),
        '.webp');
  });

  test('backupFileName', () {
    expect(
        backupFileName(DateTime(2026, 1, 9)), 'capward-backup-2026-01-09.zip');
  });
}
