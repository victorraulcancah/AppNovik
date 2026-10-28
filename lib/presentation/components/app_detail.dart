import 'package:flutter/material.dart';

/// Fila de un detalle: etiqueta apagada a la izquierda y valor a la derecha.
/// El valor puede ser texto o un widget (por ejemplo [AppStatusBadge]).
class AppDetailRow extends StatelessWidget {
  final String label;
  final String? value;
  final Widget? valueWidget;

  const AppDetailRow({
    super.key,
    required this.label,
    this.value,
    this.valueWidget,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Align(
              alignment: Alignment.centerRight,
              child: valueWidget ??
                  Text(
                    value ?? '—',
                    textAlign: TextAlign.right,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

enum AppBadgeTone { success, warning, danger, neutral }

/// Insignia de estado (Activo, Pendiente, Anulado...): píldora con fondo suave.
class AppStatusBadge extends StatelessWidget {
  final String label;
  final AppBadgeTone tone;

  const AppStatusBadge({super.key, required this.label, this.tone = AppBadgeTone.neutral});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final base = switch (tone) {
      AppBadgeTone.success => const Color(0xFF16A34A),
      AppBadgeTone.warning => const Color(0xFFD97706),
      AppBadgeTone.danger => const Color(0xFFDC2626),
      AppBadgeTone.neutral => theme.colorScheme.onSurfaceVariant,
    };
    final hsl = HSLColor.fromColor(base);
    final text = hsl.withLightness(dark ? 0.72 : 0.28).toColor();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: base.withValues(alpha: dark ? 0.22 : 0.14),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelMedium?.copyWith(
          color: text,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class AppItemColumn {
  final String label;
  final String value;
  const AppItemColumn(this.label, this.value);
}

/// Tarjeta de un ítem dentro de un detalle (producto de un pedido, stock de un
/// almacén...): título, detalle y columnas etiqueta/valor.
class AppItemCard extends StatelessWidget {
  final String title;
  final String? subtitle;
  final List<AppItemColumn> columns;

  const AppItemCard({
    super.key,
    required this.title,
    this.subtitle,
    this.columns = const [],
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          if (subtitle != null)
            Text(
              subtitle!,
              style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
          if (columns.isNotEmpty) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                for (final c in columns)
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          c.label,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                        Text(
                          c.value,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// Título de una sección dentro de un modal o detalle.
class AppSectionTitle extends StatelessWidget {
  final String text;
  const AppSectionTitle(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 8),
      child: Text(
        text,
        style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
      ),
    );
  }
}
