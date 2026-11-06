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

/// Esqueleto de un detalle (para dentro de un modal o una pantalla): filas de "dato a la
/// izquierda, valor a la derecha", como las de `AppDetailRow`. No scrollea ni se estira.
class AppSkeletonDetail extends StatelessWidget {
  final int rows;

  const AppSkeletonDetail({super.key, this.rows = 6});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Cargando',
      child: AppShimmer(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < rows; i++)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 9),
                  child: Row(
                    children: [
                      AppSkeletonBox(height: 12, width: 70.0 + (i % 3) * 18),
                      const Spacer(),
                      AppSkeletonBox(height: 12, width: 100.0 + (i % 2) * 40),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Esqueleto de un formulario: una etiqueta y un campo por cada [fields]. Para los modales
/// que esperan sus catálogos (listas, categorías, ubigeo) antes de mostrar los campos.
class AppSkeletonForm extends StatelessWidget {
  final int fields;

  const AppSkeletonForm({super.key, this.fields = 4});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Cargando',
      child: AppShimmer(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < fields; i++) ...[
                if (i > 0) const SizedBox(height: 18),
                Align(
                  alignment: Alignment.centerLeft,
                  child: AppSkeletonBox(height: 10, width: 70.0 + (i % 3) * 22),
                ),
                const SizedBox(height: 8),
                const AppSkeletonBox(height: 48, radius: 12),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Esqueleto de los resultados de una búsqueda (hoja de búsqueda): filas compactas de dos líneas.
class AppSkeletonResults extends StatelessWidget {
  final int count;

  const AppSkeletonResults({super.key, this.count = 4});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Cargando',
      child: AppShimmer(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < count; i++)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            AppSkeletonBox(height: 13, width: 150.0 + (i % 3) * 30),
                            const SizedBox(height: 8),
                            AppSkeletonBox(height: 10, width: 90.0 + (i % 2) * 40),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      const AppSkeletonBox(height: 13, width: 54),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Esqueleto de la pantalla de Reportes: las cifras (de a dos), la gráfica y unas tarjetas.
class AppSkeletonReport extends StatelessWidget {
  const AppSkeletonReport({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    Widget card({required double height, Widget? child}) => Container(
      height: height,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: child,
    );

    Widget stat() => card(
      height: 100,
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppSkeletonBox(height: 11, width: 90),
          SizedBox(height: 14),
          AppSkeletonBox(height: 20, width: 110),
          SizedBox(height: 10),
          AppSkeletonBox(height: 12, width: 56, radius: 10),
        ],
      ),
    );

    Widget statsRow() => Row(
      children: [
        Expanded(child: stat()),
        const SizedBox(width: 12),
        Expanded(child: stat()),
      ],
    );

    return Semantics(
      label: 'Cargando',
      child: AppShimmer(
        child: ListView(
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            statsRow(),
            const SizedBox(height: 12),
            statsRow(),
            const SizedBox(height: 16),
            card(
              height: 230,
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppSkeletonBox(height: 14, width: 140),
                  SizedBox(height: 14),
                  Expanded(child: AppSkeletonBox(height: 10, radius: 10)),
                ],
              ),
            ),
            const SizedBox(height: 16),
            for (var i = 0; i < 3; i++) ...[
              card(
                height: 76,
                child: const Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          AppSkeletonBox(height: 13, width: 170),
                          SizedBox(height: 8),
                          AppSkeletonBox(height: 10, width: 110),
                        ],
                      ),
                    ),
                    AppSkeletonBox(height: 14, width: 64),
                  ],
                ),
              ),
              const SizedBox(height: 8),
            ],
          ],
        ),
      ),
    );
  }
}
