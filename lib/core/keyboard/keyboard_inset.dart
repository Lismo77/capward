/// Gaps smaller than this are browser rounding or toolbar wobble, not a
/// keyboard. Even a hardware keyboard's accessory bar is taller.
const minKeyboardInset = 24.0;

/// How much of the bottom of the app the keyboard hides, in logical pixels.
///
/// Installed iPhone web apps don't always tell Flutter the keyboard is up, so
/// [engineInset] can be 0 while the keyboard covers the screen. The browser
/// still knows what's visible: anything below [visibleBottom] is hidden. Take
/// whichever is bigger so this only ever helps.
///
/// Returns [engineInset] while the page is zoomed, because the sums below
/// assume one CSS pixel is one logical pixel.
double effectiveBottomInset({
  required double viewHeight,
  required double engineInset,
  required double visibleBottom,
  required double scale,
}) {
  if ((scale - 1).abs() > 0.01) return engineInset;
  final hidden = viewHeight - visibleBottom;
  if (hidden < minKeyboardInset) return engineInset;
  return hidden > engineInset ? hidden : engineInset;
}
