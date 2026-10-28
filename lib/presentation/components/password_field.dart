import 'package:flutter/material.dart';
import 'custom_text_field.dart';

/// Campo de contraseña con botón para mostrar/ocultar el texto.
class AppPasswordField extends StatefulWidget {
  final TextEditingController controller;
  final String label;
  final bool enabled;
  final TextInputAction? textInputAction;
  final String? Function(String?)? validator;
  final ValueChanged<String>? onFieldSubmitted;

  const AppPasswordField({
    super.key,
    required this.controller,
    this.label = 'Contraseña',
    this.enabled = true,
    this.textInputAction,
    this.validator,
    this.onFieldSubmitted,
  });

  @override
  State<AppPasswordField> createState() => _AppPasswordFieldState();
}

class _AppPasswordFieldState extends State<AppPasswordField> {
  bool _obscure = true;

  @override
  Widget build(BuildContext context) {
    return AppTextField(
      controller: widget.controller,
      label: widget.label,
      prefixIcon: Icons.lock_outline,
      obscureText: _obscure,
      enabled: widget.enabled,
      textInputAction: widget.textInputAction,
      validator: widget.validator,
      onFieldSubmitted: widget.onFieldSubmitted,
      autofillHints: const [AutofillHints.password],
      suffix: IconButton(
        tooltip: _obscure ? 'Mostrar contraseña' : 'Ocultar contraseña',
        icon: Icon(
          _obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
        ),
        onPressed: () => setState(() => _obscure = !_obscure),
      ),
    );
  }
}
