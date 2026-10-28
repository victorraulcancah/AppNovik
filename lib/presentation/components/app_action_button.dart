import 'package:flutter/material.dart';

/// Acciones estándar sobre un registro. Cada una trae su ícono y su color, para
/// que "anular" se vea igual en toda la app.
enum AppActionType { view, edit, delete, annul }

extension on AppActionType {
  IconData get icon => switch (this) {
        AppActionType.view => Icons.visibility_outlined,
        AppActionType.edit => Icons.edit_outlined,
        AppActionType.delete => Icons.delete_outline,
        AppActionType.annul => Icons.block,
      };

  String get label => switch (this) {
        AppActionType.view => 'Ver',
        AppActionType.edit => 'Editar',
        AppActionType.delete => 'Eliminar',
        AppActionType.annul => 'Anular',
      };

  /// En oscuro se usan tonos más claros para mantener el contraste.
  Color color(ColorScheme scheme) {
    final dark = scheme.brightness == Brightness.dark;
    return switch (this) {
      AppActionType.view => scheme.onSurfaceVariant,
      AppActionType.edit =>
        dark ? const Color(0xFF60A5FA) : const Color(0xFF1E4E80),
      AppActionType.delete =>
        dark ? const Color(0xFFF87171) : const Color(0xFFDC2626),
      AppActionType.annul =>
        dark ? const Color(0xFFFB923C) : const Color(0xFFF97316),
    };
  }
}

/// Botón de acción de una fila: solo ícono, sin fondo ni texto (el nombre sale
/// como tooltip). Se pone dentro de cada fila o tarjeta, por ejemplo en
/// `AppListCard.actions`.
///
/// Las acciones destructivas ([AppActionType.delete], [AppActionType.annul])
/// deberían confirmarse con `showAppConfirm` antes de ejecutarse.
class AppActionButton extends StatelessWidget {
  final AppActionType type;
  final VoidCallback? onPressed;

  /// Nombre distinto del predeterminado para el tooltip (por ejemplo "Anular venta").
  final String? label;

  const AppActionButton({
    super.key,
    required this.type,
    required this.onPressed,
    this.label,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: label ?? type.label,
      onPressed: onPressed,
      icon: Icon(type.icon),
      iconSize: 20,
      color: type.color(Theme.of(context).colorScheme),
      visualDensity: VisualDensity.compact,
      style: IconButton.styleFrom(
        minimumSize: const Size(36, 36),
        tapTargetSize: MaterialTapTargetSize.padded,
      ),
    );
  }
}
