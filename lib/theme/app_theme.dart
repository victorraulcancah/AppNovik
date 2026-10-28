import 'package:flutter/material.dart';

class AppTheme {
  /// Color semilla provisional: aún no hay identidad de marca definida para Novik.
  static const Color primary = Color(0xFF1E3A8A);

  static final ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    colorSchemeSeed: primary,
    scaffoldBackgroundColor: Colors.white,
    appBarTheme: const AppBarTheme(elevation: 0),
  );
}
