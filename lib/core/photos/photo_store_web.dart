import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:image_picker/image_picker.dart';

import 'photo_store.dart';

PhotoStore createPhotoStore(DatabaseGetter db) => _DbPhotoStore(db);

/// Browsers have no file system to keep photos in, so they go in the
/// database (which the web build stores in IndexedDB).
class _DbPhotoStore implements PhotoStore {
  _DbPhotoStore(this._db);

  static const _prefix = 'photo:';

  final DatabaseGetter _db;

  /// Decoding is the slow part, but this saves a query per thumbnail too.
  final _cache = <String, Uint8List>{};

  @override
  Future<String> save(XFile file) async {
    final bytes = await file.readAsBytes();
    final db = await _db();
    final id = await db.insert('photos', {'bytes': bytes});
    final ref = '$_prefix$id';
    _cache[ref] = bytes;
    return ref;
  }

  @override
  Future<Uint8List?> read(String ref) async {
    final cached = _cache[ref];
    if (cached != null) return cached;
    final id = ref.startsWith(_prefix)
        ? int.tryParse(ref.substring(_prefix.length))
        : null;
    if (id == null) return null;
    final db = await _db();
    final rows = await db.query('photos',
        columns: ['bytes'], where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return null;
    final raw = rows.first['bytes'];
    final bytes = raw is Uint8List ? raw : Uint8List.fromList(raw as List<int>);
    return _cache[ref] = bytes;
  }

  @override
  Widget image(
    String ref, {
    BoxFit fit = BoxFit.cover,
    required WidgetBuilder fallback,
  }) {
    Widget show(Uint8List bytes) => Image.memory(
          bytes,
          fit: fit,
          gaplessPlayback: true,
          errorBuilder: (context, error, stackTrace) => fallback(context),
        );
    final cached = _cache[ref];
    if (cached != null) return show(cached);
    return FutureBuilder<Uint8List?>(
      future: read(ref),
      builder: (context, snap) =>
          snap.data == null ? fallback(context) : show(snap.data!),
    );
  }
}
