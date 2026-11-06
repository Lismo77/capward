import 'package:flutter/material.dart';

import '../../../../core/widgets/palette_bar.dart';
import '../../domain/item.dart';

Future<ItemColor?> showColorPickerSheet(BuildContext context) =>
    showModalBottomSheet<ItemColor>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => const _ColorPickerSheet(),
    );

class _ColorPickerSheet extends StatelessWidget {
  const _ColorPickerSheet();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Pick a colour', style: theme.textTheme.titleMedium),
            const SizedBox(height: 12),
            Flexible(
              child: GridView.builder(
                shrinkWrap: true,
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 76,
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 4,
                  childAspectRatio: 0.8,
                ),
                itemCount: colorPresets.length,
                itemBuilder: (context, i) {
                  final preset = colorPresets[i];
                  return InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: () => Navigator.pop(context, preset),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ColorDot(color: preset.value, size: 36),
                        const SizedBox(height: 4),
                        Text(
                          preset.name,
                          style: theme.textTheme.bodySmall,
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
