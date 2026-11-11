import 'dart:async';
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

    // The tree keeps the same shape whatever the values, so the app below
    // is never rebuilt from scratch while the keyboard moves.
    return Stack(
      textDirection: TextDirection.ltr,
      children: [
        MediaQuery(
          data: media.copyWith(
            viewInsets: media.viewInsets.copyWith(bottom: inset),
            // Same as Flutter does itself: the keyboard covers the home bar.
            padding: media.padding.copyWith(
              bottom: math.max(0, media.viewPadding.bottom - inset),
            ),
          ),
          child: widget.child,
        ),
        if (ref.watch(keyboardDebugProvider))
          Positioned(
            left: 8,
            right: 8,
            top: media.padding.top + 4,
            child: IgnorePointer(
              child: _Readout(
                source: _source!,
                area: area,
                viewSize: media.size,
                engineInset: engineInset,
                usedInset: inset,
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

/// The measurements, refreshed a few times a second because some of them
/// (page scroll, list scroll, field position) change without an event here.
class _Readout extends StatefulWidget {
  const _Readout({
    required this.source,
    required this.area,
    required this.viewSize,
    required this.engineInset,
    required this.usedInset,
  });

  final VisibleAreaSource source;
  final VisibleArea? area;
  final Size viewSize;
  final double engineInset;
  final double usedInset;

  @override
  State<_Readout> createState() => _ReadoutState();
}

class _ReadoutState extends State<_Readout> {
  late final Timer _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 300), (_) {
      widget.source.refresh();
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final area = widget.area;
    int r(double v) => v.round();
    final lines = [
      'view ${r(widget.viewSize.width)}x${r(widget.viewSize.height)}'
          '  engine inset ${r(widget.engineInset)}'
          '  used ${r(widget.usedInset)}',
      if (area != null) ...[
        'visual top ${r(area.top)} h ${r(area.height)}'
            '  scale ${area.scale.toStringAsFixed(2)}',
        'inner ${r(area.innerHeight)}  client ${r(area.clientHeight)}'
            '  ${area.standalone ? 'home screen' : 'browser tab'}',
        'page scroll ${r(area.pageScrollY)}  app top ${r(area.viewTop)}',
      ],
      ..._focusLines(r),
    ];
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

  /// Where the focused field is, and how far its list has scrolled.
  List<String> _focusLines(int Function(double) r) {
    final focus = FocusManager.instance.primaryFocus;
    final context = focus?.context;
    if (focus == null || context == null || !context.mounted) {
      return ['no field focused'];
    }
    final rect = focus.rect;
    final position = Scrollable.maybeOf(context)?.position;
    return [
      'field top ${r(rect.top)} bottom ${r(rect.bottom)}',
      if (position != null && position.hasContentDimensions)
        'list scroll ${r(position.pixels)} of ${r(position.maxScrollExtent)}'
            '  list h ${r(position.viewportDimension)}',
    ];
  }
}
