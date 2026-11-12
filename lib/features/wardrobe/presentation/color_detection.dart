import 'dart:typed_data';
import 'dart:ui' as ui;

import '../domain/color_extraction.dart';
import '../domain/item.dart';

/// Detects an item's main colours from its photo, on the device. Fast enough
/// to run right after a photo is taken: the image is decoded at 80px wide.
Future<List<ItemColor>> detectItemColors(Uint8List bytes) async {
  final codec = await ui.instantiateImageCodec(bytes, targetWidth: 80);
  final frame = await codec.getNextFrame();
  final image = frame.image;
  try {
    final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    if (data == null) return const [];
    final pixels =
        data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
    final found = <String, ItemColor>{};
    for (final rgb in dominantColors(pixels, image.width, image.height)) {
      // The standard swatch, not the photo's shade: lighting and cameras
      // often get the shade wrong, and a picked colour should look the same.
      final color = nearestPreset(rgb);
      found.putIfAbsent(color.name, () => color); // one swatch per name
    }
    return found.values.toList();
  } finally {
    image.dispose();
    codec.dispose();
  }
}
