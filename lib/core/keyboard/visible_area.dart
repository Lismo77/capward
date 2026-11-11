import 'package:flutter/foundation.dart';

import 'visible_area_stub.dart'
    if (dart.library.js_interop) 'visible_area_web.dart' as platform;

/// What the browser says is actually on screen, in CSS pixels (the same as
/// Flutter's logical pixels on the web).
@immutable
class VisibleArea {
  const VisibleArea({
    required this.top,
    required this.height,
    required this.scale,
    required this.innerHeight,
    required this.clientHeight,
    required this.standalone,
    this.pageScrollY = 0,
    this.viewTop = 0,
  });

  /// `visualViewport.offsetTop`: how far the browser has panned the page up.
  final double top;

  /// `visualViewport.height`: the part not covered by the keyboard.
  final double height;

  /// `visualViewport.scale`: pinch or auto zoom. 1 when not zoomed.
  final double scale;

  final double innerHeight;
  final double clientHeight;

  /// Opened from the home screen rather than in a browser tab.
  final bool standalone;

  /// `window.scrollY`: whether the browser scrolled the page itself.
  final double pageScrollY;

  /// Where Flutter's `<flutter-view>` element sits on screen. Not 0 means
  /// the browser moved the whole app.
  final double viewTop;

  double get bottom => top + height;
}

/// Updates whenever the visible area changes (keyboard, rotation, zoom).
abstract class VisibleAreaSource implements ValueListenable<VisibleArea?> {
  /// Measures again now, for values the browser sends no event for.
  void refresh();
}

/// Null off the web, where the engine already reports the keyboard properly.
VisibleAreaSource? createVisibleAreaSource() =>
    platform.createVisibleAreaSource();
