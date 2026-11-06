import 'dart:io';

import 'package:flutter/material.dart';

import '../../../../core/widgets/palette_bar.dart';
import '../../domain/item.dart';

/// The item's photo, or - when there is none - a tile in the item's main
/// colour with a category icon. Fills whatever space it is given.
class ItemThumbnail extends StatelessWidget {
  const ItemThumbnail({super.key, required this.item, this.iconSize = 40});

  final Item item;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    final placeholder = _ColourTile(item: item, iconSize: iconSize);
    final path = item.photoPath;
    if (path == null) return placeholder;
    return Image.file(
      File(path),
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) => placeholder,
    );
  }
}

class _ColourTile extends StatelessWidget {
  const _ColourTile({required this.item, required this.iconSize});

  final Item item;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = item.colors.isEmpty
        ? scheme.surfaceContainerHighest
        : rgbToColor(item.colors.first.value);
    final iconColor =
        ThemeData.estimateBrightnessForColor(color) == Brightness.dark
            ? Colors.white70
            : Colors.black54;
    return ColoredBox(
      color: color,
      child: Center(
        child:
            Icon(categoryIcon(item.category), size: iconSize, color: iconColor),
      ),
    );
  }
}

IconData categoryIcon(ItemCategory category) => switch (category) {
      ItemCategory.shoes => Icons.directions_walk,
      ItemCategory.bag => Icons.work_outline,
      ItemCategory.accessory => Icons.watch_outlined,
      ItemCategory.outerwear => Icons.dry_cleaning_outlined,
      _ => Icons.checkroom,
    };
