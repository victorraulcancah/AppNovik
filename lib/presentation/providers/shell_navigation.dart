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

  ({DateTime? desde, DateTime? hasta})? _pendingQuotes;

  /// Pedido para Documentos: abrir la lista de Cotizaciones solo con las pendientes y, si hay, en
  /// ese rango de emisión (el enlace "Cotizaciones pendientes" del Inicio). Lo atiende
  /// `DocumentsPage` con [takePendingQuotes].
  ({DateTime? desde, DateTime? hasta})? get pendingQuotes => _pendingQuotes;

  void goToPendingQuotes({DateTime? desde, DateTime? hasta}) {
    _pendingQuotes = (desde: desde, hasta: hasta);
    goTo('documentos');
  }

  ({DateTime? desde, DateTime? hasta})? takePendingQuotes() {
    final request = _pendingQuotes;
    _pendingQuotes = null;
    return request;
  }
}
