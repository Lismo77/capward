import 'dart:typed_data';

import 'item_color.dart';

const _mergeDistance = 60.0;

/// Finds up to [maxColors] dominant colours (0xRRGGBB) in an RGBA image.
///
/// Clothing is usually in the middle of the photo, so only the centre is
/// sampled for colours. If one colour dominates the border, it is treated as
/// background and dropped, unless that would leave too little behind (e.g. a
/// white shirt photographed on a white bed).
List<int> dominantColors(
  Uint8List rgba,
  int width,
  int height, {
  int maxColors = 3,
  double minShare = 0.08,
}) {
  final centre = _Histogram();
  final border = _Histogram();
  final x0 = (width * 0.15).floor(), x1 = (width * 0.85).ceil();
  final y0 = (height * 0.15).floor(), y1 = (height * 0.85).ceil();

  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      final i = (y * width + x) * 4;
      if (i + 3 >= rgba.length) break;
      if (rgba[i + 3] < 128) continue; // transparent
      final rgb = (rgba[i] << 16) | (rgba[i + 1] << 8) | rgba[i + 2];
      final inCentre = x >= x0 && x < x1 && y >= y0 && y < y1;
      (inCentre ? centre : border).add(rgb);
    }
  }

  var result = centre.clusters().where((c) => c.share >= minShare).toList();
  if (result.isEmpty) return const [];

  final borderClusters = border.clusters();
  if (borderClusters.isNotEmpty && borderClusters.first.share > 0.5) {
    final background = borderClusters.first.color;
    final rest = result
        .where((c) => colorDistance(c.color, background) > _mergeDistance)
        .toList();
    final restShare = rest.fold<double>(0, (sum, c) => sum + c.share);
    if (rest.isNotEmpty && restShare >= 0.25) result = rest;
  }

  return result.take(maxColors).map((c) => c.color).toList();
}

class _Cluster {
  _Cluster(this.r, this.g, this.b, this.count);

  int r, g, b, count; // channel sums and pixel count
  double share = 0;

  int get color => ((r ~/ count) << 16) | ((g ~/ count) << 8) | (b ~/ count);
}

class _Histogram {
  final _buckets = <int, _Cluster>{};
  var _total = 0;

  void add(int rgb) {
    // 4 bits per channel -> 4096 buckets.
    final key = ((rgb >> 20) & 0xF) << 8 |
        ((rgb >> 12) & 0xF) << 4 |
        ((rgb >> 4) & 0xF);
    final c = _buckets.putIfAbsent(key, () => _Cluster(0, 0, 0, 0));
    c.r += (rgb >> 16) & 0xFF;
    c.g += (rgb >> 8) & 0xFF;
    c.b += rgb & 0xFF;
    c.count++;
    _total++;
  }

  /// Buckets merged into clusters of similar colour, largest first.
  List<_Cluster> clusters() {
    if (_total == 0) return [];
    final sorted = _buckets.values.toList()
      ..sort((a, b) => b.count.compareTo(a.count));
    final merged = <_Cluster>[];
    for (final bucket in sorted) {
      _Cluster? target;
      for (final m in merged) {
        if (colorDistance(m.color, bucket.color) < _mergeDistance) {
          target = m;
          break;
        }
      }
      if (target == null) {
        merged.add(_Cluster(bucket.r, bucket.g, bucket.b, bucket.count));
      } else {
        target
          ..r += bucket.r
          ..g += bucket.g
          ..b += bucket.b
          ..count += bucket.count;
      }
    }
    for (final m in merged) {
      m.share = m.count / _total;
    }
    merged.sort((a, b) => b.count.compareTo(a.count));
    return merged;
  }
}
