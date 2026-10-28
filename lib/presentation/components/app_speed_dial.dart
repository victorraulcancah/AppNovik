import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

class AppSpeedDialAction {
  final String label;
  final IconData icon;
  final VoidCallback? onPressed;

  /// La acción principal de la vista (crear): se distingue por color.
  final bool primary;

  const AppSpeedDialAction({
    required this.label,
    required this.icon,
    required this.onPressed,
    this.primary = false,
  });
}

/// Botón redondo "Acciones" que flota abajo a la izquierda de la vista. Al
/// tocarlo oscurece la pantalla y despliega hacia arriba todas las acciones
/// (crear, plantilla, subir, exportar...), cada una con su etiqueta. Con una
/// sola acción se muestra como un botón flotante normal con su nombre.
///
/// Colócalo con `Positioned(left: 16, bottom: 16)` dentro de un `Stack`, o en
/// `Scaffold.floatingActionButton` con `FloatingActionButtonLocation.startFloat`.
/// Deja espacio al final de la lista (`AppCardList.bottomPadding`, por ejemplo
/// 96) para que no tape el último elemento.
class AppSpeedDial extends StatefulWidget {
  final List<AppSpeedDialAction> actions;
  final String label;

  const AppSpeedDial({super.key, required this.actions, this.label = 'Acciones'});

  @override
  State<AppSpeedDial> createState() => _AppSpeedDialState();
}

class _AppSpeedDialState extends State<AppSpeedDial> {
  static const _size = 64.0;
  static const _miniSize = 40.0;

  final _portal = OverlayPortalController();
  final _link = LayerLink();

  /// Botón redondo con ícono y, debajo, el nombre.
  Widget _roundButton(BuildContext context, IconData icon, VoidCallback onPressed) {
    return Material(
      color: AppTheme.strongFill(Theme.of(context).brightness),
      elevation: 6,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onPressed,
        child: SizedBox(
          width: _size,
          height: _size,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: Colors.white, size: 24),
              Text(
                widget.label,
                maxLines: 1,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _overlay(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final fill = AppTheme.strongFill(theme.brightness);
    final animate = !MediaQuery.disableAnimationsOf(context);

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: animate ? 0 : 1, end: 1),
      duration: const Duration(milliseconds: 160),
      builder: (context, t, child) => Opacity(opacity: t, child: child),
      child: Material(
        type: MaterialType.transparency,
        child: Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _portal.hide,
                child: const ColoredBox(color: Color(0x99000000)),
              ),
            ),
            CompositedTransformFollower(
              link: _link,
              targetAnchor: Alignment.bottomLeft,
              followerAnchor: Alignment.bottomLeft,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final a in widget.actions)
                    Padding(
                      // Centra el círculo pequeño sobre el botón principal.
                      padding: const EdgeInsets.only(
                        left: (_size - _miniSize) / 2,
                        bottom: 12,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: _miniSize,
                            height: _miniSize,
                            child: FloatingActionButton.small(
                              heroTag: null,
                              tooltip: a.label,
                              backgroundColor:
                                  a.primary ? fill : scheme.surfaceContainerHighest,
                              foregroundColor:
                                  a.primary ? Colors.white : scheme.onSurface,
                              onPressed: () {
                                _portal.hide();
                                a.onPressed?.call();
                              },
                              child: Icon(a.icon),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Material(
                            color: scheme.surfaceContainerHighest,
                            elevation: 2,
                            borderRadius: BorderRadius.circular(8),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              child: Text(a.label, style: theme.textTheme.labelLarge),
                            ),
                          ),
                        ],
                      ),
                    ),
                  _roundButton(context, Icons.close, _portal.hide),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.actions.length == 1) {
      final only = widget.actions.single;
      return FloatingActionButton.extended(
        heroTag: null,
        backgroundColor: AppTheme.strongFill(Theme.of(context).brightness),
        foregroundColor: Colors.white,
        onPressed: only.onPressed,
        icon: Icon(only.icon),
        label: Text(only.label),
      );
    }

    return CompositedTransformTarget(
      link: _link,
      child: OverlayPortal(
        controller: _portal,
        overlayChildBuilder: _overlay,
        child: _roundButton(context, Icons.apps, _portal.show),
      ),
    );
  }
}
