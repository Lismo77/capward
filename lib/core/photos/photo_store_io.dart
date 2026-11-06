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
  @override
  Future<String> save(XFile file) async {
    final docs = await getApplicationDocumentsDirectory();
    final photos = Directory(p.join(docs.path, 'photos'));
    await photos.create(recursive: true);
    final ext =
        p.extension(file.path).isEmpty ? '.jpg' : p.extension(file.path);
    final dest = p.join(
      photos.path,
      '${DateTime.now().millisecondsSinceEpoch}$ext',
    );
    await file.saveTo(dest);
    return dest;
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
