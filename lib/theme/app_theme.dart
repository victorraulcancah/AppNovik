import 'package:flutter/material.dart';

/// Tema Material 3 de Novik: esquemas claro y oscuro con el naranja de acción
/// del login. El resto de la app usa roles de color (`colorScheme`).
class AppTheme {
  /// Naranja de acción (el del botón del login). Provisional hasta definir la marca.
  static const Color primary = Color(0xFFEA580C);

  /// Azul pizarra de la cabecera del login (igual en claro y oscuro).
  static const Color brandDark = Color(0xFF0F172A);
  static const Color brandDarkAlt = Color(0xFF1E293B);

  /// Navegación (barra inferior y riel): el azul pizarra de la marca, con
  /// íconos apagados y el destino activo en blanco sobre una píldora más clara.
  static const Color navIndicator = Color(0xFF334155);
  static const Color navMuted = Color(0xFF94A3B8);

  static const double radius = 14;

  static ThemeData get light => _build(Brightness.light);
  static ThemeData get dark => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final isLight = brightness == Brightness.light;
    final scheme = ColorScheme.fromSeed(
      seedColor: primary,
      brightness: brightness,
    ).copyWith(
      primary: primary,
      onPrimary: Colors.white,
      // Superficies en grises neutros: el naranja queda solo para las acciones.
      surface: isLight ? const Color(0xFFF4F4F5) : const Color(0xFF18181B),
      onSurface: isLight ? const Color(0xFF18181B) : const Color(0xFFFAFAFA),
      onSurfaceVariant:
          isLight ? const Color(0xFF52525B) : const Color(0xFFA1A1AA),
      surfaceContainerLowest:
          isLight ? const Color(0xFFFFFFFF) : const Color(0xFF0F0F11),
      surfaceContainerLow:
          isLight ? const Color(0xFFF4F4F5) : const Color(0xFF1F1F23),
      surfaceContainer:
          isLight ? const Color(0xFFEDEDEF) : const Color(0xFF27272A),
      surfaceContainerHigh:
          isLight ? const Color(0xFFE4E4E7) : const Color(0xFF2E2E32),
      surfaceContainerHighest:
          isLight ? const Color(0xFFD4D4D8) : const Color(0xFF3F3F46),
      outline: isLight ? const Color(0xFF71717A) : const Color(0xFF71717A),
      outlineVariant:
          isLight ? const Color(0xFFD4D4D8) : const Color(0xFF3F3F46),
      secondaryContainer:
          isLight ? const Color(0xFFE4E4E7) : const Color(0xFF3F3F46),
      onSecondaryContainer:
          isLight ? const Color(0xFF18181B) : const Color(0xFFFAFAFA),
      surfaceTint: Colors.transparent,
    );

    OutlineInputBorder border([Color color = Colors.transparent, double width = 1]) =>
        OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius),
          borderSide: BorderSide(color: color, width: width),
        );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: scheme.surface,
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        centerTitle: false,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerHigh,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        border: border(),
        enabledBorder: border(),
        focusedBorder: border(primary, 1.6),
        errorBorder: border(scheme.error),
        focusedErrorBorder: border(scheme.error, 1.6),
        prefixIconColor: scheme.onSurfaceVariant,
        suffixIconColor: scheme.onSurfaceVariant,
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
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: scheme.onSurfaceVariant,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: brandDark,
        surfaceTintColor: Colors.transparent,
        indicatorColor: navIndicator,
        height: 72,
        elevation: 0,
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            size: 24,
            color: states.contains(WidgetState.selected)
                ? Colors.white
                : navMuted,
          ),
        ),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            fontSize: 12,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w600
                : FontWeight.w500,
            color: states.contains(WidgetState.selected)
                ? Colors.white
                : navMuted,
          ),
        ),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: brandDark,
        indicatorColor: navIndicator,
        selectedIconTheme: const IconThemeData(color: Colors.white),
        unselectedIconTheme: const IconThemeData(color: navMuted),
        selectedLabelTextStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
        unselectedLabelTextStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: navMuted,
        ),
      ),
      listTileTheme: const ListTileThemeData(
        contentPadding: EdgeInsets.symmetric(horizontal: 16),
        minVerticalPadding: 12,
      ),
    );
  }
}
