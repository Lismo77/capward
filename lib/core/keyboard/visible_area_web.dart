import 'dart:js_interop';

import 'package:flutter/foundation.dart';
import 'package:web/web.dart' as web;

import 'visible_area.dart';

VisibleAreaSource? createVisibleAreaSource() {
  final viewport = web.window.visualViewport;
  if (viewport == null) return null;
  return _WebSource(viewport);
}

class _WebSource extends ValueNotifier<VisibleArea?>
    implements VisibleAreaSource {
  _WebSource(this._viewport) : super(null) {
    final listener = ((web.Event _) => refresh()).toJS;
    _viewport.addEventListener('resize', listener);
    _viewport.addEventListener('scroll', listener);
    // Lives for the whole app, so the listeners are never removed.
    refresh();
  }

  final web.VisualViewport _viewport;

  @override
  void refresh() {
    final flutterView = web.document.querySelector('flutter-view');
    value = VisibleArea(
      top: _viewport.offsetTop.toDouble(),
      height: _viewport.height.toDouble(),
      scale: _viewport.scale.toDouble(),
      innerHeight: web.window.innerHeight.toDouble(),
      clientHeight: web.document.documentElement?.clientHeight.toDouble() ?? 0,
      standalone: web.window.matchMedia('(display-mode: standalone)').matches,
      pageScrollY: web.window.scrollY.toDouble(),
      viewTop: flutterView?.getBoundingClientRect().top.toDouble() ?? 0,
    );
  }
}
