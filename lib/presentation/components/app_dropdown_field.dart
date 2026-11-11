import 'package:flutter/material.dart';

/// Campo desplegable con etiqueta (estilo de los demás campos de la app).
///
/// El valor elegido y las opciones van en letra más pequeña (14) que la de un campo de texto
/// para que quepan los nombres largos (almacenes, listas de precios) sin cortarse.
class AppDropdownField<T> extends StatelessWidget {
  final String label;
  final T? value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?>? onChanged;
  final String? Function(T?)? validator;

  const AppDropdownField({
    super.key,
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
    this.validator,
  });

  /// Tamaño del valor y de las opciones.
  static const double fontSize = 14;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DropdownButtonFormField<T>(
      initialValue: value,
      items: items,
      onChanged: onChanged,
      validator: validator,
      isExpanded: true,
      style: theme.textTheme.bodyMedium?.copyWith(
        fontSize: fontSize,
        color: theme.colorScheme.onSurface,
      ),
      decoration: InputDecoration(labelText: label),
    );
  }
}
