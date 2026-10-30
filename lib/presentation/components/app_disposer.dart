import 'package:flutter/widgets.dart';

/// Libera controladores y notificadores cuando el widget sale del árbol.
///
/// Un modal sigue dibujado durante su animación de salida, aunque `showAppModal` ya haya
/// devuelto el resultado: liberar los controladores justo después del `await` los deja en uso
/// mientras todavía se redibuja. Envolver el cuerpo del modal con esto los libera cuando de
/// verdad ya no se usan.
class AppDisposer extends StatefulWidget {
  final List<VoidCallback> onDispose;
  final Widget child;

  const AppDisposer({super.key, required this.onDispose, required this.child});

  @override
  State<AppDisposer> createState() => _AppDisposerState();
}

class _AppDisposerState extends State<AppDisposer> {
  @override
  void dispose() {
    for (final dispose in widget.onDispose) {
      dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
