import '../../domain/entities/report_entity.dart';

double? _double(dynamic v) =>
    v is num ? v.toDouble() : (v is String ? double.tryParse(v) : null);

int? _int(dynamic v) =>
    v is num ? v.toInt() : (v is String ? int.tryParse(v) : null);

DateTime _date(dynamic v) =>
    (v is String ? DateTime.tryParse(v) : null) ?? DateTime.now();

Map<String, dynamic> _map(dynamic v) => v is Map<String, dynamic> ? v : const {};

List<Map<String, dynamic>> _list(dynamic v) =>
    v is List ? v.whereType<Map<String, dynamic>>().toList() : const [];

RankedItemEntity _ranked(Map<String, dynamic> j) {
  final codigo = j['codigo'];
  return RankedItemEntity(
    codigo: codigo is String && codigo.isNotEmpty ? codigo : null,
    nombre: (j['nombre'] as String?)?.trim().isNotEmpty == true
        ? (j['nombre'] as String).trim()
        : 'Sin nombre',
    monto: _double(j['monto']) ?? 0,
  );
}

List<RankedItemEntity> _rankedList(dynamic v) => _list(v).map(_ranked).toList();

GoalLight _light(dynamic v) => switch (v) {
      'rojo' => GoalLight.rojo,
      'ambar' => GoalLight.ambar,
      'verde' => GoalLight.verde,
      _ => GoalLight.gris,
    };

QuotePriority _priority(dynamic v) => switch (v) {
      'alta' => QuotePriority.alta,
      'media' => QuotePriority.media,
      _ => QuotePriority.baja,
    };

/// Respuesta de `GET /ventas/resumen-ejecutivo`. Solo se leen los bloques que
/// muestra la app; el resto (tareas, cumpleaños, clientes en caída...) se ignora.
ExecutiveSummaryEntity executiveSummaryFromJson(Map<String, dynamic> json) {
  final v = _map(json['ventas']);
  final m = _map(json['meta']);
  final c = _map(json['cotizaciones']);
  final e = _map(json['evolucion']);

  return ExecutiveSummaryEntity(
    vendedor: (json['vendedor'] as String?) ?? '',
    desde: _date(json['desde']),
    hasta: _date(json['hasta']),
    desdeAnterior: _date(json['desde_anterior']),
    hastaAnterior: _date(json['hasta_anterior']),
    ventas: SalesFiguresEntity(
      total: _double(v['total']) ?? 0,
      totalAnterior: _double(v['total_anterior']) ?? 0,
      totalVariacion: _double(v['variacion_pct']),
      numero: _int(v['numero']) ?? 0,
      numeroAnterior: _int(v['numero_anterior']) ?? 0,
      numeroVariacion: _double(v['numero_variacion_pct']),
      ticket: _double(v['ticket']) ?? 0,
      ticketAnterior: _double(v['ticket_anterior']) ?? 0,
      ticketVariacion: _double(v['ticket_variacion_pct']),
    ),
    porAlmacen: _rankedList(json['por_almacen']),
    meta: GoalEntity(
      aplica: m['aplica'] == true,
      monto: _double(m['monto']) ?? 0,
      venta: _double(m['venta']) ?? 0,
      falta: _double(m['falta']) ?? 0,
      avance: _double(m['avance']),
      semaforo: _light(m['semaforo']),
    ),
    cotizacionesCantidad: _int(c['cantidad']) ?? 0,
    cotizacionesMonto: _double(c['monto']) ?? 0,
    cotizaciones: [
      for (final q in _list(json['cotizaciones_lista']))
        PendingQuoteEntity(
          id: _int(q['id']) ?? 0,
          documento: '${q['documento'] ?? ''}',
          cliente: (q['cliente'] as String?) ?? '-',
          monto: _double(q['monto']) ?? 0,
          dias: _int(q['dias']) ?? 0,
          prioridad: _priority(q['prioridad']),
        ),
    ],
    evolucion: EvolutionEntity(
      anioActual: _int(e['anio_actual']) ?? DateTime.now().year,
      anioAnterior: _int(e['anio_anterior']) ?? DateTime.now().year - 1,
      meses: [
        for (final mes in _list(e['meses']))
          MonthSalesEntity(
            mes: _int(mes['mes']) ?? 0,
            anterior: _double(mes['anterior']) ?? 0,
            actual: _double(mes['actual']) ?? 0,
          ),
      ],
    ),
    topProductos: _rankedList(json['top_productos']),
    topClientes: _rankedList(json['top_clientes']),
    departamentos: _rankedList(json['departamentos']),
  );
}
