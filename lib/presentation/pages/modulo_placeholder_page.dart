import 'package:flutter/material.dart';

/// Pantalla provisional de un módulo mientras no esté implementado.
class ModuloPlaceholderPage extends StatelessWidget {
  final String titulo;
  final IconData icono;

  const ModuloPlaceholderPage({
    super.key,
    required this.titulo,
    required this.icono,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icono, size: 64),
          const SizedBox(height: 16),
          Text(titulo, style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 8),
          const Text('Módulo en construcción'),
        ],
      ),
    );
  }
}
