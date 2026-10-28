import '../../domain/entities/product_entity.dart';

class ProductModel extends ProductEntity {
  const ProductModel({
    required super.id,
    required super.codigo,
    required super.name,
    super.esServicio,
    super.activo,
    super.marca,
    super.categoria,
    super.unidad,
    super.cantidadBloque,
    super.codBarra,
    super.sku,
    super.proveedor,
    super.descripcion,
    super.usuario,
    super.ventaSinStock,
    super.duplicar,
    super.creado,
    super.marcaId,
    super.categoriaId,
    super.unidadId,
    super.proveedorId,
    super.canalId,
    super.giroNegocioId,
  });

  /// Elemento de `data` de `GET /productos`.
  factory ProductModel.fromJson(Map<String, dynamic> json) {
    return ProductModel(
      id: _int(json['id']) ?? 0,
      codigo: (json['codigo'] ?? '') as String,
      name: (json['name'] ?? '') as String,
      esServicio: json['tipo'] == 's',
      activo: _bool(json['estado'], defaultValue: true),
      marca: _name(json['brand']),
      categoria: _name(json['category']),
      unidad: _name(json['measure']),
      cantidadBloque: _int(json['cantidad_bloque']),
      codBarra: json['cod_barra'] as String?,
      sku: json['sku'] as String?,
      proveedor: _name(json['provider']),
      descripcion: json['descripcion'] as String?,
      usuario: _name(json['user']),
      ventaSinStock: _bool(json['vender_sin_stock'], defaultValue: false),
      duplicar: _bool(json['duplicar'], defaultValue: false),
      creado: json['created_at'] is String
          ? DateTime.tryParse(json['created_at'] as String)?.toLocal()
          : null,
      marcaId: _int(json['brand_id']),
      categoriaId: _int(json['category_id']),
      unidadId: _int(json['measure_id']),
      proveedorId: _int(json['provider_id']),
      canalId: _int(json['canal_id']),
      giroNegocioId: _int(json['giro_negocio_id']),
    );
  }

  static String? _name(dynamic relation) =>
      relation is Map ? relation['name'] as String? : null;

  static int? _int(dynamic v) =>
      v is num ? v.toInt() : (v is String ? int.tryParse(v) : null);

  static bool _bool(dynamic v, {required bool defaultValue}) {
    if (v == null) return defaultValue;
    return v == true || v == 1 || v == '1';
  }
}

class ProductPageModel extends ProductPageEntity {
  const ProductPageModel({
    required super.items,
    required super.currentPage,
    required super.lastPage,
    required super.total,
  });

  /// Respuesta paginada de Laravel.
  factory ProductPageModel.fromJson(Map<String, dynamic> json) {
    final data = json['data'];
    return ProductPageModel(
      items: data is List
          ? data
              .whereType<Map<String, dynamic>>()
              .map(ProductModel.fromJson)
              .toList()
          : const [],
      currentPage: (json['current_page'] as num?)?.toInt() ?? 1,
      lastPage: (json['last_page'] as num?)?.toInt() ?? 1,
      total: (json['total'] as num?)?.toInt() ?? 0,
    );
  }
}
