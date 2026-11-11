import 'package:flutter_test/flutter_test.dart';
import 'package:gansey/core/keyboard/keyboard_inset.dart';

void main() {
  double inset({
    double viewHeight = 800,
    double engineInset = 0,
    double visibleBottom = 800,
    double scale = 1,
  }) =>
      effectiveBottomInset(
        viewHeight: viewHeight,
        engineInset: engineInset,
        visibleBottom: visibleBottom,
        scale: scale,
      );

  test('no keyboard: nothing hidden', () {
    expect(inset(), 0);
  });

  test('keyboard the engine missed: uses the hidden part', () {
    expect(inset(visibleBottom: 500), 300);
  });

  test('engine already reports the keyboard: keeps its value', () {
    expect(inset(engineInset: 300, visibleBottom: 500), 300);
  });

  test('engine under-reports: uses the larger hidden part', () {
    expect(inset(engineInset: 100, visibleBottom: 500), 300);
  });

  test('view already shrunk to fit above the keyboard: no extra inset', () {
    expect(inset(viewHeight: 500, visibleBottom: 500), 0);
  });

  test('visible area taller than the view (toolbar collapsed): no inset', () {
    expect(inset(visibleBottom: 840), 0);
  });

  test('small gaps are ignored', () {
    expect(inset(visibleBottom: 790), 0);
  });

  test('zoomed page: trusts the engine', () {
    expect(inset(engineInset: 0, visibleBottom: 500, scale: 1.45), 0);
  });
}
