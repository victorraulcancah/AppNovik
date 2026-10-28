import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

/// Tarjeta de lista: número en la esquina, título, líneas de detalle y, a la
/// derecha, un dato destacado con su nota y los botones de acción de la fila.
class AppListCard extends StatelessWidget {
  /// Posición en la lista; si es `null` no se muestra la marca de la esquina.
  final int? number;
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

  const AppListCard({
    super.key,
    this.number,
    required this.title,
    this.lines = const [],
    this.trailingTitle,
    this.trailingTitleColor,
    this.trailingCaption,
    this.trailingCaptionColor,
    this.actions = const [],
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    const tabular = [FontFeature.tabularFigures()];
    final hasTrailing =
        trailingTitle != null || trailingCaption != null || actions.isNotEmpty;

    return Material(
      color: scheme.surfaceContainerLowest,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: scheme.outlineVariant),
      ),
      child: InkWell(
        onTap: onTap,
        child: Stack(
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(number == null ? 16 : 44, 12, 8, 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
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
                                color: trailingCaptionColor ??
                                    scheme.onSurfaceVariant,
                                fontFeatures: tabular,
                              ),
                            ),
                          ),
                        if (actions.isNotEmpty)
                          Row(mainAxisSize: MainAxisSize.min, children: actions),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            if (number != null)
              Positioned(
                top: 0,
                left: 0,
                child: Container(
                  width: 32,
                  height: 32,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppTheme.strongFill(theme.brightness),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(12),
                      bottomRight: Radius.circular(12),
                    ),
                  ),
                  child: Text(
                    '$number',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
