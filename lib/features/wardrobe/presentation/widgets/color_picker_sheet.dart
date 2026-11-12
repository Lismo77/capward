import 'package:flutter/material.dart';

import '../../../../core/widgets/palette_bar.dart';
import '../../domain/item.dart';

/// Lets the user tick any number of preset colours. Returns the ticked
/// names in pick order (those in [selected] first), or null if dismissed.
Future<List<String>?> showColorPickerSheet(
  BuildContext context, {
  List<String> selected = const [],
}) {
  // Otherwise the last text field (e.g. price) gets focus back when the
  // sheet closes, and the form jumps to it with the keyboard up.
  FocusManager.instance.primaryFocus?.unfocus();
  return showModalBottomSheet<List<String>>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (context) => _ColorPickerSheet(initial: selected),
  );
}

class _ColorPickerSheet extends StatefulWidget {
  const _ColorPickerSheet({required this.initial});

  final List<String> initial;

  @override
  State<_ColorPickerSheet> createState() => _ColorPickerSheetState();
}

class _ColorPickerSheetState extends State<_ColorPickerSheet> {
  late final List<String> _picked = [
    ...{...widget.initial}
  ];

  void _toggle(String name) => setState(() {
        if (!_picked.remove(name)) _picked.add(name);
      });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child:
                      Text('Pick colours', style: theme.textTheme.titleMedium),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(context, _picked),
                  child: const Text('Done'),
                ),
              ],
            ),
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
                  final on = _picked.contains(preset.name);
                  return Semantics(
                    selected: on,
                    button: true,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: () => _toggle(preset.name),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Stack(
                            alignment: Alignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(3),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    width: 2,
                                    color: on
                                        ? scheme.primary
                                        : Colors.transparent,
                                  ),
                                ),
                                child: ColorDot(color: preset.value, size: 36),
                              ),
                              if (on)
                                Container(
                                  decoration: BoxDecoration(
                                    color: scheme.primary,
                                    shape: BoxShape.circle,
                                  ),
                                  padding: const EdgeInsets.all(2),
                                  child: Icon(Icons.check,
                                      size: 14, color: scheme.onPrimary),
                                ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            preset.label,
                            style: on
                                ? theme.textTheme.bodySmall?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: scheme.primary)
                                : theme.textTheme.bodySmall,
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
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
