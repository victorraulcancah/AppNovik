import 'sale_entity.dart';

/// Una línea de una cotización: producto, cantidad y el precio con el que se cotizó.
class QuoteLineEntity {
  final int productId;
  final String codigo;
  final String name;
  final String? marca;
  final int cantidad;
  final double precio;

  /// La línea está en dólares (la cotización se hizo con una lista en dólares).
  final bool dolares;

  /// Descuento con el que se cotizó: un porcentaje, o un monto si [dtoFijo].
  final double dto;
  final bool dtoFijo;

  const QuoteLineEntity({
    required this.productId,
    required this.codigo,
    required this.name,
    this.marca,
    required this.cantidad,
    required this.precio,
    this.dolares = false,
    this.dto = 0,
    this.dtoFijo = false,
  });
}

/// Lo necesario de una cotización para culminarla como venta o editarla: cliente, almacén, lista de
/// precios y sus líneas. Es lo que la web guarda al tocar "Culminar Venta o Editar Cotización".
class QuoteDraftEntity {
  final int id;
  final ClientEntity client;
  final int warehouseId;
  final int? priceListId;
  final String? observaciones;
  final List<QuoteLineEntity> lines;

  /// Vendedor encargado que se eligió al cotizar (viaja a la venta, como en la web).
  final int? vendedorId;

  const QuoteDraftEntity({
    required this.id,
    required this.client,
    required this.warehouseId,
    this.priceListId,
    this.observaciones,
    this.lines = const [],
    this.vendedorId,
  });

  /// Alguna línea está en dólares.
  bool get esDolares => lines.any((l) => l.dolares);
}
