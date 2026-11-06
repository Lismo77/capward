import 'dart:io';

import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Keeps item photos in the app's private documents folder, so they survive
/// even if the user deletes the original from their gallery.
class PhotoStore {
  static Future<String> save(XFile file) async {
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
}
