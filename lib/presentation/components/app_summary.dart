import 'package:flutter/material.dart';
import 'app_modal.dart';

/// Un dato informativo del resumen: su nombre, su valor y, opcionalmente, un color de acento
/// (por ejemplo rojo para un costo y verde para una venta).
class AppSummaryMetric {
  final String label;
  final String value;
  final Color? color;

  const AppSummaryMetric({required this.label, required this.value, this.color});
}

/// Tarjeta informativa de un total: franja de color, nombre y el valor en grande.
class AppMetricCard extends StatelessWidget {
  final String label;
  final String value;
  final Color? color;

  const AppMetricCard({super.key, required this.label, required this.value, this.color});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final accent = color ?? scheme.outline;

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(width: 5, color: accent),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: color ?? scheme.onSurfaceVariant,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      value,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Modal de resumen: los totales de una pantalla como tarjetas informativas (se abre desde el
/// botón "Acciones"). Sirve igual para los totales de Stock, de Documentos o de lo que venga.
Future<void> showAppSummary(
  BuildContext context, {
  required String title,
  String? subtitle,
  IconData icon = Icons.functions,
  required List<AppSummaryMetric> metrics,
  String? note,
  String closeLabel = 'Cerrar',
}) {
  return showAppModal(
    context,
    title: title,
    subtitle: subtitle,
    icon: icon,
    primaryLabel: null,
    secondaryLabel: closeLabel,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < metrics.length; i++) ...[
          if (i > 0) const SizedBox(height: 10),
          AppMetricCard(label: metrics[i].label, value: metrics[i].value, color: metrics[i].color),
        ],
        if (note != null) ...[
          const SizedBox(height: 14),
          Text(
            note,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
        ],
      ],
    ),
  );
}
