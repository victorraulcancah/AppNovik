import 'package:flutter/material.dart';

/// Bloque de una pantalla: título con ícono y su contenido en una tarjeta con borde.
class AppSection extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;

  /// Algo a la derecha del título (una leyenda, un contador).
  final Widget? trailing;

  const AppSection({
    super.key,
    required this.title,
    required this.icon,
    required this.child,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Row(
            children: [
              Icon(icon, size: 18, color: scheme.onSurfaceVariant),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              ?trailing,
            ],
          ),
        ),
        // Un Material (no un Container con color) para que las listas, interruptores y casillas
        // de dentro puedan dibujar su fondo y su efecto al tocarlos.
        Material(
          color: scheme.surfaceContainerLowest,
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: scheme.outlineVariant),
          ),
          child: Padding(padding: const EdgeInsets.all(14), child: child),
        ),
      ],
    );
  }
}
