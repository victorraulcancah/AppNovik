import '../../domain/entities/inicio_entity.dart';

double _double(dynamic v) => v is num ? v.toDouble() : (v is String ? double.tryParse(v) ?? 0 : 0);

double? _doubleOrNull(dynamic v) => v == null ? null : _double(v);

int _int(dynamic v) => v is num ? v.toInt() : (v is String ? int.tryParse(v) ?? 0 : 0);

int? _intOrNull(dynamic v) => v is num ? v.toInt() : (v is String ? int.tryParse(v) : null);

String? _text(dynamic v) {
  if (v is! String) return null;
  final t = v.trim();
  return t.isEmpty ? null : t;
}

DateTime _date(dynamic v) => (v is String ? DateTime.tryParse(v) : null) ?? DateTime(2000);

DateTime? _dateOrNull(dynamic v) => v is String ? DateTime.tryParse(v) : null;

Map<String, dynamic> _map(dynamic v) => v is Map<String, dynamic> ? v : const {};

List<Map<String, dynamic>> _list(dynamic v) =>
    v is List ? [for (final e in v) if (e is Map<String, dynamic>) e] : const [];

GoalLight _light(dynamic v) => switch (v) {
  'rojo' => GoalLight.rojo,
  'ambar' => GoalLight.ambar,
  'verde' => GoalLight.verde,
  _ => GoalLight.gris,
};

GoalEntity _goal(dynamic raw) {
  final j = _map(raw);
  return GoalEntity(
    aplica: j['aplica'] == true,
    anio: _int(j['anio']),
    mes: _int(j['mes']),
    monto: _double(j['monto']),
    venta: _double(j['venta']),
    falta: _double(j['falta']),
    avance: _doubleOrNull(j['avance']),
    semaforo: _light(j['semaforo']),
  );
}

SalesFiguresEntity _figures(dynamic raw) {
  final j = _map(raw);
  return SalesFiguresEntity(
    total: _double(j['total']),
    totalAnterior: _double(j['total_anterior']),
    variacionPct: _doubleOrNull(j['variacion_pct']),
    numero: _int(j['numero']),
    numeroAnterior: _int(j['numero_anterior']),
    numeroVariacionPct: _doubleOrNull(j['numero_variacion_pct']),
    ticket: _double(j['ticket']),
    ticketAnterior: _double(j['ticket_anterior']),
    ticketVariacionPct: _doubleOrNull(j['ticket_variacion_pct']),
  );
}

RankedAmountEntity _ranked(Map<String, dynamic> j) => RankedAmountEntity(
  id: _intOrNull(j['id']),
  codigo: _text(j['codigo']),
  nombre: _text(j['nombre']) ?? '-',
  monto: _double(j['monto']),
  unidades: _double(j['unidades']),
);

EvolutionEntity _evolution(dynamic raw) {
  final j = _map(raw);
  return EvolutionEntity(
    anioActual: _int(j['anio_actual']),
    anioAnterior: _int(j['anio_anterior']),
    meses: [
      for (final m in _list(j['meses']))
        MonthPairEntity(mes: _int(m['mes']), anterior: _double(m['anterior']), actual: _double(m['actual'])),
    ],
  );
}

/// Las donas de la web (`{total, estados: [{clave, cantidad}]}`).
StatusCountsEntity _statesFromBreakdown(dynamic raw) {
  final counts = <String, int>{};
  for (final e in _list(_map(raw)['estados'])) {
    counts['${e['clave']}'] = _int(e['cantidad']);
  }
  return StatusCountsEntity(
    critico: counts['critico'] ?? 0,
    riesgo: counts['riesgo'] ?? 0,
    seguimiento: counts['seguimiento'] ?? 0,
  );
}

/// Los contadores sueltos (`critico`, `riesgo`, `seguimiento`) del resumen del equipo.
StatusCountsEntity _statesFlat(Map<String, dynamic> j) => StatusCountsEntity(
  critico: _int(j['critico']),
  riesgo: _int(j['riesgo']),
  seguimiento: _int(j['seguimiento']),
);

FallTotalsEntity _totals(dynamic raw) {
  final j = _map(raw);
  return FallTotalsEntity(
    anterior: _double(j['anterior']),
    actual: _double(j['actual']),
    variacion: _double(j['variacion']),
  );
}

FallClientsEntity _fallClients(Map<String, dynamic> j) => FallClientsEntity(
  total: _int(j['total']),
  totales: _totals(j['totales']),
  filas: [
    for (final f in _list(j['filas']))
      FallClientEntity(
        id: _int(f['id']),
        cliente: _text(f['cliente']) ?? '-',
        vendedor: _text(f['vendedor']),
        anterior: _double(f['anterior']),
        actual: _double(f['actual']),
        caidaPct: _doubleOrNull(f['caida_pct']),
        estado: _text(f['estado']) ?? '',
      ),
  ],
);

List<FallProductEntity> _fallProducts(dynamic raw) => [
  for (final p in _list(raw))
    FallProductEntity(
      id: _int(p['id']),
      codigo: _text(p['codigo']),
      producto: _text(p['producto']) ?? '-',
      anterior: _double(p['anterior']),
      actual: _double(p['actual']),
      variacion: _double(p['variacion']),
      caidaPct: _doubleOrNull(p['caida_pct']),
    ),
];

QuotePriority _priority(dynamic v) => switch (v) {
  'alta' => QuotePriority.alta,
  'media' => QuotePriority.media,
  _ => QuotePriority.baja,
};

List<DepartmentEntity> _departments(dynamic raw) => [
  for (final d in _list(raw))
    DepartmentEntity(
      nombre: _text(d['nombre']) ?? '-',
      monto: _double(d['monto']),
      participacion: _double(d['participacion']),
    ),
];

List<SellerGoalEntity> _sellers(dynamic raw) => [
  for (final v in _list(raw))
    SellerGoalEntity(
      id: _int(v['id']),
      nombre: _text(v['nombre']) ?? '-',
      venta: _double(v['venta']),
      meta: _doubleOrNull(v['meta']),
      avance: _doubleOrNull(v['avance']),
      semaforo: _light(v['semaforo']),
    ),
];

List<WarehouseSalesEntity> warehouseSalesFromJson(dynamic body) => [
  for (final w in _list(body))
    WarehouseSalesEntity(
      id: _int(w['id']),
      nombre: _text(w['name']) ?? '-',
      total: _double(w['total_ventas_convertidas']),
    ),
];

ExecutiveSummaryEntity executiveSummaryFromJson(Map<String, dynamic> j) {
  final quotes = _map(j['cotizaciones']);
  return ExecutiveSummaryEntity(
    vendedor: _text(j['vendedor']) ?? '',
    desde: _date(j['desde']),
    hasta: _date(j['hasta']),
    desdeAnterior: _date(j['desde_anterior']),
    hastaAnterior: _date(j['hasta_anterior']),
    ventas: _figures(j['ventas']),
    porAlmacen: [for (final a in _list(j['por_almacen'])) _ranked(a)],
    meta: _goal(j['meta']),
    cotizacionesCantidad: _int(quotes['cantidad']),
    cotizacionesMonto: _double(quotes['monto']),
    cotizaciones: [
      for (final c in _list(j['cotizaciones_lista']))
        PendingQuoteEntity(
          id: _int(c['id']),
          cliente: _text(c['cliente']) ?? '-',
          monto: _double(c['monto']),
          montoMoneda: _double(c['monto']),
          dias: _int(c['dias']),
          prioridad: _priority(c['prioridad']),
        ),
    ],
    evolucion: _evolution(j['evolucion']),
    topProductos: [for (final p in _list(j['top_productos'])) _ranked(p)],
    topClientes: [for (final c in _list(j['top_clientes'])) _ranked(c)],
    departamentos: [for (final d in _list(j['departamentos'])) _ranked(d)],
    clientesSinCompra: _statesFromBreakdown(j['clientes_sin_compra']),
    productosSinVenta: _statesFromBreakdown(j['productos_sin_venta']),
    conCaida: _fallClients(_map(_map(j['atencion'])['con_caida'])),
    tareas: [
      for (final t in _list(j['tareas']))
        TaskEntity(
          id: _int(t['id']),
          clienteId: _int(t['cliente_id']),
          cliente: _text(t['cliente']) ?? '-',
          tipo: _text(t['tipo']) ?? '',
          tipoEtiqueta: _text(t['tipo_etiqueta']) ?? '',
          accion: _text(t['accion']),
          fecha: _date(t['fecha']),
          vencida: t['vencida'] == true,
        ),
    ],
    cumpleanos: [
      for (final b in _list(j['cumpleanos']))
        BirthdayEntity(
          id: _int(b['id']),
          nombre: _text(b['nombre']) ?? '-',
          telefono: _text(b['telefono']),
          dia: _int(b['dia']),
          mes: _int(b['mes']),
          esHoy: b['es_hoy'] == true,
          yaPaso: b['ya_paso'] == true,
        ),
    ],
  );
}

TeamSummaryEntity teamSummaryFromJson(Map<String, dynamic> j) {
  final caida = _map(j['clientes_caida']);
  final productos = _map(j['productos_sin_ventas']);
  final quotes = _map(j['cotizaciones']);
  final managements = _map(j['gestiones']);
  return TeamSummaryEntity(
    jefe: _text(j['jefe']) ?? '',
    desde: _date(j['desde']),
    hasta: _date(j['hasta']),
    desdeAnterior: _date(j['desde_anterior']),
    hastaAnterior: _date(j['hasta_anterior']),
    ventas: _figures(j['ventas']),
    meta: _goal(j['meta']),
    evolucion: _evolution(j['evolucion']),
    vendedores: _sellers(j['vendedores']),
    topProductos: [for (final p in _list(j['top_productos'])) _ranked(p)],
    departamentos: _departments(j['departamentos']),
    clientesCaidaEstados: _statesFlat(caida),
    clientesCaida: _fallClients(caida),
    productosSinVentasEstados: _statesFlat(productos),
    productosMayorCaida: _fallProducts(productos['mayor_caida']),
    cotizacionesCantidad: _int(quotes['cantidad']),
    cotizacionesMonto: _double(quotes['monto']),
    cotizacionesSoles: _double(quotes['soles']),
    cotizacionesDolares: _double(quotes['dolares']),
    cotizaciones: [
      for (final c in _list(quotes['filas']))
        PendingQuoteEntity(
          id: _int(c['id']),
          cliente: _text(c['cliente']) ?? '-',
          vendedor: _text(c['vendedor']),
          monto: _double(c['monto']),
          montoMoneda: _double(c['monto_moneda']),
          enDolares: c['moneda'] == 'dolares',
          dias: _int(c['dias']),
          prioridad: _priority(c['prioridad']),
        ),
    ],
    gestiones: {
      for (final period in TaskPeriod.values)
        period: [
          for (final g in _list(managements[period.key]))
            ManagementEntity(
              tipo: _text(g['tipo']) ?? '',
              hechas: _int(g['hechas']),
              programadas: _int(g['programadas']),
              pct: _doubleOrNull(g['pct']),
            ),
        ],
    },
  );
}

IncomesEntity _incomes(dynamic raw) {
  final j = _map(raw);
  return IncomesEntity(
    total: _double(j['total']),
    totalSoles: _double(j['total_soles']),
    totalDolares: _double(j['total_dolares']),
    totalAnterior: _double(j['total_anterior']),
    variacionPct: _doubleOrNull(j['variacion_pct']),
    totalSolesAnterior: _double(j['total_soles_anterior']),
    totalDolaresAnterior: _double(j['total_dolares_anterior']),
    variacionSolesPct: _doubleOrNull(j['variacion_soles_pct']),
    variacionDolaresPct: _doubleOrNull(j['variacion_dolares_pct']),
    desdeAnterior: _dateOrNull(j['desde_anterior']),
    hastaAnterior: _dateOrNull(j['hasta_anterior']),
    metodos: [
      for (final m in _list(j['metodos']))
        PaymentIncomeEntity(
          metodo: _text(m['metodo']) ?? '-',
          entidad: _text(m['entidad']) ?? '',
          monto: _double(m['monto']),
          soles: _double(m['soles']),
          dolares: _double(m['dolares']),
          montoAnterior: _double(m['monto_anterior']),
          solesAnterior: _double(m['soles_anterior']),
          dolaresAnterior: _double(m['dolares_anterior']),
        ),
    ],
  );
}

CeoSummaryEntity ceoSummaryFromJson(Map<String, dynamic> j) {
  final sales = _map(j['ventas']);
  final ind = _map(j['indicadores']);
  final cxc = _map(j['cuentas_por_cobrar']);
  final news = _map(j['nuevos_clientes']);
  final productos = _map(j['productos_sin_ventas']);
  return CeoSummaryEntity(
    ceo: _text(j['ceo']) ?? '',
    empresa: _text(j['empresa']) ?? '',
    desde: _date(j['desde']),
    hasta: _date(j['hasta']),
    desdeAnterior: _date(j['desde_anterior']),
    hastaAnterior: _date(j['hasta_anterior']),
    sucursal: _intOrNull(j['sucursal']),
    sucursales: [
      for (final s in _list(j['sucursales']))
        WarehouseOption(id: _int(s['id']), name: _text(s['name']) ?? '-'),
    ],
    ventas: CeoSalesEntity(
      total: _double(sales['total']),
      totalAnterior: _double(sales['total_anterior']),
      variacionPct: _doubleOrNull(sales['variacion_pct']),
      mesAnterior: _double(sales['mes_anterior']),
      mesAnteriorPct: _doubleOrNull(sales['mes_anterior_pct']),
      mesAnteriorDesde: _date(sales['mes_anterior_desde']),
      mesAnteriorHasta: _date(sales['mes_anterior_hasta']),
      proyeccion: _doubleOrNull(sales['proyeccion']),
      numero: _int(sales['numero']),
      ticket: _double(sales['ticket']),
    ),
    meta: _goal(j['meta']),
    evolucion: _evolution(j['evolucion']),
    indicadores: CeoIndicatorsEntity(
      ventasAcumuladas: _double(ind['ventas_acumuladas']),
      ventasAcumuladasAnterior: _double(ind['ventas_acumuladas_anterior']),
      ventasAcumuladasPct: _doubleOrNull(ind['ventas_acumuladas_pct']),
      utilidadEstimada: _double(ind['utilidad_estimada']),
      margenPct: _doubleOrNull(ind['margen_pct']),
      cotizacionesMonto: _double(ind['cotizaciones_monto']),
      cotizacionesCantidad: _int(ind['cotizaciones_cantidad']),
      clientesActivos: _int(ind['clientes_activos']),
      clientesActivosAnterior: _int(ind['clientes_activos_anterior']),
      clientesActivosPct: _doubleOrNull(ind['clientes_activos_pct']),
    ),
    vendedores: _sellers(j['vendedores']),
    departamentos: _departments(j['departamentos']),
    canales: [
      for (final c in _list(j['canales']))
        ChannelEntity(
          codigo: _text(c['codigo']),
          nombre: _text(c['nombre']) ?? '-',
          clientes: _int(c['clientes']),
          monto: _double(c['monto']),
        ),
    ],
    cuentasPorCobrar: ReceivablesEntity(
      total: _double(cxc['total']),
      porVencer: _double(cxc['por_vencer']),
      porVencerPct: _double(cxc['por_vencer_pct']),
      vencido: _double(cxc['vencido']),
      vencidoPct: _double(cxc['vencido_pct']),
    ),
    cobroPorVendedor: [
      for (final c in _list(j['cobro_por_vendedor']))
        SellerCollectionEntity(
          id: _int(c['id']),
          nombre: _text(c['nombre']) ?? '-',
          cobrado: _double(c['cobrado']),
          soles: _double(c['soles']),
          dolares: _double(c['dolares']),
          pendiente: _double(c['pendiente']),
        ),
    ],
    ingresos: _incomes(j['ingresos']),
    nuevosClientes: NewClientsEntity(
      cantidad: _int(news['cantidad']),
      cantidadPct: _doubleOrNull(news['cantidad_pct']),
      ventas: _double(news['ventas']),
      ventasPct: _doubleOrNull(news['ventas_pct']),
      top: [for (final t in _list(news['top'])) _ranked(t)],
    ),
    clientesCaida: _fallClients(_map(j['clientes_caida'])),
    productosMayorCaida: _fallProducts(productos['mayor_caida']),
  );
}
