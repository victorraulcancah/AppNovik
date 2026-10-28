import 'package:flutter/material.dart';

/// Acciones estándar sobre un registro. Cada una trae su ícono y su color, para
/// que "anular" se vea igual en toda la app.
enum AppActionType { view, edit, dispatch, duplicate, annul, delete, pdf }

extension on AppActionType {
  IconData get icon => switch (this) {
        AppActionType.view => Icons.description_outlined,
        AppActionType.edit => Icons.edit_outlined,
        AppActionType.dispatch => Icons.local_shipping_outlined,
        AppActionType.duplicate => Icons.content_copy_outlined,
        AppActionType.annul => Icons.block,
        AppActionType.delete => Icons.delete_outline,
        AppActionType.pdf => Icons.picture_as_pdf_outlined,
      };

  String get label => switch (this) {
        AppActionType.view => 'Ver detalle',
        AppActionType.edit => 'Editar',
        AppActionType.dispatch => 'Despachar',
        AppActionType.duplicate => 'Duplicar',
        AppActionType.annul => 'Anular',
        AppActionType.delete => 'Eliminar',
        AppActionType.pdf => 'Descargar PDF',
      };

  Color get color => switch (this) {
        AppActionType.view => const Color(0xFF16A34A),
        AppActionType.edit => const Color(0xFF0E90C7),
        AppActionType.dispatch => const Color(0xFF2563EB),
        AppActionType.duplicate => const Color(0xFFE8891D),
        AppActionType.annul => const Color(0xFFC2410C),
        AppActionType.delete => const Color(0xFFC8123F),
        AppActionType.pdf => const Color(0xFFA31238),
      };
}

/// Botón de acción de una fila: píldora de color con un ícono blanco, sin
/// texto (el nombre sale como tooltip). Se pone dentro de cada fila o tarjeta,
/// por ejemplo en `AppListCard.actions`. Solo se muestran las acciones que el
/// registro admite.
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
      iconSize: 18,
      visualDensity: VisualDensity.compact,
      style: IconButton.styleFrom(
        backgroundColor: type.color,
        foregroundColor: Colors.white,
        disabledBackgroundColor: type.color.withValues(alpha: 0.35),
        fixedSize: const Size(38, 28),
        minimumSize: const Size(38, 28),
        padding: EdgeInsets.zero,
        shape: const StadiumBorder(),
        tapTargetSize: MaterialTapTargetSize.padded,
      ),
    );
  }
}
