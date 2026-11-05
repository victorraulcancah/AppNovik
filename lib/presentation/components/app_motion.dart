import 'package:flutter/material.dart';

/// Aparición suave: el contenido entra con un fundido y un leve deslizamiento hacia arriba.
///
/// [delay] sirve para escalonar varios elementos (cada uno entra un poco después del anterior).
/// Respeta el ajuste del sistema "quitar animaciones": en ese caso se muestra directo.
class AppEntrance extends StatelessWidget {
  final Widget child;
  final Duration delay;
  final Duration duration;

  /// Cuánto sube mientras aparece (en píxeles lógicos).
  final double offset;

  const AppEntrance({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.duration = const Duration(milliseconds: 380),
    this.offset = 16,
  });

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) return child;

    final total = delay + duration;
    final curve = Interval(
      delay.inMilliseconds / total.inMilliseconds,
      1,
      curve: Curves.easeOutCubic,
    );
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: total,
      curve: curve,
      child: child,
      builder: (context, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(offset: Offset(0, (1 - t) * offset), child: child),
      ),
    );
  }
}

/// Latido suave y continuo (escala), para marcas o íconos mientras se espera.
class AppPulse extends StatefulWidget {
  final Widget child;

  const AppPulse({super.key, required this.child});

  @override
  State<AppPulse> createState() => _AppPulseState();
}

class _AppPulseState extends State<AppPulse> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  );

  @override
  void initState() {
    super.initState();
    _controller.repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) return widget.child;
    return ScaleTransition(
      scale: Tween<double>(begin: 0.94, end: 1.04).animate(
        CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
      ),
      child: widget.child,
    );
  }
}

/// Cambio de contenido con fundido (y un leve zoom) al pasar de un módulo a otro.
/// Cada hijo debe traer una `key` distinta para que se note el cambio.
class AppFadeSwitcher extends StatelessWidget {
  final Widget child;

  const AppFadeSwitcher({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 260),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.98, end: 1).animate(animation),
          child: child,
        ),
      ),
      child: child,
    );
  }
}
