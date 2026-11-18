import '../../domain/entities/import_entity.dart';
import '../../domain/entities/price_list_entity.dart';

double? _doubleOrNull(dynamic v) {
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v.trim());
  return null;
}

int? _int(dynamic v) {
  if (v is int) return v;
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v.trim());
  return null;
}

String? _text(dynamic v) {
  if (v is! String) return null;
  final t = v.trim();
  return t.isEmpty ? null : t;
}

bool _bool(dynamic v, {bool defaultValue = true}) {
  if (v == null) return defaultValue;
  return v == true || v == 1 || v == '1' || v == 'true';
}

/// Una lista de `GET /lista-de-precios` (o la que devuelven crear y editar):
/// `{id, name, tipo_moneda: 's'|'d', estado, company_id}`.
PriceListEntity priceListFromJson(Map<String, dynamic> j) => PriceListEntity(
  id: _int(j['id']) ?? 0,
  name: _text(j['name']) ?? '—',
  currency: j['tipo_moneda'] == 'd' ? 'd' : 's',
  active: _bool(j['estado']),
);

/// El paginador de Laravel: `{data, current_page, last_page, total}`.
PriceListPageEntity priceListPageFromJson(Map<String, dynamic> j) {
  final data = j['data'];
  return PriceListPageEntity(
    items: data is List
        ? [
            for (final c in data)
              if (c is Map) priceListFromJson(c.cast<String, dynamic>()),
          ]
        : const [],
    currentPage: _int(j['current_page']) ?? 1,
    lastPage: _int(j['last_page']) ?? 1,
    total: _int(j['total']) ?? 0,
  );
}

/// La web trata `/storage/` solo como "sin imagen".
String? _imagen(dynamic v) {
  if (v is! String) return null;
  return v.replaceFirst('/storage/', '').isEmpty ? null : v;
}

/// Un producto del detalle (`GET /lista-de-precios/details`, y lo que devuelve `PATCH
/// /lista-de-precios/{id}`): `{id, tipo, codigo, name, img, brand: {name}, list_prices: [{pivot:
/// {precio}}]}`. El servidor solo trae la lista que se pidió, así que el precio es el de
/// `list_prices[0]`.
PriceListProductEntity priceListProductFromJson(Map<String, dynamic> j) {
  final prices = j['list_prices'];
  double? precio;
  if (prices is List && prices.isNotEmpty && prices.first is Map) {
    final pivot = (prices.first as Map)['pivot'];
    if (pivot is Map) precio = _doubleOrNull(pivot['precio']);
  }
  final brand = j['brand'];
  return PriceListProductEntity(
    id: _int(j['id']) ?? 0,
    tipo: j['tipo'] == 's' ? 's' : 'p',
    codigo: _text(j['codigo']) ?? '',
    name: _text(j['name']) ?? '—',
    marca: brand is Map ? _text(brand['name']) : null,
    imagen: _imagen(j['img']),
    precio: precio,
  );
}

PriceListProductPageEntity priceListProductPageFromJson(
  Map<String, dynamic> j,
) {
  final data = j['data'];
  return PriceListProductPageEntity(
    items: data is List
        ? [
            for (final p in data)
              if (p is Map) priceListProductFromJson(p.cast<String, dynamic>()),
          ]
        : const [],
    currentPage: _int(j['current_page']) ?? 1,
    lastPage: _int(j['last_page']) ?? 1,
    total: _int(j['total']) ?? 0,
  );
}

/// Respuesta de `POST /lista-de-precios/{id}/import`: `{message}` o `{failures: [...]}`. Cada falla
/// puede ser `{row, attribute, errors: [...]}` (una fila inválida) o un texto suelto (un error de
/// lectura); `failures` puede venir como lista o como mapa.
ImportResultEntity priceListImportResultFromJson(dynamic body) {
  if (body is! Map) return const ImportResultEntity();
  final raw = body['failures'];
  final failures = <ImportFailureEntity>[];
  final entries = raw is Map ? raw.values : (raw is List ? raw : const []);
  for (final f in entries) {
    if (f is Map) {
      failures.add(
        ImportFailureEntity(
          row: _int(f['row']) ?? 0,
          errors: [
            for (final e
                in (f['errors'] is List ? f['errors'] as List : const []))
              '$e',
          ],
        ),
      );
    } else if (f is String && f.trim().isNotEmpty) {
      failures.add(ImportFailureEntity(row: 0, errors: [f.trim()]));
    }
  }
  final message = body['message'];
  return ImportResultEntity(
    message: message is String && message.isNotEmpty
        ? message
        : 'Importación exitosa',
    failures: failures,
  );
}
