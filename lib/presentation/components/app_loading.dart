import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

/// Pantalla de carga inicial: fondo azul pizarra de la marca y un indicador
/// claro, sin el color de acción.
class AppLoadingScreen extends StatelessWidget {
  const AppLoadingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: AppTheme.brandDark,
      body: Center(
        child: SizedBox(
          width: 32,
          height: 32,
          child: CircularProgressIndicator(
            strokeWidth: 3,
            color: AppTheme.navMuted,
          ),
        ),
      ),
    );
  }
}
