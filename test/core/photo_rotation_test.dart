import 'dart:typed_data';

import 'package:gansey/core/photos/photo_rotation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

/// A 2x1 image: red on the left, blue on the right.
img.Image redBlue() => img.Image(width: 2, height: 1)
  ..setPixelRgb(0, 0, 255, 0, 0)
  ..setPixelRgb(1, 0, 0, 0, 255);

void main() {
  test('turns a PNG clockwise and keeps it a PNG', () {
    final out = rotatePhotoClockwise(img.encodePng(redBlue()));
    expect(out.extension, '.png');

    final rotated = img.decodePng(out.bytes)!;
    expect((rotated.width, rotated.height), (1, 2));
    // Clockwise: what was on the left ends up on top.
    expect(rotated.getPixel(0, 0).r, 255);
    expect(rotated.getPixel(0, 1).b, 255);
  });

  test('re-encodes other formats as JPEG with the sides swapped', () {
    final photo = img.Image(width: 40, height: 20);
    final out = rotatePhotoClockwise(img.encodeJpg(photo));
    expect(out.extension, '.jpg');
    final rotated = img.decodeJpg(out.bytes)!;
    expect((rotated.width, rotated.height), (20, 40));
  });

  test('applies EXIF orientation before turning', () {
    // Stored 40x20 but tagged "rotate 90° clockwise to display", so it shows
    // as 20x40. One more clockwise turn makes it 40x20 on screen.
    final photo = img.Image(width: 40, height: 20)
      ..exif.imageIfd.orientation = 6;
    final out = rotatePhotoClockwise(img.encodeJpg(photo));
    final rotated = img.decodeJpg(out.bytes)!;
    expect((rotated.width, rotated.height), (40, 20));
  });

  test('rejects bytes that are not an image', () {
    expect(() => rotatePhotoClockwise(Uint8List.fromList([1, 2, 3])),
        throwsFormatException);
  });
}
