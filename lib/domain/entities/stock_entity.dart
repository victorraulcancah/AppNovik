/// Lista de precios de la empresa.
class PriceListEntity {
  final int id;
  final String name;

  /// `true` si los precios están en dólares.
  final bool esDolares;

  const PriceListEntity({required this.id, required this.name, this.esDolares = false});

  String get simboloMoneda => esDolares ? r'$' : 'S/';
}

/// Existencias de un producto en un almacén, como las muestra la web en el
/// detalle del almacén.
class StockItemEntity {
  final int productId;
  final bool esServicio;
  final String codigo;
  final String name;
  final String? marca;

  /// Lo que hay en el almacén y se puede vender.
  final double disponible;

  /// Reservado por entregas pendientes, cotizaciones con reserva y transferencias.
  final double porDespachar;

  /// Transferencias que están llegando a este almacén.
  final double porRecibir;
  final bool ventaSinStock;

  /// Costo promedio y precio de la lista elegida (el usuario puede no verlos).
  final double? costoPromedio;
  final double? precio;

  const StockItemEntity({
    required this.productId,
    required this.codigo,
    required this.name,
    this.esServicio = false,
    this.marca,
    this.disponible = 0,
    this.porDespachar = 0,
    this.porRecibir = 0,
    this.ventaSinStock = false,
    this.costoPromedio,
    this.precio,
  });

  /// Disponible más lo reservado por despachar (igual que la web).
  double get stockTotal => disponible + porDespachar;
}

/// Una página del detalle de un almacén, con los totales del almacén completo.
class StockPageEntity {
  final List<StockItemEntity> items;
  final int currentPage;
  final int lastPage;
  final int total;
  final double costoTotal;
  final double totalVenta;

  const StockPageEntity({
    required this.items,
    required this.currentPage,
    required this.lastPage,
    required this.total,
    this.costoTotal = 0,
    this.totalVenta = 0,
  });

  bool get hasMore => currentPage < lastPage;
}
