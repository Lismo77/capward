import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:sqflite/sqflite.dart';

import '../database/app_database.dart';
import 'photo_store_io.dart' if (dart.library.js_interop) 'photo_store_web.dart'
    as platform;

/// Where item photos live. Items store the string [save] returns.
///
/// - Android: a file in the app's documents folder; the string is its path.
/// - Web: bytes in the `photos` table; the string is `photo:<id>`.
abstract class PhotoStore {
  /// Copies a picked photo into app storage and returns its reference.
  Future<String> save(XFile file);

  /// The photo's bytes, or null if it's gone.
  Future<Uint8List?> read(String ref);

  /// Shows the photo, or [fallback] if it can't be loaded.
  Widget image(
    String ref, {
    BoxFit fit = BoxFit.cover,
    required WidgetBuilder fallback,
  });
}

final photoStoreProvider = Provider<PhotoStore>((ref) {
  return platform.createPhotoStore(() => ref.read(databaseProvider.future));
});

/// An item photo from [photoStoreProvider].
class StoredPhoto extends ConsumerWidget {
  const StoredPhoto(
    this.photoRef, {
    super.key,
    this.fit = BoxFit.cover,
    required this.fallback,
  });

  final String photoRef;
  final BoxFit fit;
  final WidgetBuilder fallback;

  @override
  Widget build(BuildContext context, WidgetRef ref) => ref
      .watch(photoStoreProvider)
      .image(photoRef, fit: fit, fallback: fallback);
}

typedef DatabaseGetter = Future<Database> Function();
