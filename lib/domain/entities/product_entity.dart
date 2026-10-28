class ProductEntity {
  final int id;
  final String codigo;
  final String name;
  final String? sku;

  /// `true` si es un servicio (no tiene stock).
  final bool esServicio;
  final bool activo;
  final String? marca;
  final String? categoria;
  final String? unidad;

  /// Suma del stock en todos los almacenes; `null` si el backend no lo envía.
  final double? stockTotal;

  const ProductEntity({
    required this.id,
    required this.codigo,
    required this.name,
    this.sku,
    this.esServicio = false,
    this.activo = true,
    this.marca,
    this.categoria,
    this.unidad,
    this.stockTotal,
  });
}

/// Una página de la lista de productos.
class ProductPageEntity {
  final List<ProductEntity> items;
  final int currentPage;
  final int lastPage;
  final int total;

  const ProductPageEntity({
    required this.items,
    required this.currentPage,
    required this.lastPage,
    required this.total,
  });

  bool get hasMore => currentPage < lastPage;
}
