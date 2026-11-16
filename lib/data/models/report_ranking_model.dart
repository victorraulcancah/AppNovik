import '../../domain/entities/report_ranking_entity.dart';

double _double(dynamic v) => v is num ? v.toDouble() : (v is String ? double.tryParse(v) ?? 0 : 0);

int? _int(dynamic v) => v is num ? v.toInt() : (v is String ? int.tryParse(v) : null);

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
