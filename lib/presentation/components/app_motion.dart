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

  /// Desde dónde llega, en píxeles lógicos (por ejemplo `Offset(24, 0)` entra desde la derecha).
  /// Si se da, reemplaza a [offset].
  final Offset? from;

  const AppEntrance({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.duration = const Duration(milliseconds: 380),
    this.offset = 16,
    this.from,
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
        child: Transform.translate(
          offset: (from ?? Offset(0, offset)) * (1 - t),
          child: child,
        ),
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

class _AppPulseState extends State<AppPulse>
    with SingleTickerProviderStateMixin {
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
    if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) {
      return widget.child;
    }
    return ScaleTransition(
      scale: Tween<double>(
        begin: 0.94,
        end: 1.04,
      ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut)),
      child: widget.child,
    );
  }
}

/// Cambio de contenido con fundido (y un leve zoom) al pasar de un módulo a otro.
/// Cada hijo debe traer una `key` distinta para que se note el cambio.
class AppFadeSwitcher extends StatelessWidget {
  final Widget child;
  final Duration duration;

  const AppFadeSwitcher({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 260),
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: duration,
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

/// Dice a los números que corren ([AppCountUp]) y a las barras que se llenan si deben partir de cero.
///
/// Con datos recién llegados del servidor parten de cero (es la gracia de la animación). Pero si lo
/// que se ve ya son datos guardados, contar desde cero sería esconder una cifra que ya estaba a la
/// vista: ahí no parten de cero y, si el dato nuevo cambia, pasan del valor viejo al nuevo.
class AppCountUpScope extends InheritedWidget {
  final bool fromZero;

  const AppCountUpScope({super.key, required this.fromZero, required super.child});

  /// `true` si no hay un [AppCountUpScope] encima.
  static bool fromZeroOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppCountUpScope>()?.fromZero ?? true;

  @override
  bool updateShouldNotify(AppCountUpScope old) => fromZero != old.fromZero;
}

/// Número que "corre" hasta su valor (y vuelve a correr, desde el valor anterior, si cambia).
/// [format] arma el texto (por ejemplo con el símbolo de moneda). Parte de cero salvo que un
/// [AppCountUpScope] diga lo contrario.
class AppCountUp extends StatelessWidget {
  final double value;
  final String Function(double value) format;
  final TextStyle? style;
  final Duration duration;

  const AppCountUp({
    super.key,
    required this.value,
    required this.format,
    this.style,
    this.duration = const Duration(milliseconds: 450),
  });

  @override
  Widget build(BuildContext context) {
    final text = Text(
      format(value),
      style: style,
      maxLines: 1,
      softWrap: false,
    );
    if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) return text;
    final fromZero = AppCountUpScope.fromZeroOf(context);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: fromZero ? 0 : value, end: value),
      duration: duration,
      curve: Curves.easeOutCubic,
      builder: (context, v, _) =>
          Text(format(v), style: style, maxLines: 1, softWrap: false),
    );
  }
}

/// Progreso 0→1 para dibujar una gráfica: arranca al aparecer y vuelve a arrancar desde cero
/// cuando cambia [dataKey] (por ejemplo, un hash de los datos). No repite nada por su cuenta,
/// así que `pumpAndSettle` termina. Con "quitar animaciones" el progreso queda en 1 de entrada.
class AppReveal extends StatefulWidget {
  final Object? dataKey;
  final Duration duration;
  final Widget Function(BuildContext context, Animation<double> progress)
  builder;

  const AppReveal({
    super.key,
    required this.dataKey,
    required this.builder,
    this.duration = const Duration(milliseconds: 900),
  });

  @override
  State<AppReveal> createState() => _AppRevealState();
}

class _AppRevealState extends State<AppReveal>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.duration,
  );
  bool _started = false;

  bool get _still => MediaQuery.maybeDisableAnimationsOf(context) ?? false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (_still) {
      _controller.value = 1;
    } else {
      _controller.forward();
    }
  }

  @override
  void didUpdateWidget(AppReveal old) {
    super.didUpdateWidget(old);
    if (old.dataKey == widget.dataKey) return;
    if (_still) {
      _controller.value = 1;
    } else {
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, _controller);
}
