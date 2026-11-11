import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/app_version.dart';
import '../../../core/database/migrations.dart';
import '../../../core/format.dart';
import '../../outfits/data/outfit_repository.dart';
import '../../style_profile/data/style_profile_repository.dart';
import '../../wardrobe/data/item_repository.dart';
import '../../wear_log/data/wear_log_repository.dart';
import '../data/backup_service.dart';
import '../domain/backup_format.dart';

const _kLastExport = 'backup.lastExport';

/// When the last backup was exported from this device, or null.
final lastBackupProvider = FutureProvider<DateTime?>((ref) async {
  final prefs = await SharedPreferences.getInstance();
  final value = prefs.getString(_kLastExport);
  return value == null ? null : DateTime.tryParse(value);
});

/// Builds a backup and lets the user save it (Android: a "Save as" dialog;
/// web: a download).
Future<void> exportBackup(BuildContext context) async {
  final container = ProviderScope.containerOf(context, listen: false);
  final messenger = ScaffoldMessenger.of(context);
  final now = DateTime.now();

  final close = _showBusy(context, 'Preparing backup…');
  final Uint8List bytes;
  try {
    final service = await container.read(backupServiceProvider.future);
    final version =
        await container.read(appVersionProvider.future).catchError((_) => '');
    bytes = encodeBackup(await service.export(
        appVersion: version.isEmpty ? null : version, now: now));
  } catch (e) {
    close();
    messenger.showSnackBar(SnackBar(content: Text('Backup failed: $e')));
    return;
  }
  close();

  final Uri? saved;
  try {
    saved = await FilePicker.saveFile(
      dialogTitle: 'Save backup',
      fileName: backupFileName(now),
      mimeType: 'application/zip',
      bytes: bytes,
    );
  } catch (e) {
    messenger.showSnackBar(SnackBar(content: Text('Could not save: $e')));
    return;
  }
  // On the web it's a download that can't be cancelled from here; elsewhere
  // null means the user cancelled the dialog.
  if (!kIsWeb && saved == null) return;

  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(_kLastExport, now.toIso8601String());
  container.invalidate(lastBackupProvider);
  const done = kIsWeb ? 'Backup downloaded' : 'Backup saved';
  messenger.showSnackBar(const SnackBar(content: Text(done)));
}

/// Picks a backup file, shows what's in it, and replaces the wardrobe with
/// it once the user confirms.
Future<void> importBackup(BuildContext context) async {
  final container = ProviderScope.containerOf(context, listen: false);
  final messenger = ScaffoldMessenger.of(context);

  final Uint8List bytes;
  try {
    final picked = await FilePicker.pickFile(
      dialogTitle: 'Choose a backup',
      type: FileType.custom,
      allowedExtensions: const ['zip'],
    );
    if (picked == null) return; // cancelled
    bytes = await picked.readAsBytes();
  } catch (e) {
    if (context.mounted) await _showError(context, "Couldn't read that file.");
    return;
  }
  if (!context.mounted) return;

  final Backup backup;
  try {
    backup = decodeBackup(bytes, currentSchemaVersion: migrations.length);
  } on BackupException catch (e) {
    if (context.mounted) await _showError(context, e.message);
    return;
  }
  if (!context.mounted) return;

  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Replace everything with this backup?'),
      content: Text('${_describe(backup)}\n\n'
          'Your current items, outfits, wear history and style profile will '
          'be replaced. Export a backup first if you might want them back.'),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel')),
        TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Replace')),
      ],
    ),
  );
  if (confirmed != true || !context.mounted) return;

  final close = _showBusy(context, 'Restoring backup…');
  try {
    final service = await container.read(backupServiceProvider.future);
    await service.restore(backup);
  } catch (e) {
    close();
    final message = e is BackupException ? e.message : 'Import failed: $e';
    if (context.mounted) await _showError(context, message);
    return;
  }
  close();
  container
    ..invalidate(itemsProvider)
    ..invalidate(outfitsProvider)
    ..invalidate(wearLogProvider)
    ..invalidate(styleProfileProvider);
  messenger.showSnackBar(const SnackBar(content: Text('Backup restored')));
}

/// "Backup from 6 Nov 2026 (Gansey 0.2.0): 23 items, 4 outfits, ..."
String _describe(Backup b) {
  String n(int count, String one, [String? many]) =>
      '$count ${count == 1 ? one : many ?? '${one}s'}';
  final date = friendlyDate(b.exportedAt, today: DateTime.now());
  final from = [
    'Backup from ${date == 'Today' || date == 'Yesterday' ? date.toLowerCase() : date}',
    if (b.appVersion != null) '(Gansey ${b.appVersion})',
  ].join(' ');
  return '$from: ${[
    n(b.count('items'), 'item'),
    n(b.count('outfits'), 'outfit'),
    n(b.count('wear_log'), 'wear log entry', 'wear log entries'),
    n(b.photos.length, 'photo'),
  ].join(', ')}.';
}

/// A blocking "working..." dialog. Returns a function that closes it.
VoidCallback _showBusy(BuildContext context, String message) {
  final navigator = Navigator.of(context, rootNavigator: true);
  showDialog<void>(
    context: context,
    useRootNavigator: true,
    barrierDismissible: false,
    builder: (context) => PopScope(
      canPop: false,
      child: AlertDialog(
        content: Row(
          children: [
            const SizedBox.square(
                dimension: 24,
                child: CircularProgressIndicator(strokeWidth: 3)),
            const SizedBox(width: 20),
            Expanded(child: Text(message)),
          ],
        ),
      ),
    ),
  );
  return navigator.pop;
}

Future<void> _showError(BuildContext context, String message) =>
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Couldn't import"),
        content: Text(message),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context), child: const Text('OK')),
        ],
      ),
    );
