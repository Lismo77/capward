import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'keyboard_inset.dart';
import 'visible_area.dart';

/// Shows a small readout of the keyboard measurements over the app. Web only,
/// for checking [KeyboardInsetFix] on a real iPhone.
final keyboardDebugProvider = StateProvider<bool>((ref) => false);

/// Whether this build can measure the visible area itself (the web).
final canMeasureKeyboard = kIsWeb;

/// Keeps text fields above the keyboard in the installed iPhone web app.
///
/// There, Flutter is sometimes never told the keyboard is up, so screens lay
/// out behind it. This measures what the browser actually shows and passes
/// the hidden part down as the keyboard inset, which Scaffold and bottom
/// sheets already make room for. Elsewhere it changes nothing.
class KeyboardInsetFix extends ConsumerStatefulWidget {
  const KeyboardInsetFix({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<KeyboardInsetFix> createState() => _KeyboardInsetFixState();
}

class _KeyboardInsetFixState extends ConsumerState<KeyboardInsetFix> {
  static final _source = createVisibleAreaSource();
  double _lastApplied = 0;

  @override
  Widget build(BuildContext context) {
    final source = _source;
    if (source == null) return widget.child;
    return ValueListenableBuilder<VisibleArea?>(
      valueListenable: source,
      builder: (context, area, _) => _build(context, area),
    );
  }

  Widget _build(BuildContext context, VisibleArea? area) {
    final media = MediaQuery.of(context);
    final engineInset = media.viewInsets.bottom;
    final applyFix = defaultTargetPlatform == TargetPlatform.iOS;
    final inset = area == null || !applyFix
        ? engineInset
        : effectiveBottomInset(
            viewHeight: media.size.height,
            engineInset: engineInset,
            visibleBottom: area.bottom,
            scale: area.scale,
          );

    if (inset > _lastApplied && inset > engineInset) _revealFocusedField();
    _lastApplied = inset;

    Widget child = widget.child;
    if (inset != engineInset) {
      child = MediaQuery(
        data: media.copyWith(
          viewInsets: media.viewInsets.copyWith(bottom: inset),
          // Same as Flutter does itself: the keyboard covers the home bar.
          padding: media.padding.copyWith(
            bottom: math.max(0, media.viewPadding.bottom - inset),
          ),
        ),
        child: child,
      );
    }

    if (!ref.watch(keyboardDebugProvider)) return child;
    return Stack(
      textDirection: TextDirection.ltr,
      children: [
        child,
        Positioned(
          left: 8,
          right: 8,
          top: media.padding.top + 4,
          child: IgnorePointer(
            child: _Readout(
              lines: [
                'view ${media.size.width.round()}x${media.size.height.round()}'
                    '  engine inset ${engineInset.round()}'
                    '  used ${inset.round()}',
                if (area != null)
                  'visual top ${area.top.round()} h ${area.height.round()}'
                      '  scale ${area.scale.toStringAsFixed(2)}',
                if (area != null)
                  'inner ${area.innerHeight.round()}'
                      '  client ${area.clientHeight.round()}'
                      '  ${area.standalone ? 'home screen' : 'browser tab'}',
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// Flutter only scrolls the caret into view when it hears about the
  /// keyboard itself. When this widget is the one making room, do it here.
  void _revealFocusedField() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final focused = FocusManager.instance.primaryFocus?.context;
      if (focused == null || !focused.mounted) return;
      Scrollable.ensureVisible(
        focused,
        duration: const Duration(milliseconds: 150),
        alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtEnd,
      );
    });
  }
}

class _Readout extends StatelessWidget {
  const _Readout({required this.lines});

  final List<String> lines;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: const Color(0xDD000000),
        borderRadius: BorderRadius.circular(6),
      ),
      child: DefaultTextStyle(
        style: const TextStyle(
          color: Color(0xFFFFFFFF),
          fontSize: 12,
          fontFamily: 'monospace',
          height: 1.3,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [for (final l in lines) Text(l)],
        ),
      ),
    );
  }
}
