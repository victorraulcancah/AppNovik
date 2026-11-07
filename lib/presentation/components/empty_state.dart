import 'package:flutter/material.dart';
import 'app_illustrations.dart';
import 'app_motion.dart';

/// Estado vacío o de error: una ilustración, título, explicación y una acción opcional. Entra con
/// un fundido.
///
/// La ilustración se elige sola según el [icon]: la nube tachada (`Icons.cloud_off_outlined`, que
/// usan todas las pantallas para "no se pudo cargar") o [error] dibujan el error; los candados,
/// el "sin acceso"; la bandeja de entrada y la búsqueda, "sin resultados"; y cualquier otro ícono
/// dibuja la caja abierta con ese ícono como insignia. [illustration] fuerza una en concreto.
class AppEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? message;
  final Widget? action;
  final bool error;

  /// Ilustración a dibujar; por defecto se deduce del [icon].
  final AppIllustrationKind? illustration;

  const AppEmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.action,
    this.error = false,
    this.illustration,
  });

  static final _errorIcons = {
    Icons.cloud_off_outlined,
    Icons.cloud_off,
    Icons.wifi_off,
    Icons.wifi_off_rounded,
    Icons.signal_wifi_off,
  };

  static final _lockedIcons = {
    Icons.lock,
    Icons.lock_outline,
    Icons.lock_outlined,
    Icons.lock_person,
    Icons.lock_person_outlined,
  };

  static final _emptyIcons = {
    Icons.inbox,
    Icons.inbox_outlined,
    Icons.search,
    Icons.search_off,
    Icons.search_off_outlined,
  };

  /// La ilustración que corresponde a un ícono (y si el ícono ya queda dicho por el dibujo).
  @visibleForTesting
  static AppIllustrationKind kindFor(IconData icon, {bool error = false}) {
    if (error || _errorIcons.contains(icon)) return AppIllustrationKind.error;
    if (_lockedIcons.contains(icon)) return AppIllustrationKind.locked;
    if (_emptyIcons.contains(icon)) return AppIllustrationKind.empty;
    return AppIllustrationKind.generic;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final kind = illustration ?? kindFor(icon, error: error);
    // El dibujo ya dice "error", "candado" o "sin resultados"; en los demás casos el ícono
    // propio de la pantalla (almacén, ajustes…) va como insignia sobre la caja.
    final showBadge =
        illustration == null && kind == AppIllustrationKind.generic;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: AppEntrance(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 140,
                  child: Stack(
                    clipBehavior: Clip.none,
                    alignment: Alignment.center,
                    children: [
                      AppIllustration(kind: kind),
                      if (showBadge)
                        Positioned(
                          right: 0,
                          bottom: 2,
                          child: Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: scheme.surfaceContainerLowest,
                              border: Border.all(color: scheme.outlineVariant),
                            ),
                            child: Icon(icon, size: 19, color: scheme.primary),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
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
