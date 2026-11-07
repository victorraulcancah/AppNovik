import 'package:flutter/material.dart';

/// Un filtro aplicado, para mostrarlo como chip con su "x".
class AppActiveFilter {
  /// Identifica al filtro (llave del chip); debe ser único dentro de la lista.
  final String id;

  /// Texto del chip: "Estado: Activos", "Del 01/11 al 05/11"...
  final String label;

  /// Quita este filtro. La pantalla recarga la lista igual que al cambiarlo en el panel.
  final VoidCallback onRemove;

  const AppActiveFilter({
    required this.id,
    required this.label,
    required this.onRemove,
  });
}

/// Los filtros que están puestos, como chips que se quitan uno a uno, en una fila horizontal
/// con scroll. Con dos o más sale además **Limpiar** al principio (si se pasa [onClear]). Sin filtros no ocupa
/// lugar: la fila crece y se encoge con animación y cada chip entra con un fundido.
///
/// Es la contraparte visual del botón de filtros (`AppSearchBar.filterCount`).
class AppActiveFilters extends StatelessWidget {
  final List<AppActiveFilter> filters;
  final VoidCallback? onClear;

  const AppActiveFilters({super.key, required this.filters, this.onClear});

  @override
  Widget build(BuildContext context) {
    final still = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final content = filters.isEmpty
        ? const SizedBox(width: double.infinity)
        : SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
              children: [
                // Primero, para que siempre se vea aunque haya muchos chips.
                if (onClear != null && filters.length > 1)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Center(
                      child: TextButton(
                        key: const ValueKey('filtros-limpiar'),
                        onPressed: onClear,
                        child: const Text('Limpiar'),
                      ),
                    ),
                  ),
                for (final f in filters)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: _ChipEntrance(
                      key: ValueKey('filtro-${f.id}'),
                      child: InputChip(
                        label: Text(f.label),
                        visualDensity: VisualDensity.compact,
                        onDeleted: f.onRemove,
                        deleteButtonTooltipMessage: 'Quitar ${f.label}',
                      ),
                    ),
                  ),
              ],
            ),
          );

    if (still) return content;
    return AnimatedSize(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      alignment: Alignment.topCenter,
      child: content,
    );
  }
}

/// Fundido y leve crecimiento al aparecer (solo una vez, sin animación continua).
class _ChipEntrance extends StatelessWidget {
  final Widget child;

  const _ChipEntrance({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) return child;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      child: child,
      builder: (context, t, child) => Opacity(
        opacity: t,
        child: Transform.scale(scale: 0.92 + 0.08 * t, child: child),
      ),
    );
  }
}
