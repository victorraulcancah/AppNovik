import 'package:flutter/material.dart';

/// Hace que su contenido se hunda un poco mientras se lo toca (botones y tarjetas).
/// No interfiere con los toques: solo escucha. Si el dedo se arrastra (scroll) deja de hundirse.
/// Con "quitar animaciones" del sistema no hace nada.
class AppPressScale extends StatefulWidget {
  final Widget child;
  final bool enabled;
  final double scale;

  const AppPressScale({
    super.key,
    required this.child,
    this.enabled = true,
    this.scale = 0.97,
  });

  @override
  State<AppPressScale> createState() => _AppPressScaleState();
}

class _AppPressScaleState extends State<AppPressScale> {
  bool _down = false;
  Offset _start = Offset.zero;

  void _set(bool down) {
    if (_down != down && mounted) setState(() => _down = down);
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled ||
        (MediaQuery.maybeDisableAnimationsOf(context) ?? false)) {
      return widget.child;
    }
    return Listener(
      onPointerDown: (e) {
        _start = e.position;
        _set(true);
      },
      onPointerMove: (e) {
        if ((e.position - _start).distance > 10) _set(false);
      },
      onPointerUp: (_) => _set(false),
      onPointerCancel: (_) => _set(false),
      child: AnimatedScale(
        scale: _down ? widget.scale : 1,
        duration: const Duration(milliseconds: 110),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}
