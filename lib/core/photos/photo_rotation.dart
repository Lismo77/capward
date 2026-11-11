import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

/// A re-encoded photo and the file extension that matches it.
typedef RotatedPhoto = ({Uint8List bytes, String extension});

/// Turns a photo a quarter turn clockwise.
///
/// Any EXIF orientation is applied first, so the result is the on-screen
/// image turned, not the raw sensor data. PNGs stay PNG (they may have
/// transparency, e.g. after background removal); everything else becomes a
/// JPEG. Throws [FormatException] if the bytes aren't an image.
RotatedPhoto rotatePhotoClockwise(Uint8List bytes) {
  final decoded = img.decodeImage(bytes);
  if (decoded == null) throw const FormatException('Not an image');
  final rotated = img.copyRotate(img.bakeOrientation(decoded), angle: 90);
  final isPng = img.findDecoderForData(bytes) is img.PngDecoder;
  return isPng
      ? (bytes: img.encodePng(rotated), extension: '.png')
      : (bytes: img.encodeJpg(rotated, quality: 90), extension: '.jpg');
}

/// [rotatePhotoClockwise] off the UI thread where the platform allows it.
Future<RotatedPhoto> rotatePhotoClockwiseInBackground(Uint8List bytes) =>
    compute(rotatePhotoClockwise, bytes);
