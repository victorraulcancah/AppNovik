import 'package:flutter/material.dart';
import 'app_motion.dart';

/// Estado vacío o de error: ícono dentro de un círculo de color, título, explicación y una
/// acción opcional. Entra con un fundido.
///
/// Con [error] (o con el ícono de nube tachada que usan todas las pantallas para "no se pudo
/// cargar") el círculo va en los colores de error.
class AppEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? message;
  final Widget? action;
  final bool error;

  const AppEmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.action,
    this.error = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isError = error || icon == Icons.cloud_off_outlined;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: AppEntrance(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 88,
                  height: 88,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isError
                        ? scheme.errorContainer.withValues(alpha: 0.6)
                        : scheme.primary.withValues(alpha: 0.10),
                  ),
                  child: Icon(
                    icon,
                    size: 40,
                    color: isError ? scheme.error : scheme.primary,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (message != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    message!,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
                if (action != null) ...[const SizedBox(height: 24), action!],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
