import 'package:flutter/material.dart';

class AppTheme {
  // A warm neutral - capsule wardrobes tend to be built around neutrals.
  static const _seed = Color(0xFF6B5B4B);

  static ThemeData light() => ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: _seed),
        useMaterial3: true,
      );

  static ThemeData dark() => ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: _seed,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      );
}
