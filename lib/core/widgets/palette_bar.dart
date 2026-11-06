import 'package:flutter/material.dart';

Color rgbToColor(int rgb) => Color(0xFF000000 | rgb);

/// A horizontal strip of colour segments, e.g. an outfit's palette.
class PaletteBar extends StatelessWidget {
  const PaletteBar({
    super.key,
    required this.colors,
    this.height = 10,
  });

  /// 0xRRGGBB values, shown left to right.
  final List<int> colors;
  final double height;

  @override
  Widget build(BuildContext context) {
    if (colors.isEmpty) return SizedBox(height: height);
    final radius = BorderRadius.circular(height / 2);
    return DecoratedBox(
      // A hairline border keeps white and cream segments visible.
      position: DecorationPosition.foreground,
      decoration: BoxDecoration(
        borderRadius: radius,
        border: Border.all(
          color: Theme.of(context).colorScheme.outlineVariant,
          width: 0.5,
        ),
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: SizedBox(
          height: height,
          child: Row(
            children: [
              for (final c in colors)
                Expanded(child: ColoredBox(color: rgbToColor(c))),
            ],
          ),
        ),
      ),
    );
  }
}

/// A single round swatch.
class ColorDot extends StatelessWidget {
  const ColorDot({super.key, required this.color, this.size = 20});

  /// 0xRRGGBB
  final int color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: rgbToColor(color),
        shape: BoxShape.circle,
        border: Border.all(
          color: Theme.of(context).colorScheme.outlineVariant,
          width: 0.5,
        ),
      ),
    );
  }
}
