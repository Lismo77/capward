import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'photo_store.dart';

PhotoStore createPhotoStore(DatabaseGetter db) => _FilePhotoStore();

/// Keeps item photos in the app's private documents folder, so they survive
/// even if the user deletes the original from their gallery.
class _FilePhotoStore implements PhotoStore {
  /// Number added to file names so several photos saved in the same
  /// millisecond (a backup restore) don't collide.
  int _counter = 0;

  Future<String> _newPath(String ext) async {
    final docs = await getApplicationDocumentsDirectory();
    final photos = Directory(p.join(docs.path, 'photos'));
    await photos.create(recursive: true);
    final stamp = DateTime.now().millisecondsSinceEpoch;
    return p.join(photos.path, '${stamp}_${_counter++}$ext');
  }

  @override
  Future<String> save(XFile file) async {
    final ext =
        p.extension(file.path).isEmpty ? '.jpg' : p.extension(file.path);
    final dest = await _newPath(ext);
    await file.saveTo(dest);
    return dest;
  }

  @override
  Future<String> saveBytes(Uint8List bytes, {String extension = '.jpg'}) async {
    final dest = await _newPath(extension.isEmpty ? '.jpg' : extension);
    await File(dest).writeAsBytes(bytes, flush: true);
    return dest;
  }

  @override
  Future<void> delete(String ref) async {
    final file = File(ref);
    if (await file.exists()) await file.delete();
  }

  @override
  Future<Uint8List?> read(String ref) async {
    final file = File(ref);
    return await file.exists() ? file.readAsBytes() : null;
  }

  @override
  Widget image(
    String ref, {
    BoxFit fit = BoxFit.cover,
    required WidgetBuilder fallback,
  }) =>
      Image.file(
        File(ref),
        fit: fit,
        errorBuilder: (context, error, stackTrace) => fallback(context),
      );
}
