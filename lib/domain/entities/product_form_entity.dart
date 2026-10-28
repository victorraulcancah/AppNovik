/// Elemento de un catálogo (marca, categoría, medida, proveedor, canal, giro).
class CatalogItemEntity {
  final int id;
  final String name;

  const CatalogItemEntity({required this.id, required this.name});
}

/// Catálogos que necesita el formulario de producto, de la empresa del usuario.
class ProductCatalogsEntity {
  final List<CatalogItemEntity> marcas;
  final List<CatalogItemEntity> categorias;
  final List<CatalogItemEntity> medidas;
  final List<CatalogItemEntity> proveedores;
  final List<CatalogItemEntity> canales;
  final List<CatalogItemEntity> giros;

  const ProductCatalogsEntity({
    required this.marcas,
    required this.categorias,
    required this.medidas,
    required this.proveedores,
    required this.canales,
    required this.giros,
  });
}

/// Datos del formulario de producto, con los mismos campos que pide la web.
class ProductFormEntity {
  /// `'p'` producto, `'s'` servicio.
  final String tipo;
  final String codigo;
  final String? sku;
  final String name;
  final bool estado;
  final int? measureId;
  final int? cantidadBloque;
  final int brandId;
  final String? codBarra;
  final int categoryId;
  final bool ventaSinStock;
  final int providerId;
  final bool duplicar;
  final int canalId;
  final int giroNegocioId;
  final String? descripcion;

  const ProductFormEntity({
    required this.tipo,
    required this.codigo,
    this.sku,
    required this.name,
    this.estado = true,
    this.measureId,
    this.cantidadBloque,
    required this.brandId,
    this.codBarra,
    required this.categoryId,
    this.ventaSinStock = false,
    required this.providerId,
    this.duplicar = false,
    required this.canalId,
    required this.giroNegocioId,
    this.descripcion,
  });
}
