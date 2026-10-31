import 'dart:typed_data';

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

/// Qué catálogo se amplía desde el formulario (el "+" junto a cada lista, como en la web).
enum CatalogKind {
  medida('Unidad de medida', 'la unidad de medida', '/medidas'),
  marca('Marca', 'la marca', '/marcas'),
  categoria('Categoría', 'la categoría', '/categorias'),
  canal('Canal', 'el canal', '/canales'),
  giro('Giro de negocio', 'el giro de negocio', '/giros-negocio');

  final String label;

  /// Con su artículo, para frases como "Crear la marca".
  final String articulado;
  final String endpoint;
  const CatalogKind(this.label, this.articulado, this.endpoint);
}

/// Foto elegida para el producto (JPG, PNG o WEBP de menos de 2 MB).
class ProductPhotoEntity {
  final String name;
  final Uint8List bytes;

  const ProductPhotoEntity({required this.name, required this.bytes});
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

  /// Foto nueva (reemplaza la actual) y si se pide quitar la actual.
  final ProductPhotoEntity? foto;
  final bool eliminarImagen;

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
    this.foto,
    this.eliminarImagen = false,
  });
}
