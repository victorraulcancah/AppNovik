import 'package:flutter/material.dart';
import '../../domain/entities/gestion_entity.dart';
import '../utils/gestion_copy.dart';

/// Etiqueta de color (el resultado de una gestión, "Programado", "Vencido"...): fondo suave del mismo
/// color y texto legible en el tema claro y en el oscuro.
class GestionPill extends StatelessWidget {
  final String label;
  final Color color;

  const GestionPill({super.key, required this.label, required this.color});

  /// La etiqueta del resultado de una gestión, con el color de su tono.
  factory GestionPill.resultado(GestionTono tono, String label) =>
      GestionPill(label: label, color: gestionTonoColor(tono));

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: dark ? 0.22 : 0.14),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelMedium?.copyWith(
          color: gestionLegible(color, theme.brightness),
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

/// Círculo con el ícono del tipo de contacto.
class GestionContactoIcon extends StatelessWidget {
  final GestionContacto tipo;
  final double size;

  const GestionContactoIcon({super.key, required this.tipo, this.size = 36});

  @override
  Widget build(BuildContext context) {
    final style = gestionContactoStyle(tipo);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: style.color, shape: BoxShape.circle),
      child: Icon(style.icon, size: size * 0.5, color: Colors.white),
    );
  }
}

/// Tarjeta con una cifra: franja de color, título (con su ícono), una nota, el valor en grande y un detalle.
class GestionStatCard extends StatelessWidget {
  final String title;
  final String? note;

  /// El valor en grande; [valueWidget] lo reemplaza si no es un texto (por ejemplo, una etiqueta).
  final String? value;
  final Widget? valueWidget;
  final String? detail;
  final IconData icon;
  final Color? color;

  /// Algo junto al título (por ejemplo, el signo de interrogación que explica los estados).
  final Widget? titleTrailing;

  const GestionStatCard({
    super.key,
    required this.title,
    this.note,
    this.value,
    this.valueWidget,
    this.detail,
    required this.icon,
    this.color,
    this.titleTrailing,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final accent = color ?? scheme.outline;
    final titleColor = color == null ? scheme.onSurfaceVariant : gestionLegible(color!, theme.brightness);

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
                padding: const EdgeInsets.fromLTRB(14, 10, 10, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(icon, size: 18, color: titleColor),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            title,
                            style: theme.textTheme.labelLarge?.copyWith(
                              color: titleColor,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        if (titleTrailing != null) ...[const SizedBox(width: 2), titleTrailing!],
                      ],
                    ),
                    if (note != null)
                      Text(
                        note!,
                        style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                      ),
                    const SizedBox(height: 4),
                    if (valueWidget != null)
                      Align(alignment: Alignment.centerLeft, child: valueWidget!)
                    else
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          value ?? '—',
                          maxLines: 1,
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                      ),
                    if (detail != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        detail!,
                        style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                      ),
                    ],
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

/// Las tarjetas de cifras en una cuadrícula: 1 columna en un celular angosto, 2 en uno normal y 4 en tablet.
/// Las de una misma fila miden lo mismo.
class GestionStatGrid extends StatelessWidget {
  final List<Widget> children;

  const GestionStatGrid({super.key, required this.children});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        final columns = box.maxWidth >= 700 ? 4 : (box.maxWidth >= 400 ? 2 : 1);
        final rows = <Widget>[];
        for (var i = 0; i < children.length; i += columns) {
          if (rows.isNotEmpty) rows.add(const SizedBox(height: 10));
          rows.add(
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var c = 0; c < columns; c++) ...[
                    if (c > 0) const SizedBox(width: 10),
                    Expanded(child: i + c < children.length ? children[i + c] : const SizedBox.shrink()),
                  ],
                ],
              ),
            ),
          );
        }
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: rows);
      },
    );
  }
}

/// Una fila "dato: valor" que no se desborda con letra grande: los dos lados bajan de línea.
class GestionInfoRow extends StatelessWidget {
  final String label;
  final String? value;
  final Widget? valueWidget;

  const GestionInfoRow({super.key, required this.label, this.value, this.valueWidget});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(label, style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant)),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 3,
            child: Align(
              alignment: Alignment.centerRight,
              child: valueWidget ??
                  Text(
                    value ?? '—',
                    textAlign: TextAlign.right,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: value == null ? scheme.onSurfaceVariant : null,
                    ),
                  ),
            ),
          ),
        ],
      ),
    );
  }
}
