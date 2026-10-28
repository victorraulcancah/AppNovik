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

/// Botón flotante "Acciones" que se despliega hacia arriba con todas las
/// acciones de la vista (crear, plantilla, subir, exportar...), cada una con
/// su etiqueta. Con una sola acción se muestra como un botón flotante normal.
/// Va en `Scaffold.floatingActionButton`; deja espacio al final de la lista
/// (`AppCardList.bottomPadding`) para que no tape el último elemento.
class AppSpeedDial extends StatefulWidget {
  final List<AppSpeedDialAction> actions;
  final String label;

  const AppSpeedDial({super.key, required this.actions, this.label = 'Acciones'});

  @override
  State<AppSpeedDial> createState() => _AppSpeedDialState();
}

class _AppSpeedDialState extends State<AppSpeedDial> {
  final _portal = OverlayPortalController();
  final _link = LayerLink();

  Widget _overlay(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final fill = AppTheme.strongFill(Theme.of(context).brightness);
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
              targetAnchor: Alignment.bottomRight,
              followerAnchor: Alignment.bottomRight,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  for (final a in widget.actions)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Material(
                            color: scheme.surfaceContainerHighest,
                            elevation: 2,
                            borderRadius: BorderRadius.circular(8),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              child: Text(
                                a.label,
                                style: Theme.of(context).textTheme.labelLarge,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          FloatingActionButton.small(
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
                        ],
                      ),
                    ),
                  FloatingActionButton.extended(
                    heroTag: null,
                    backgroundColor: fill,
                    foregroundColor: Colors.white,
                    onPressed: _portal.hide,
                    icon: const Icon(Icons.close),
                    label: Text(widget.label),
                  ),
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
    final fill = AppTheme.strongFill(Theme.of(context).brightness);

    if (widget.actions.length == 1) {
      final only = widget.actions.single;
      return FloatingActionButton.extended(
        heroTag: null,
        backgroundColor: fill,
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
        child: FloatingActionButton.extended(
          heroTag: null,
          backgroundColor: fill,
          foregroundColor: Colors.white,
          onPressed: _portal.show,
          icon: const Icon(Icons.apps),
          label: Text(widget.label),
        ),
      ),
    );
  }
}
