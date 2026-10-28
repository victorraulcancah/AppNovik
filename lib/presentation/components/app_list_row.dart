import 'package:flutter/material.dart';

/// Fila estándar de lista: icono tonal, título y detalle a la izquierda; valor
/// y nota a la derecha. Los números usan cifras tabulares para alinear columnas.
class AppListRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final String? value;
  final String? caption;

  /// Color de la nota (por ejemplo `colorScheme.error` para "Agotado").
  final Color? captionColor;
  final VoidCallback? onTap;

  const AppListRow({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.value,
    this.caption,
    this.captionColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return ListTile(
      onTap: onTap,
      leading: CircleAvatar(
        backgroundColor: scheme.primaryContainer,
        foregroundColor: scheme.onPrimaryContainer,
        child: Icon(icon),
      ),
      title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: subtitle == null
          ? null
          : Text(subtitle!, maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: (value == null && caption == null)
          ? null
          : Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (value != null)
                  Text(
                    value!,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                if (caption != null)
                  Text(
                    caption!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: captionColor ?? scheme.onSurfaceVariant,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
              ],
            ),
    );
  }
}
