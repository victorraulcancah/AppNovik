import 'dart:math' as math;
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

/// Botón redondo "Acciones" que flota abajo a la derecha de la vista. Al
/// tocarlo oscurece la pantalla y despliega las acciones (crear, plantilla,
/// subir, exportar...) en abanico: un arco de cuarto de círculo desde arriba
/// del botón hasta su izquierda, cada una con su etiqueta a la izquierda. Con
/// una sola acción se muestra como un botón flotante normal con su nombre.
///
/// Colócalo con `Positioned(right: 16, bottom: 16)` dentro de un `Stack`, o en
/// `Scaffold.floatingActionButton`. Deja espacio al final de la lista
/// (`AppCardList.bottomPadding`, por ejemplo 96) para que no tape el último
/// elemento.
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

  /// Distancia del centro del botón al centro de cada acción.
  static const _radius = 140.0;

  final _portal = OverlayPortalController();
  final _buttonKey = GlobalKey();

  /// Posición del botón en la pantalla, para abrir el abanico desde ahí.
  Rect? _buttonRect() {
    final box = _buttonKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.attached) return null;
    return box.localToGlobal(Offset.zero) & box.size;
  }

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

  /// Círculo de una acción y su etiqueta, en su lugar del arco.
  List<Widget> _item(
    BuildContext context,
    int index,
    Offset center,
    double screenWidth,
  ) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final a = widget.actions[index];
    final count = widget.actions.length;

    // De 90° (justo arriba del botón) a 180° (a su izquierda).
    final degrees = count == 1 ? 90.0 : 90 + index * 90 / (count - 1);
    final radians = degrees * math.pi / 180;
    final c = center + Offset(_radius * math.cos(radians), -_radius * math.sin(radians));

    return [
      Positioned(
        left: c.dx - _miniSize / 2,
        top: c.dy - _miniSize / 2,
        width: _miniSize,
        height: _miniSize,
        child: FloatingActionButton.small(
          heroTag: null,
          tooltip: a.label,
          backgroundColor:
              a.primary ? AppTheme.strongFill(theme.brightness) : scheme.surfaceContainerHighest,
          foregroundColor: a.primary ? Colors.white : scheme.onSurface,
          onPressed: () {
            _portal.hide();
            a.onPressed?.call();
          },
          child: Icon(a.icon),
        ),
      ),
      // Etiqueta a la izquierda del círculo, pegada a él.
      Positioned(
        top: c.dy - _miniSize / 2,
        height: _miniSize,
        right: screenWidth - (c.dx - _miniSize / 2 - 12),
        child: Align(
          alignment: Alignment.centerRight,
          child: Material(
            color: scheme.surfaceContainerHighest,
            elevation: 2,
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Text(a.label, style: theme.textTheme.labelLarge),
            ),
          ),
        ),
      ),
    ];
  }

  Widget _overlay(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final rect = _buttonRect() ??
        Rect.fromLTWH(size.width - 16 - _size, size.height - 16 - _size, _size, _size);
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
            for (var i = 0; i < widget.actions.length; i++)
              ..._item(context, i, rect.center, size.width),
            Positioned(
              left: rect.left,
              top: rect.top,
              child: _roundButton(context, Icons.close, _portal.hide),
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

    return OverlayPortal(
      controller: _portal,
      overlayChildBuilder: _overlay,
      child: KeyedSubtree(
        key: _buttonKey,
        child: _roundButton(context, Icons.apps, _portal.show),
      ),
    );
  }
}
