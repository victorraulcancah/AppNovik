import '../../domain/entities/sale_entity.dart';

double? _double(dynamic v) =>
    v is num ? v.toDouble() : (v is String ? double.tryParse(v) : null);

int? _int(dynamic v) =>
    v is num ? v.toInt() : (v is String ? int.tryParse(v) : null);

bool _bool(dynamic v) => v == true || v == 1 || v == '1';

String? _text(dynamic v) {
  if (v is! String) return null;
  final t = v.trim();
  return t.isEmpty ? null : t;
}

/// Cliente de `GET /clientes/search`: razón social, o nombre y apellido.
ClientEntity clientFromJson(Map<String, dynamic> json) {
  final razon = _text(json['razon_social']);
  final fullName = '${json['name'] ?? ''} ${json['last_name'] ?? ''}'.trim();
  final ejecutivo = json['ejecutivo_comercial'];

  return ClientEntity(
    id: _int(json['id']) ?? 0,
    name: razon ?? (fullName.isEmpty ? '-' : fullName),
    documento: _text(json['dni_ruc']),
    tipo: _text(json['tipo']),
    listPriceId: _int(json['list_price_id']),
    paymentMethodId: _int(json['payment_method_id']),
    ejecutivoComercialId: _int(json['ejecutivo_comercial_id']),
    ejecutivoComercial: ejecutivo is Map ? _text(ejecutivo['name']) : null,
  );
}

List<ClientEntity> clientsFromJson(dynamic json) => json is List
    ? json.whereType<Map<String, dynamic>>().map(clientFromJson).toList()
    : const [];

/// Producto de `GET /productos/search`: `warehouses[].pivot.stock` y
/// `list_prices[].pivot.precio` dan el stock por almacén y el precio por lista.
SaleProductEntity saleProductFromJson(Map<String, dynamic> json) {
  Map<int, double> pivots(dynamic list, String field) {
    final result = <int, double>{};
    if (list is! List) return result;
    for (final e in list) {
      if (e is! Map) continue;
      final id = _int(e['id']);
      final pivot = e['pivot'];
      final value = pivot is Map ? _double(pivot[field]) : null;
      if (id != null && value != null) result[id] = value;
    }
    return result;
  }

  final brand = json['brand'];
  final measure = json['measure'];
  return SaleProductEntity(
    id: _int(json['id']) ?? 0,
    codigo: (json['codigo'] ?? '') as String,
    name: (json['name'] ?? '') as String,
    marca: brand is Map ? _text(brand['name']) : null,
    brandId: _int(json['brand_id']) ?? (brand is Map ? _int(brand['id']) : null),
    categoryId: _int(json['category_id']),
    unidad: measure is Map ? _text(measure['name']) : null,
    esServicio: json['tipo'] == 's',
    ventaSinStock: _bool(json['vender_sin_stock']),
    stockPorAlmacen: pivots(json['warehouses'], 'stock'),
    precioPorLista: pivots(json['list_prices'], 'precio'),
  );
}

List<SaleProductEntity> saleProductsFromJson(dynamic json) => json is List
    ? json.whereType<Map<String, dynamic>>().map(saleProductFromJson).toList()
    : const [];

/// `GET /categorias` y `GET /marcas`: `[{id, name}]`.
List<({int id, String name})> _idNames(dynamic json) {
  if (json is! List) return const [];
  final result = <({int id, String name})>[];
  for (final e in json) {
    if (e is! Map) continue;
    final id = _int(e['id']);
    final name = _text(e['name']);
    if (id != null && name != null) result.add((id: id, name: name));
  }
  return result;
}

SaleProductFiltersEntity saleProductFiltersFromJson({
  required dynamic categorias,
  required dynamic marcas,
}) =>
    SaleProductFiltersEntity(categorias: _idNames(categorias), marcas: _idNames(marcas));

List<PaymentMethodEntity> paymentMethodsFromJson(dynamic json) {
  if (json is! List) return const [];
  final result = <PaymentMethodEntity>[];
  for (final e in json) {
    if (e is! Map) continue;
    final id = _int(e['id']);
    final name = e['name'];
    if (id != null && name is String) {
      result.add(PaymentMethodEntity(id: id, name: name));
    }
  }
  return result;
}

/// Cuerpo de `POST /ventas` para una venta al contado en soles, con los mismos
/// campos que arma la web. `punto_venta` y `tipo_de_cambio` los lee el backend
/// aunque no apliquen, por eso se envían siempre.
Map<String, dynamic> saleToJson(
  SaleFormEntity form, {
  required int companyId,
  required int userId,
}) {
  final total = form.total;
  final observaciones = form.observaciones?.trim();

  return {
    'tipo_documento': form.tipoDocumento.apiValue,
    'totales_soles': total,
    'totales_dolares': 0,
    'company_id': companyId,
    'user_id': userId,
    'client_id': form.client!.id,
    'warehouse_id': form.warehouseId,
    'punto_venta': false,
    'tipo_de_cambio': 1,
    'metodo_entrega': 'e',
    if (observaciones != null && observaciones.isNotEmpty) 'observaciones': observaciones,
    'product_sales': [
      for (final l in form.lines)
        {
          'product_id': l.product.id,
          'cantidad': l.cantidad,
          'precio': l.precio,
          'dto_fijo': false,
          'dolares': false,
          'dto': 0,
          'monto_dto': 0,
          'subtotal': l.subtotal,
          'subtotal_con_dto': l.subtotal,
        },
    ],
    'payment_methods': [
      {'payment_method_id': form.paymentMethodId, 'monto': total},
    ],
  };
}
