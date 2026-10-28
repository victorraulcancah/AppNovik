import '../../domain/entities/product_entity.dart';

class ProductModel extends ProductEntity {
  const ProductModel({
    required super.id,
    required super.codigo,
    required super.name,
    super.sku,
    super.esServicio,
    super.activo,
    super.marca,
    super.categoria,
    super.unidad,
    super.stockTotal,
  });

  /// Elemento de `data` de `GET /productos`.
  factory ProductModel.fromJson(Map<String, dynamic> json) {
    return ProductModel(
      id: _int(json['id']) ?? 0,
      codigo: (json['codigo'] ?? '') as String,
      name: (json['name'] ?? '') as String,
      sku: json['sku'] as String?,
      esServicio: json['tipo'] == 's',
      activo: _bool(json['estado'], defaultValue: true),
      marca: _name(json['brand']),
      categoria: _name(json['category']),
      unidad: _name(json['measure']),
      stockTotal: _stock(json['warehouses']),
    );
  }

  static String? _name(dynamic relation) =>
      relation is Map ? relation['name'] as String? : null;

  /// Suma `pivot.stock` de cada almacén; `null` si ninguno trae el dato.
  static double? _stock(dynamic warehouses) {
    if (warehouses is! List) return null;
    double? total;
    for (final w in warehouses) {
      if (w is! Map) continue;
      final pivot = w['pivot'];
      final value = pivot is Map ? _double(pivot['stock']) : null;
      if (value != null) total = (total ?? 0) + value;
    }
    return total;
  }

  static int? _int(dynamic v) =>
      v is num ? v.toInt() : (v is String ? int.tryParse(v) : null);

  static double? _double(dynamic v) =>
      v is num ? v.toDouble() : (v is String ? double.tryParse(v) : null);

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
