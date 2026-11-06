import 'package:flutter/material.dart';

import '../../../wardrobe/domain/item.dart';
import '../../../wardrobe/presentation/widgets/item_thumbnail.dart';

/// Up to four item thumbnails tiled to fill the space. Pass items already
/// sorted with orderForDisplay.
class OutfitCollage extends StatelessWidget {
  const OutfitCollage({super.key, required this.items, this.iconSize = 28});

  final List<Item> items;
  final double iconSize;

  static const _gap = 2.0;

  @override
  Widget build(BuildContext context) {
    final shown = items.take(4).toList();
    if (shown.isEmpty) {
      final scheme = Theme.of(context).colorScheme;
      return ColoredBox(
        color: scheme.surfaceContainerHighest,
        child: Center(
          child: Icon(Icons.style_outlined, size: 40, color: scheme.outline),
        ),
      );
    }

    Widget tile(int i) =>
        Expanded(child: ItemThumbnail(item: shown[i], iconSize: iconSize));
    Widget row(List<Widget> children) =>
        Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: children);
    Widget column(List<Widget> children) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch, children: children);
    const hGap = SizedBox(width: _gap);
    const vGap = SizedBox(height: _gap);

    return switch (shown.length) {
      1 => row([tile(0)]),
      2 => row([tile(0), hGap, tile(1)]),
      3 => row([
          tile(0),
          hGap,
          Expanded(child: column([tile(1), vGap, tile(2)])),
        ]),
      _ => column([
          Expanded(child: row([tile(0), hGap, tile(1)])),
          vGap,
          Expanded(child: row([tile(2), hGap, tile(3)])),
        ]),
    };
  }
}
