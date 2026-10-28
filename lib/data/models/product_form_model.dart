import '../../domain/entities/product_form_entity.dart';

/// Cuerpo de `POST /productos` y `PUT /productos/{id}`.
extension ProductFormJson on ProductFormEntity {
  Map<String, dynamic> toJson({required int companyId, required bool editing}) {
    return {
      'company_id': companyId,
      'tipo': tipo,
      'codigo': codigo,
      // Al crear, el backend genera el SKU y el código de barras si no vienen.
      if (sku != null && sku!.isNotEmpty) 'sku': sku,
      if (codBarra != null && codBarra!.isNotEmpty) 'cod_barra': codBarra,
      'name': name,
      'estado': estado,
      if (measureId != null) 'measure_id': measureId,
      if (cantidadBloque != null) 'cantidad_bloque': cantidadBloque,
      'brand_id': brandId,
      'category_id': categoryId,
      'vender_sin_stock': ventaSinStock,
      'provider_id': providerId,
      'duplicar': duplicar,
      'canal_id': canalId,
      'giro_negocio_id': giroNegocioId,
      if (descripcion != null && descripcion!.isNotEmpty) 'descripcion': descripcion,
      // La edición exige este campo (la web lo manda siempre).
      if (editing) 'eliminar_imagen': false,
    };
  }
}

/// Catálogos: la mayoría trae `name`; canales y giros traen `nombre`.
List<CatalogItemEntity> catalogFromJson(dynamic json) {
  if (json is! List) return const [];
  final items = <CatalogItemEntity>[];
  for (final e in json) {
    if (e is! Map) continue;
    final id = e['id'];
    final name = e['name'] ?? e['nombre'];
    if (id is num && name is String) {
      items.add(CatalogItemEntity(id: id.toInt(), name: name));
    }
  }
  return items;
}
