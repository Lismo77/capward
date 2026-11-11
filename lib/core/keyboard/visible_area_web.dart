import 'dart:js_interop';

import 'package:flutter/foundation.dart';
import 'package:web/web.dart' as web;

import 'visible_area.dart';

ValueListenable<VisibleArea?>? createVisibleAreaSource() {
  final viewport = web.window.visualViewport;
  if (viewport == null) return null;
  final source = ValueNotifier<VisibleArea?>(null);

  void update() {
    source.value = VisibleArea(
      top: viewport.offsetTop.toDouble(),
      height: viewport.height.toDouble(),
      scale: viewport.scale.toDouble(),
      innerHeight: web.window.innerHeight.toDouble(),
      clientHeight: web.document.documentElement?.clientHeight.toDouble() ?? 0,
      standalone: web.window.matchMedia('(display-mode: standalone)').matches,
    );
  }

  final listener = ((web.Event _) => update()).toJS;
  viewport.addEventListener('resize', listener);
  viewport.addEventListener('scroll', listener);
  update();
  // Lives for the whole app, so the listeners are never removed.
  return source;
}
