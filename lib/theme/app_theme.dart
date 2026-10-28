import 'package:flutter/material.dart';

class AppTheme {
  /// Colores provisionales: aún no hay identidad de marca definida para Novik.
  /// Naranja de acción (como el botón del login web) sobre azul pizarra oscuro.
  static const Color primary = Color(0xFFEA580C);
  static const Color dark = Color(0xFF0F172A);
  static const Color darkAlt = Color(0xFF1E293B);
  static const Color fieldFill = Color(0xFFF1F5F9);
  static const Color textMuted = Color(0xFF64748B);

  static const double radius = 14;

  static OutlineInputBorder _border([Color color = Colors.transparent, double width = 1]) =>
      OutlineInputBorder(
        borderRadius: BorderRadius.circular(radius),
        borderSide: BorderSide(color: color, width: width),
      );

  static final ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(seedColor: primary, primary: primary),
    scaffoldBackgroundColor: Colors.white,
    appBarTheme: const AppBarTheme(elevation: 0),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: fieldFill,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      border: _border(),
      enabledBorder: _border(),
      focusedBorder: _border(primary, 1.6),
      errorBorder: _border(Colors.red.shade400),
      focusedErrorBorder: _border(Colors.red.shade400, 1.6),
      labelStyle: const TextStyle(color: textMuted),
      prefixIconColor: textMuted,
      suffixIconColor: textMuted,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(54),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius),
        ),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
    ),
  );
}
