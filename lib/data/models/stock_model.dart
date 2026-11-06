import '../../domain/entities/import_entity.dart';
import '../../domain/entities/stock_entity.dart';
import '../../domain/entities/stock_manage_entity.dart';

double? _double(dynamic v) =>
    v is num ? v.toDouble() : (v is String ? double.tryParse(v) : null);

int? _int(dynamic v) =>
    v is num ? v.toInt() : (v is String ? int.tryParse(v) : null);

bool _bool(dynamic v) => v == true || v == 1 || v == '1';

/// Elemento de `GET /almacenes/details`: un producto con su existencia en el
/// almacén pedido (`warehouses[0].pivot`) y los acumulados por despachar y por
/// recibir (`cantidad_total*`, `transfers_pendientes`), que vienen como texto o `null`.
StockItemEntity stockItemFromJson(Map<String, dynamic> json) {
  final warehouses = json['warehouses'];
  Map? pivot;
  if (warehouses is List && warehouses.isNotEmpty && warehouses.first is Map) {
    final p = (warehouses.first as Map)['pivot'];
    if (p is Map) pivot = p;
  }

  final prices = json['list_prices'];
  double? precio;
  if (prices is List && prices.isNotEmpty && prices.first is Map) {
    final p = (prices.first as Map)['pivot'];
    if (p is Map) precio = _double(p['precio']);
  }

  final brand = json['brand'];

  return StockItemEntity(
    productId: _int(json['id']) ?? 0,
    codigo: (json['codigo'] ?? '') as String,
    name: (json['name'] ?? '') as String,
    esServicio: json['tipo'] == 's',
    marca: brand is Map ? brand['name'] as String? : null,
    disponible: _double(pivot?['stock']) ?? 0,
    porDespachar: (_double(json['cantidad_total']) ?? 0) +
        (_double(json['cantidad_total_cotizaciones']) ?? 0) +
        (_double(json['cantidad_total_transferencias']) ?? 0),
    porRecibir: _double(json['transfers_pendientes']) ?? 0,
    ventaSinStock: _bool(json['vender_sin_stock']),
    costoPromedio: _double(pivot?['costo_promedio']),
    precio: precio,
    ultimoCosto: _double(pivot?['ultimo_costo_promedio']),
  );
}

class StockPageModel extends StockPageEntity {
  const StockPageModel({
    required super.items,
    required super.currentPage,
    required super.lastPage,
    required super.total,
    super.costoTotal,
    super.totalVenta,
  });

  factory StockPageModel.fromJson(Map<String, dynamic> json) {
    final data = json['data'];
    return StockPageModel(
      items: data is List
          ? data.whereType<Map<String, dynamic>>().map(stockItemFromJson).toList()
          : const [],
      currentPage: _int(json['current_page']) ?? 1,
      lastPage: _int(json['last_page']) ?? 1,
      total: _int(json['total']) ?? 0,
      costoTotal: _double(json['costo_total']) ?? 0,
      totalVenta: _double(json['total_venta']) ?? 0,
    );
  }
}

/// Listas de precios: `{id, name, tipo_moneda: 'd'|'s'}`.
List<PriceListEntity> priceListsFromJson(dynamic json) {
  if (json is! List) return const [];
  final result = <PriceListEntity>[];
  for (final e in json) {
    if (e is! Map) continue;
    final id = _int(e['id']);
    final name = e['name'];
    if (id != null && name is String) {
      result.add(PriceListEntity(id: id, name: name, esDolares: e['tipo_moneda'] == 'd'));
    }
  }
  return result;
}

/// Producto de `GET /productos/search`: marca, último costo de entrada (`stocks[0].pivot.costo`)
/// y `warehouses[].pivot` con lo que tiene en cada almacén.
StockProductEntity stockProductFromJson(Map<String, dynamic> json) {
  final brand = json['brand'];

  double? ultimoCosto;
  final stocks = json['stocks'];
  if (stocks is List && stocks.isNotEmpty && stocks.first is Map) {
    final pivot = (stocks.first as Map)['pivot'];
    if (pivot is Map) ultimoCosto = _double(pivot['costo']);
  }

  final levels = <int, StockWarehouseLevel>{};
  final warehouses = json['warehouses'];
  if (warehouses is List) {
    for (final w in warehouses) {
      if (w is! Map) continue;
      final id = _int(w['id']);
      if (id == null) continue;
      final pivot = w['pivot'];
      levels[id] = StockWarehouseLevel(
        stock: pivot is Map ? _double(pivot['stock']) ?? 0 : 0,
        costoPromedio: pivot is Map ? _double(pivot['costo_promedio']) ?? 0 : 0,
      );
    }
  }

  return StockProductEntity(
    id: _int(json['id']) ?? 0,
    codigo: (json['codigo'] ?? '') as String,
    name: (json['name'] ?? '') as String,
    marca: brand is Map ? brand['name'] as String? : null,
    ultimoCosto: ultimoCosto,
    levels: levels,
  );
}

List<StockProductEntity> stockProductsFromJson(dynamic json) {
  if (json is! List) return const [];
  return json.whereType<Map<String, dynamic>>().map(stockProductFromJson).toList();
}

/// Respuesta de `POST /stock/import`: `message` trae las filas leídas (una lista, o un objeto
/// con las posiciones como claves cuando el servidor descartó alguna) y `failures` las filas con
/// error (`{clave: {row, errors}}`).
StockImportResultEntity stockImportResultFromJson(dynamic body) {
  if (body is! Map) return const StockImportResultEntity();

  final rows = <StockImportRow>[];
  final message = body['message'];
  final entries = message is Map ? message.values : (message is List ? message : const []);
  for (final r in entries) {
    if (r is! Map) continue;
    final costo = r['costo'];
    rows.add(StockImportRow(
      row: _int(r['row_number']) ?? 0,
      codigo: '${r['codigo'] ?? ''}',
      costo: costo == null || '$costo'.isEmpty ? null : '$costo',
      stock: '${r['stock'] ?? ''}',
    ));
  }

  final failures = <ImportFailureEntity>[];
  final raw = body['failures'];
  final failureEntries = raw is Map ? raw.values : (raw is List ? raw : const []);
  for (final f in failureEntries) {
    if (f is! Map) continue;
    failures.add(ImportFailureEntity(
      row: _int(f['row']) ?? 0,
      errors: [for (final e in (f['errors'] is List ? f['errors'] as List : const [])) '$e'],
    ));
  }
  return StockImportResultEntity(rows: rows, failures: failures);
}
