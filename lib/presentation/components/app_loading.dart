import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import 'app_logo.dart';
import 'app_motion.dart';

/// Pantalla de carga inicial: fondo azul pizarra de la marca con el logo latiendo.
/// El logo queda en el mismo lugar y tamaño (96) que el de la pantalla de arranque
/// nativa, así el paso de una a otra no se nota.
class AppLoadingScreen extends StatelessWidget {
  const AppLoadingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.brandDark,
      body: Stack(
        alignment: Alignment.center,
        children: [
          const AppPulse(child: AppLogo(size: 96, showName: false)),
          Align(
            alignment: const Alignment(0, 0.45),
            child: AppEntrance(
              delay: const Duration(milliseconds: 400),
              child: const SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  color: AppTheme.navMuted,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
