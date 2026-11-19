import '../../domain/entities/report_ranking_entity.dart';
import '../../domain/entities/report_entity.dart';

double _double(dynamic v) => v is num ? v.toDouble() : (v is String ? double.tryParse(v) ?? 0 : 0);

int? _int(dynamic v) => v is num ? v.toInt() : (v is String ? int.tryParse(v) : null);

String? _clean(dynamic v) => v is String && v.trim().isNotEmpty ? v.trim() : null;

/// En qué campo trae cada reporte el nombre de la fila.
String _nameKey(ReportKind kind) => switch (kind) {
  ReportKind.departamentos => 'departamento',
  ReportKind.marcas => 'marca',
  ReportKind.categorias => 'categoria',
  ReportKind.clientes => 'cliente',
  // `reporte-vendedores-v2` devuelve el usuario con `name`.
  _ => 'name',
};

/// Lee una página de `GET /ventas/reporte-{departamentos,vendedores,marcas,categorias,clientes}-v2`.
///
/// La forma es `{success, data: [...], resumen: {total_ventas, ...}, pagination: {total, has_more}}`.
/// Cuando no hay ventas, el servidor responde solo `data: []` (sin `resumen` ni `pagination`), y
/// sin `resumen` el total sale de sumar las filas.
RankingReport rankingFromJson(ReportKind kind, dynamic body) {
  if (body is! Map) return const RankingReport();
  final data = body['data'];
  final key = _nameKey(kind);
  final rows = <RankingRow>[
    if (data is List)
      for (final e in data.whereType<Map>())
        RankingRow(
          id: _int(e['id']),
          name: (e[key] is String && (e[key] as String).trim().isNotEmpty) ? (e[key] as String).trim() : '-',
          venta: _double(e['venta_total']),
          nVentas: _int(e['n_de_ventas'] ?? e['numero_ventas']) ?? 0,
          subtotal: _double(e['subtotal']),
          descuento: _double(e['descuento']),
          margen: _double(e['margen']),
          documento: _clean(e['documento']),
          categoria: _clean(e['categoria']),
        ),
  ];

  final resumen = body['resumen'];
  final pagination = body['pagination'];
  final total = resumen is Map && resumen['total_ventas'] != null
      ? _double(resumen['total_ventas'])
      : rows.fold<double>(0, (sum, r) => sum + r.venta);

  return RankingReport(
    rows: rows,
    total: total,
    totalRows: pagination is Map ? (_int(pagination['total']) ?? rows.length) : rows.length,
    hasMore: pagination is Map && pagination['has_more'] == true,
  );
}

String _text(dynamic v) => v == null ? '' : '$v'.trim();

/// Lee `productos-por-*` (vendedores, departamento, marcas, categorías, cliente): `data` con
/// `id, codigo, nombre, cantidad, subtotal, margen` y, si el reporte pagina, `pagination.has_more`.
RankingProductsPage rankingProductsFromJson(dynamic body) {
  if (body is! Map) return const RankingProductsPage();
  final data = body['data'];
  final pagination = body['pagination'];
  return RankingProductsPage(
    products: [
      if (data is List)
        for (final e in data.whereType<Map>())
          RankingProduct(
            id: _int(e['id']) ?? 0,
            codigo: _text(e['codigo']),
            name: _text(e['nombre']).isEmpty ? '-' : _text(e['nombre']),
            cantidad: _double(e['cantidad']),
            venta: _double(e['subtotal']),
            margen: _double(e['margen']),
          ),
    ],
    hasMore: pagination is Map && pagination['has_more'] == true,
  );
}

/// Lee `documentos-por-producto-sucursal-v2`: `data` con `id, nro_documento, tipo_documento, fecha...`,
/// rotulados como en Productos y servicios (`Boleta Nro: B001-0001`, `Venta Nro: V001-0005`).
List<SalesReportDocumentEntity> reportDocumentsFromJson(dynamic body) {
  final data = body is Map ? body['data'] : null;
  if (data is! List) return const [];
  return [
    for (final e in data.whereType<Map>())
      if (_int(e['id']) != null) _document(e),
  ];
}

SalesReportDocumentEntity _document(Map e) {
  final raw = _text(e['nro_documento']).isNotEmpty ? _text(e['nro_documento']) : _text(e['nro_documento_raw']);
  final kind = _text(e['tipo_documento']).toLowerCase();
  var numero = raw.toUpperCase();
  if (RegExp(r'^\d+$').hasMatch(numero)) numero = 'V001-${numero.padLeft(4, '0')}';
  final tipo = kind.contains('factura')
      ? 'Factura'
      : kind.contains('boleta')
          ? 'Boleta'
          : (numero.startsWith('F') ? 'Factura' : (numero.startsWith('B') ? 'Boleta' : 'Venta'));
  return SalesReportDocumentEntity(id: _int(e['id'])!, tipo: tipo, numero: numero);
}
