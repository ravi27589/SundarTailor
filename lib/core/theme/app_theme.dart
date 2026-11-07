import 'package:flutter/material.dart';

ThemeData buildAppTheme() {
  const seed = Color(0xFF2563EB);

  return ThemeData(
    colorScheme: ColorScheme.fromSeed(seedColor: seed),
    useMaterial3: true,
    appBarTheme: const AppBarTheme(centerTitle: false),
    inputDecorationTheme: const InputDecorationTheme(
      border: OutlineInputBorder(),
    ),
    cardTheme: const CardThemeData(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(8)),
        side: BorderSide(color: Color(0xFFE5E7EB)),
      ),
    ),
  );
}

class StatusColors {
  const StatusColors._();

  static const booked = Color(0xFF2563EB);
  static const drying = Color(0xFF0891B2);
  static const cutting = Color(0xFF0F766E);
  static const stitching = Color(0xFFF97316);
  static const finishing = Color(0xFFB45309);
  static const ironing = Color(0xFF475569);
  static const trial = Color(0xFF7C3AED);
  static const ready = Color(0xFF9333EA);
  static const delivered = Color(0xFF16A34A);
  static const cancelled = Color(0xFFDC2626);
}
