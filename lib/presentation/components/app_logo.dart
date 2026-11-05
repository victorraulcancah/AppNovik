import 'package:flutter/material.dart';
import '../../core/constants/app_constants.dart';

/// Marca de Novik: la "N" blanca sobre un cuadrado redondeado naranja con degradado
/// (la misma del ícono de la app) y, opcionalmente, el nombre debajo.
class AppLogo extends StatelessWidget {
  final double size;
  final bool showName;

  /// Color del nombre; sobre fondo oscuro se pasa blanco.
  final Color? nameColor;

  const AppLogo({
    super.key,
    this.size = 64,
    this.showName = true,
    this.nameColor,
  });

  static const _top = Color(0xFFFB7832);
  static const _bottom = Color(0xFFD64A06);

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Semantics(
      label: AppConstants.appName,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: size,
            height: size,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [_top, _bottom],
              ),
              borderRadius: BorderRadius.circular(size * 0.3),
              boxShadow: [
                BoxShadow(
                  color: _bottom.withValues(alpha: 0.35),
                  blurRadius: size * 0.3,
                  offset: Offset(0, size * 0.1),
                ),
              ],
            ),
            child: Text(
              AppConstants.appName.substring(0, 1),
              style: TextStyle(
                color: Colors.white,
                fontSize: size * 0.55,
                fontWeight: FontWeight.w800,
                height: 1,
              ),
            ),
          ),
          if (showName) ...[
            const SizedBox(height: 14),
            Text(
              AppConstants.appName,
              style: TextStyle(
                color: nameColor ?? scheme.onSurface,
                fontSize: 28,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
