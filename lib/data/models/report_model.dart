import '../../domain/entities/report_entity.dart';

double _double(dynamic v) => v is num ? v.toDouble() : (v is String ? double.tryParse(v) ?? 0 : 0);

int? _int(dynamic v) => v is num ? v.toInt() : (v is String ? int.tryParse(v) : null);

String? _text(dynamic v) {
  if (v is! String) return null;
  final t = v.trim();
  return t.isEmpty ? null : t;
}

String _pad(dynamic v, int width) => '${_int(v) ?? 0}'.padLeft(width, '0');

SalesReportDayEntity _day(Map<String, dynamic> j) => SalesReportDayEntity(
      name: _text(j['name']) ?? '',
      ventasSoles: _double(j['ventas_soles']),
      ventasDolares: _double(j['ventas_dolares']),
      ventasDolaresASoles: _double(j['ventas_dolares_a_soles']),
      unidades: _double(j['unidades']),
    );

SalesReportProductEntity _product(Map<String, dynamic> j) => SalesReportProductEntity(
      id: _int(j['id']) ?? 0,
      codigo: _text(j['codigo']) ?? '',
      name: _text(j['name']) ?? '-',
      marca: j['brand'] is Map ? _text((j['brand'] as Map)['name']) : null,
      imagen: _text(j['img']),
      cantidad: _double(j['cantidad']),
      subtotal: _double(j['subtotal']),
      descuento: _double(j['descuento']),
      venta: _double(j['venta']),
      costo: _double(j['costo']),
    );

/// Una venta del reporte, rotulada como en la web: `Boleta Nro: B001-0001` o `Venta Nro: V001-0005`.
SalesReportDocumentEntity _document(Map<String, dynamic> j) {
  final boleta = j['boleta'];
  final String tipo;
  final String numero;
  if (boleta is Map && boleta['tipo'] is String) {
    final t = (boleta['tipo'] as String).toLowerCase();
    tipo = t == 'f' ? 'Factura' : 'Boleta';
    numero = '${t.toUpperCase()}${_pad(boleta['serie'], 3)}-${_pad(boleta['numero'], 4)}';
  } else {
    tipo = 'Venta';
    final raw = '${j['nro_documento_raw'] ?? j['nro_documento'] ?? ''}'.toUpperCase();
    numero = raw.startsWith('V') ? raw : 'V001-${raw.padLeft(4, '0')}';
  }
  final products = j['products'];
  return SalesReportDocumentEntity(
    id: _int(j['id']) ?? 0,
    tipo: tipo,
    numero: numero,
    productIds: products is List
        ? [for (final p in products.whereType<Map>()) if (_int(p['id']) != null) _int(p['id'])!]
        : const [],
  );
}

/// Respuesta de `GET /ventas/reporte`.
SalesReportEntity salesReportFromJson(Map<String, dynamic> json) {
  List<T> list<T>(String key, T Function(Map<String, dynamic>) map) {
    final raw = json[key];
    return raw is List ? [for (final e in raw.whereType<Map<String, dynamic>>()) map(e)] : <T>[];
  }

  return SalesReportEntity(
    days: list('ventas', _day),
    documents: list('sales', _document),
    products: list('data', _product),
    totalProducts: _int(json['total']) ?? 0,
    countVentas: _int(json['countVentas']) ?? 0,
    unidades: _double(json['unidadesVendidas']),
    totalVentas: _double(json['totalVentas']),
    totalCostos: _double(json['totalCostos']),
  );
}

/// Opciones de un filtro (marcas, categorías, sucursales...): `[{id, name}]`, con el nombre en
/// `display_label`, `display_name`, `name` o, en usuarios y clientes, nombre y apellido.
List<ReportOption> reportOptionsFromJson(dynamic json) {
  final list = json is List ? json : (json is Map && json['data'] is List ? json['data'] as List : const []);
  final result = <ReportOption>[];
  for (final e in list) {
    if (e is! Map) continue;
    final id = e['id'];
    if (id == null) continue;
    final name = _text(e['display_label']) ??
        _text(e['display_name']) ??
        _text(e['name']) ??
        '${e['first_name'] ?? ''} ${e['last_name'] ?? ''}'.trim();
    result.add((id: '$id', name: name.isEmpty ? '#$id' : name));
  }
  return result;
}
