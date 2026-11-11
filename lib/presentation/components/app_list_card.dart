import 'package:flutter/material.dart';

import 'app_press.dart';

/// Tarjeta de lista: título, líneas de detalle y, a la derecha, un dato destacado con su
/// nota y los botones de acción de la fila.
class AppListCard extends StatelessWidget {
  final String title;
  final List<String> lines;
  final String? trailingTitle;

  /// Color del dato destacado (por ejemplo rojo si el stock es negativo).
  final Color? trailingTitleColor;
  final String? trailingCaption;

  /// Color de la nota (por ejemplo verde para "Activo"); por defecto, apagado.
  final Color? trailingCaptionColor;

  /// Botones de acción de esta fila: [AppActionButton]s.
  final List<Widget> actions;
  final VoidCallback? onTap;

  /// Un widget a la izquierda del título (por ejemplo la miniatura de un producto).
  final Widget? leading;

  /// Fila opcional bajo las líneas de detalle (por ejemplo, insignias de categoría y estado).
  final Widget? footer;

  /// El elemento que se está viendo en el panel de detalle (tablet): borde y fondo de la marca.
  final bool selected;

  const AppListCard({
    super.key,
    required this.title,
    this.lines = const [],
    this.trailingTitle,
    this.trailingTitleColor,
    this.trailingCaption,
    this.trailingCaptionColor,
    this.actions = const [],
    this.onTap,
    this.leading,
    this.footer,
    this.selected = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    const tabular = [FontFeature.tabularFigures()];
    final hasTrailing =
        trailingTitle != null || trailingCaption != null || actions.isNotEmpty;

    return AppPressScale(
      enabled: onTap != null,
      scale: 0.985,
      child: Material(
        color: selected
            ? Color.alphaBlend(
                scheme.primary.withValues(alpha: 0.08),
                scheme.surfaceContainerLowest,
              )
            : scheme.surfaceContainerLowest,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: selected ? scheme.primary : scheme.outlineVariant,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: InkWell(
          onTap: onTap,
          child: Stack(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (leading != null) ...[leading!, const SizedBox(width: 12)],
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            for (final line in lines)
                              Text(
                                line,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: scheme.onSurfaceVariant,
                                ),
                              ),
                            if (footer != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 6),
                                child: footer,
                              ),
                          ],
                        ),
                      ),
                    ),
                    if (hasTrailing) ...[
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (trailingTitle != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 2, right: 8),
                              child: Text(
                                trailingTitle!,
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  fontFeatures: tabular,
                                  color: trailingTitleColor,
                                ),
                              ),
                            ),
                          if (trailingCaption != null)
                            Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: Text(
                                trailingCaption!,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color:
                                      trailingCaptionColor ??
                                      scheme.onSurfaceVariant,
                                  fontFeatures: tabular,
                                ),
                              ),
                            ),
                          if (actions.isNotEmpty)
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: actions,
                            ),
                        ],
                      ),
                    ],
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
