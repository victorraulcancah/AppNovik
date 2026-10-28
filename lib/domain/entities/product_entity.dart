/// Producto o servicio, con los mismos datos que muestra la web en `/productos`.
class ProductEntity {
  final int id;

  /// `true` si es un servicio; `false` si es un producto.
  final bool esServicio;
  final String codigo;
  final String name;
  final bool activo;
  final String? marca;
  final String? categoria;

  /// Unidad de medida (UNIDAD, CAJA...) y cuántas unidades trae cada una.
  final String? unidad;
  final int? cantidadBloque;

  // Datos adicionales (la web los muestra al expandir la fila).
  final String? codBarra;
  final String? sku;
  final String? proveedor;
  final String? descripcion;
  final String? usuario;
  final bool ventaSinStock;
  final bool duplicar;
  final DateTime? creado;

  /// Ids de las relaciones, para precargar el formulario de edición.
  final int? marcaId;
  final int? categoriaId;
  final int? unidadId;
  final int? proveedorId;
  final int? canalId;
  final int? giroNegocioId;

  const ProductEntity({
    required this.id,
    required this.codigo,
    required this.name,
    this.esServicio = false,
    this.activo = true,
    this.marca,
    this.categoria,
    this.unidad,
    this.cantidadBloque,
    this.codBarra,
    this.sku,
    this.proveedor,
    this.descripcion,
    this.usuario,
    this.ventaSinStock = false,
    this.duplicar = false,
    this.creado,
    this.marcaId,
    this.categoriaId,
    this.unidadId,
    this.proveedorId,
    this.canalId,
    this.giroNegocioId,
  });

  /// "UNIDAD (1 c/u)" como en la columna "U. de Medida" de la web.
  String? get unidadLabel {
    if (unidad == null) return null;
    return cantidadBloque == null ? unidad : '$unidad ($cantidadBloque c/u)';
  }
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
