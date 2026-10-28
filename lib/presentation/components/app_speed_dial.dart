import 'dart:math' as math;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

class AppSpeedDialAction {
  final String label;
  final IconData icon;
  final VoidCallback? onPressed;

  /// Color del círculo y del texto de la acción; sin color usa uno neutro.
  final Color? color;

  const AppSpeedDialAction({
    required this.label,
    required this.icon,
    required this.onPressed,
    this.color,
  });
}

/// Botón redondo "Acciones" que flota abajo a la derecha de la vista. Al
/// tocarlo oscurece la pantalla y despliega las acciones en un arco hacia
/// arriba y a la izquierda del botón, cada una con su color y su etiqueta.
///
/// Si hay más acciones de las que caben ([visibleCount]), el arco funciona como
/// una rueda: se desliza con el dedo hacia arriba o abajo para girarla y las
/// acciones entran y salen por los extremos. Con una sola acción se muestra
/// como un botón flotante normal con su nombre.
///
/// Colócalo con `Positioned(right: 16, bottom: 16)` dentro de un `Stack`, o en
/// `Scaffold.floatingActionButton`. Deja espacio al final de la lista
/// (`AppCardList.bottomPadding`, por ejemplo 96) para que no tape el último
/// elemento.
class AppSpeedDial extends StatefulWidget {
  final List<AppSpeedDialAction> actions;
  final String label;

  /// Cuántas acciones se ven a la vez en el arco.
  final int visibleCount;

  const AppSpeedDial({
    super.key,
    required this.actions,
    this.label = 'Acciones',
    this.visibleCount = 4,
  });

  @override
  State<AppSpeedDial> createState() => _AppSpeedDialState();
}

class _AppSpeedDialState extends State<AppSpeedDial>
    with SingleTickerProviderStateMixin {
  static const _size = 64.0;
  static const _miniSize = 40.0;

  /// Separación vertical entre acciones consecutivas: mayor que el alto de una
  /// etiqueta, para que ninguna tape a otra.
  static const _step = 60.0;

  /// Radio horizontal del arco (más corto que el vertical para que las
  /// etiquetas largas no se salgan por la izquierda).
  static const _radiusX = 130.0;

  final _portal = OverlayPortalController();
  final _buttonKey = GlobalKey();
  late final AnimationController _snap;
  Animation<double>? _snapAnimation;

  /// Posición de la rueda, en acciones: 0 muestra las primeras.
  double _offset = 0;

  int get _visible => math.min(widget.visibleCount, widget.actions.length);
  double get _maxOffset => (widget.actions.length - _visible).toDouble();
  bool get _scrolls => _maxOffset > 0;

  /// Radio vertical del arco: de la acción más alta a la altura del botón.
  double get _radiusY => _step * (_visible - 1);

  @override
  void initState() {
    super.initState();
    _snap = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 180),
    )..addListener(() {
        if (_snapAnimation != null) setState(() => _offset = _snapAnimation!.value);
      });
  }

  @override
  void dispose() {
    _snap.dispose();
    super.dispose();
  }

  void _open() {
    _offset = 0;
    _portal.show();
  }

  void _drag(double deltaY) {
    _snap.stop();
    setState(
      () => _offset = (_offset - deltaY / _step).clamp(0.0, _maxOffset).toDouble(),
    );
  }

  /// Al soltar, la rueda se acomoda en la acción más cercana.
  void _settle() {
    final target = _offset.roundToDouble().clamp(0.0, _maxOffset).toDouble();
    _snapAnimation = Tween<double>(begin: _offset, end: target)
        .animate(CurvedAnimation(parent: _snap, curve: Curves.easeOut));
    _snap
      ..reset()
      ..forward();
  }

  /// Posición del botón en la pantalla, para abrir el arco desde ahí.
  Rect? _buttonRect() {
    final box = _buttonKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.attached) return null;
    return box.localToGlobal(Offset.zero) & box.size;
  }

  /// Texto legible sobre el fondo de la etiqueta: el color de la acción, más
  /// oscuro en tema claro y más claro en tema oscuro.
  Color _textColor(Color color, Brightness brightness) {
    final hsl = HSLColor.fromColor(color);
    return hsl
        .withLightness(brightness == Brightness.dark ? 0.78 : 0.30)
        .toColor();
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

  /// Círculo de una acción y su etiqueta, en su lugar de la rueda.
  List<Widget> _item(
    BuildContext context,
    int index,
    Offset center,
    double screenWidth,
  ) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final a = widget.actions[index];

    // Posición en la rueda: 0 es la de más arriba y _visible-1 la de la altura
    // del botón. Fuera de ese rango la acción se desvanece y desaparece.
    final slot = index - _offset;
    final overshoot = math.max(math.max(-slot, slot - (_visible - 1)), 0.0);
    if (overshoot >= 1) return const [];
    final opacity = 1 - overshoot;

    final height = _radiusY * (1 - slot / (_visible - 1 == 0 ? 1 : _visible - 1));
    final ratio = (height / _radiusY).clamp(-1.0, 1.0);
    final dx = -_radiusX * math.sqrt(1 - ratio * ratio);
    final c = center + Offset(dx, -height);

    final color = a.color ?? scheme.surfaceContainerHighest;
    final colored = a.color != null;

    return [
      Positioned(
        left: c.dx - _miniSize / 2,
        top: c.dy - _miniSize / 2,
        width: _miniSize,
        height: _miniSize,
        child: Opacity(
          opacity: opacity,
          child: FloatingActionButton.small(
            heroTag: null,
            tooltip: a.label,
            backgroundColor: color,
            foregroundColor: colored ? Colors.white : scheme.onSurface,
            onPressed: () {
              _portal.hide();
              a.onPressed?.call();
            },
            child: Icon(a.icon),
          ),
        ),
      ),
      // Etiqueta a la izquierda del círculo, pegada a él.
      Positioned(
        top: c.dy - _miniSize / 2,
        height: _miniSize,
        right: screenWidth - (c.dx - _miniSize / 2 - 12),
        child: Opacity(
          opacity: opacity,
          child: Align(
            alignment: Alignment.centerRight,
            child: Material(
              color: scheme.surfaceContainerHighest,
              elevation: 2,
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Text(
                  a.label,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: colored ? _textColor(color, theme.brightness) : null,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
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
        child: Listener(
          // Rueda del ratón (web y escritorio) también gira la rueda.
          onPointerSignal: (event) {
            if (_scrolls && event is PointerScrollEvent) {
              _drag(-event.scrollDelta.dy);
              _settle();
            }
          },
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onVerticalDragUpdate: _scrolls ? (d) => _drag(d.delta.dy) : null,
            onVerticalDragEnd: _scrolls ? (_) => _settle() : null,
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
                if (_scrolls)
                  Positioned(
                    top: rect.center.dy - _radiusY - _miniSize / 2 - 32,
                    left: 0,
                    right: 0,
                    child: const Center(
                      child: Text(
                        'Desliza para ver más',
                        style: TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                    ),
                  ),
                Positioned(
                  left: rect.left,
                  top: rect.top,
                  child: _roundButton(context, Icons.close, _portal.hide),
                ),
              ],
            ),
          ),
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
        backgroundColor: only.color ?? AppTheme.strongFill(Theme.of(context).brightness),
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
        child: _roundButton(context, Icons.apps, _open),
      ),
    );
  }
}
