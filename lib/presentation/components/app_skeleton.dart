import 'package:flutter/material.dart';

/// Brillo que recorre a sus hijos (los bloques grises de un esqueleto de carga).
class AppShimmer extends StatefulWidget {
  final Widget child;

  const AppShimmer({super.key, required this.child});

  @override
  State<AppShimmer> createState() => _AppShimmerState();
}

class _AppShimmerState extends State<AppShimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );

  @override
  void initState() {
    super.initState();
    _controller.repeat();
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
    final scheme = Theme.of(context).colorScheme;
    return AnimatedBuilder(
      animation: _controller,
      child: widget.child,
      builder: (context, child) => ShaderMask(
        blendMode: BlendMode.srcATop,
        shaderCallback: (bounds) {
          final t = _controller.value;
          return LinearGradient(
            begin: Alignment(-1.5 + t * 3, -0.3),
            end: Alignment(-0.5 + t * 3, 0.3),
            colors: [
              Colors.transparent,
              scheme.surface.withValues(alpha: 0.55),
              Colors.transparent,
            ],
          ).createShader(bounds);
        },
        child: child,
      ),
    );
  }
}

/// Bloque gris redondeado de un esqueleto.
class AppSkeletonBox extends StatelessWidget {
  final double? width;
  final double height;
  final double radius;

  const AppSkeletonBox({
    super.key,
    this.width,
    this.height = 12,
    this.radius = 6,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

/// Esqueleto de una lista de tarjetas: aparece mientras carga la primera página, con la
/// misma forma que las tarjetas reales (número, título, líneas y dato a la derecha).
class AppSkeletonList extends StatelessWidget {
  final int count;

  const AppSkeletonList({super.key, this.count = 6});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      label: 'Cargando',
      child: AppShimmer(
        child: ListView.separated(
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          itemCount: count,
          separatorBuilder: (_, _) => const SizedBox(height: 12),
          itemBuilder: (context, i) => Container(
            height: 84,
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: scheme.outlineVariant),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      AppSkeletonBox(height: 14, width: 180),
                      SizedBox(height: 10),
                      AppSkeletonBox(height: 10, width: 120),
                      SizedBox(height: 6),
                      AppSkeletonBox(height: 10, width: 90),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    AppSkeletonBox(height: 14, width: 64),
                    SizedBox(height: 10),
                    AppSkeletonBox(height: 10, width: 40),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
