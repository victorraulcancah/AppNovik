import 'package:flutter/foundation.dart';

/// Permite que una pantalla pida pasar a otro módulo de la barra inferior (por ejemplo, de
/// Documentos a Ventas al culminar una cotización). El contenedor principal atiende el pedido.
class ShellNavigation extends ChangeNotifier {
  String? _requested;

  /// El módulo pedido (su `slug`: `ventas`, `documentos`...), hasta que el contenedor lo atienda.
  String? get requested => _requested;

  void goTo(String slug) {
    _requested = slug;
    notifyListeners();
  }

  /// El contenedor ya atendió el pedido.
  String? take() {
    final slug = _requested;
    _requested = null;
    return slug;
  }
}
