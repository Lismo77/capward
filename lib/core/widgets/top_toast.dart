import 'dart:async';

import 'package:flutter/material.dart';

OverlayEntry? _current;

/// A small pill near the top of the screen that fades out on its own, e.g.
/// "Fri 6 Nov · Outfit logged ✓". Lighter than a snackbar and doesn't cover
/// the bottom navigation.
void showTopToast(
  BuildContext context,
  String message, {
  IconData icon = Icons.check_circle,
}) {
  final overlay = Overlay.of(context, rootOverlay: true);
  _current?.remove();
  late final OverlayEntry entry;
  entry = OverlayEntry(
    builder: (context) => _TopToast(
      message: message,
      icon: icon,
      onDone: () {
        if (_current == entry) _current = null;
        if (entry.mounted) entry.remove();
      },
    ),
  );
  _current = entry;
  overlay.insert(entry);
}

class _TopToast extends StatefulWidget {
  const _TopToast({
    required this.message,
    required this.icon,
    required this.onDone,
  });

  final String message;
  final IconData icon;
  final VoidCallback onDone;

  @override
  State<_TopToast> createState() => _TopToastState();
}

class _TopToastState extends State<_TopToast> {
  static const _fade = Duration(milliseconds: 200);
  bool _visible = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _visible = true);
    });
    _timer = Timer(const Duration(milliseconds: 2000), () {
      if (!mounted) return;
      setState(() => _visible = false);
      _timer = Timer(_fade, widget.onDone);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final top = MediaQuery.paddingOf(context).top + kToolbarHeight + 8;
    return Positioned(
      top: top,
      left: 16,
      right: 16,
      child: IgnorePointer(
        child: Center(
          child: AnimatedOpacity(
            opacity: _visible ? 1 : 0,
            duration: _fade,
            child: Material(
              color: scheme.inverseSurface,
              elevation: 3,
              borderRadius: BorderRadius.circular(20),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(
                        widget.message,
                        style: TextStyle(color: scheme.onInverseSurface),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(widget.icon, size: 18, color: scheme.inversePrimary),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
