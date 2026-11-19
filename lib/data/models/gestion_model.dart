import '../../domain/entities/gestion_entity.dart';

double _double(dynamic v) => v is num ? v.toDouble() : (v is String ? double.tryParse(v) ?? 0 : 0);

double? _doubleOrNull(dynamic v) => v == null ? null : _double(v);

int _int(dynamic v) => v is num ? v.toInt() : (v is String ? int.tryParse(v) ?? 0 : 0);

int? _intOrNull(dynamic v) => v is num ? v.toInt() : (v is String ? int.tryParse(v) : null);

String? _text(dynamic v) {
  if (v is! String) return null;
  final t = v.trim();
  return t.isEmpty ? null : t;
}

/// Las fechas de las gestiones llegan como `Y-m-d H:i:s` (o `Y-m-d`) sin zona: son hora local, sin
/// convertir a UTC.
DateTime _date(dynamic v) => (v is String ? DateTime.tryParse(v) : null) ?? DateTime(2000);

DateTime? _dateOrNull(dynamic v) => v is String ? DateTime.tryParse(v) : null;

Map<String, dynamic> _map(dynamic v) => v is Map<String, dynamic> ? v : const {};

List<Map<String, dynamic>> _list(dynamic v) =>
    v is List ? [for (final e in v) if (e is Map<String, dynamic>) e] : const [];

GestionCatalogo gestionCatalogoFromJson(dynamic json) {
  return GestionCatalogo(
    resultados: [
      for (final r in _list(_map(json)['resultados']))
        if (_text(r['clave']) != null)
          GestionResultado(
            clave: _text(r['clave'])!,
            etiqueta: _text(r['etiqueta']) ?? _text(r['clave'])!,
            tono: GestionTono.fromKey(r['tono']),
            cuando: _text(r['cuando']) ?? '',
          ),
    ],
  );
}

List<GestionClienteBuscado> gestionClientesFromJson(dynamic json) {
  return [
    for (final c in _list(_map(json)['data']))
      GestionClienteBuscado(
        id: _int(c['id']),
        nombre: _text(c['nombre']) ?? '-',
        documento: _text(c['documento']),
        codigo: _text(c['codigo']),
        ciudad: _text(c['ciudad']),
        activo: c['activo'] != false,
      ),
  ];
}

GestionTareas gestionTareasFromJson(dynamic json) {
  final j = _map(json);
  return GestionTareas(
    equipo: j['equipo'] == true,
    tareas: [
      for (final t in _list(j['data']))
        GestionTarea(
          id: _int(t['id']),
          clienteId: _int(t['cliente_id']),
          cliente: _text(t['cliente']) ?? '-',
          tipo: _text(t['tipo']) ?? '',
          tipoEtiqueta: _text(t['tipo_etiqueta']) ?? '',
          accion: _text(t['accion']),
          fecha: _date(t['fecha']),
          vencida: t['vencida'] == true,
          ejecutivoId: _intOrNull(t['ejecutivo_id']),
          ejecutivo: _text(t['ejecutivo']),
        ),
    ],
  );
}

GestionRegistro gestionRegistroFromJson(Map<String, dynamic> j) {
  final tipo = GestionContacto.fromKey(j['tipo_contacto']) ?? GestionContacto.llamada;
  final proximoTipo = GestionContacto.fromKey(j['proximo_tipo_contacto']);
  return GestionRegistro(
    id: _int(j['id']),
    tipo: tipo,
    tipoEtiqueta: _text(j['tipo_etiqueta']) ?? tipo.etiqueta,
    resultado: _text(j['resultado']) ?? '',
    resultadoEtiqueta: _text(j['resultado_etiqueta']) ?? _text(j['resultado']) ?? '',
    tono: GestionTono.fromKey(j['tono']),
    comentario: _text(j['comentario']),
    registradoPor: _text(j['registrado_por']),
    fecha: _date(j['fecha']),
    proximoSeguimiento: _dateOrNull(j['proximo_seguimiento']),
    proximoTipo: proximoTipo,
    proximoTipoEtiqueta: _text(j['proximo_tipo_etiqueta']),
    proximaAccion: _text(j['proxima_accion']),
    seguimientoEstado: GestionSeguimiento.fromKey(j['seguimiento_estado']),
    vencida: j['vencida'] == true,
  );
}

GestionRegistro? _registroOrNull(dynamic raw) => raw is Map<String, dynamic> ? gestionRegistroFromJson(raw) : null;

GestionPeriodo _periodo(Map<String, dynamic> p) => GestionPeriodo(
      desde: _date(p['desde']),
      hasta: _date(p['hasta']),
      etiqueta: _text(p['etiqueta']) ?? '',
      etiquetaAnterior: _text(p['etiqueta_anterior']) ?? '',
      ventas: _double(p['ventas']),
      compras: _int(p['compras']),
      ticketPromedio: _double(p['ticket_promedio']),
      ventasAnterior: _double(p['ventas_anterior']),
      variacion: _double(p['variacion']),
      caidaPct: _doubleOrNull(p['caida_pct']),
    );

GestionFicha gestionFichaFromJson(dynamic json) {
  final j = _map(json);
  final c = _map(j['cliente']);
  final estado = _map(c['estado']);
  final k = _map(j['kpis']);
  final compra = _map(k['ultima_compra']);
  final p = _map(j['periodo']);

  return GestionFicha(
    cliente: GestionCliente(
      id: _int(c['id']),
      codigo: _text(c['codigo']),
      nombre: _text(c['nombre']) ?? '-',
      esEmpresa: c['tipo'] == 'Empresa',
      documento: _text(c['documento']),
      telefono: _text(c['telefono']),
      email: _text(c['email']),
      contactoOculto: c['contacto_oculto'] == true,
      direccion: _text(c['direccion']),
      ciudad: _text(c['ciudad']),
      categoria: _text(c['categoria']),
      vendedor: _text(c['vendedor']),
      condicionPago: _text(c['condicion_pago']),
      limiteCredito: _double(c['limite_credito']),
      activo: c['activo'] != false,
      estado: GestionEstado.fromKey(estado['clave']),
      estadoEtiqueta: _text(estado['etiqueta']) ?? 'Sin comparación',
    ),
    kpis: GestionKpis(
      diasSinComprar: _intOrNull(k['dias_sin_comprar']),
      ultimaCompra: compra.isEmpty
          ? null
          : GestionUltimaCompra(
              id: _int(compra['id']),
              fecha: _date(compra['fecha']),
              documento: _text(compra['documento']) ?? '',
              monto: _double(compra['monto']),
            ),
    ),
    periodo: _periodo(p),
    ultimaGestion: _registroOrNull(j['ultima_gestion']),
    proximaGestion: _registroOrNull(j['proxima_gestion']),
    productos: [
      for (final p in _list(j['productos_principales']))
        GestionProducto(
          producto: _text(p['producto']) ?? '-',
          codigo: _text(p['codigo']),
          monto: _double(p['monto']),
          porcentaje: _double(p['porcentaje']),
        ),
    ],
  );
}

GestionHistorial gestionHistorialFromJson(dynamic json) {
  final j = _map(json);
  return GestionHistorial(
    gestiones: [for (final g in _list(j['data'])) gestionRegistroFromJson(g)],
    proxima: _registroOrNull(j['proxima_gestion']),
    totalAnio: _int(j['total_anio']),
    desdeAnio: _dateOrNull(j['desde_anio']),
  );
}

String _two(int v) => v.toString().padLeft(2, '0');

/// `2026-10-30 10:00:00`: como espera el backend la fecha y hora de un siguiente contacto.
String gestionFechaHoraApi(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${_two(d.month)}-${_two(d.day)} ${_two(d.hour)}:${_two(d.minute)}:00';

String? _sinVacio(String? text) {
  final t = (text ?? '').trim();
  return t.isEmpty ? null : t;
}

/// El cuerpo de `POST /seguimiento-clientes/{cliente}/gestiones`. Lo vacío no se manda.
Map<String, dynamic> gestionNuevaToJson(GestionNueva g) {
  final comentario = _sinVacio(g.comentario);
  final accion = _sinVacio(g.proximaAccion);
  final proximo = g.proximo;
  return {
    'tipo_contacto': g.tipo.key,
    'resultado': g.resultado,
    'comentario': ?comentario,
    if (proximo != null) ...{
      'proximo_seguimiento': gestionFechaHoraApi(proximo),
      'proximo_tipo_contacto': (g.proximoTipo ?? g.tipo).key,
      'proxima_accion': ?accion,
    },
  };
}

/// El cuerpo de `PUT /seguimiento-clientes/gestiones/{gestion}`. Un siguiente contacto cumplido solo manda su
/// acción; si no, `proximo_seguimiento` va con la fecha o en `null` para quitarlo.
Map<String, dynamic> gestionEdicionToJson(GestionEdicion g) {
  final comentario = _sinVacio(g.comentario);
  final accion = _sinVacio(g.proximaAccion);
  final proximo = g.proximo;
  return {
    'tipo_contacto': g.tipo.key,
    'resultado': g.resultado,
    'comentario': ?comentario,
    if (g.cumplida)
      'proxima_accion': ?accion
    else ...{
      'proximo_seguimiento': proximo == null ? null : gestionFechaHoraApi(proximo),
      if (proximo != null) ...{
        'proximo_tipo_contacto': (g.proximoTipo ?? g.tipo).key,
        'proxima_accion': ?accion,
      },
    },
  };
}

List<GestionTop> _tops(dynamic raw) => [
      for (final t in _list(raw))
        GestionTop(
          nombre: _text(t['nombre']) ?? '-',
          codigo: _text(t['codigo']),
          monto: _double(t['monto']),
          porcentaje: _double(t['porcentaje']),
        ),
    ];

List<GestionMes> _meses(dynamic raw) => [
      for (final m in _list(raw))
        GestionMes(
          mes: _int(m['mes']),
          anterior: _double(m['anterior']),
          actual: _doubleOrNull(m['actual']),
          corte: _text(m['corte']),
        ),
    ];

/// La pestaña Compras (`GET /seguimiento-clientes/{cliente}/compras`).
GestionCompras gestionComprasFromJson(dynamic json) {
  final j = _map(json);
  return GestionCompras(
    periodo: _periodo(_map(j['periodo'])),
    anioActual: _int(j['anio_actual']),
    anioAnterior: _int(j['anio_anterior']),
    anioListas: _int(j['anio_listas']),
    hasta: _text(j['hasta']) ?? '',
    evolucion: _meses(j['evolucion']),
    acumulado: _meses(j['acumulado']),
    ultimasCompras: [
      for (final c in _list(j['ultimas_compras']))
        GestionUltimaCompra(
          id: _int(c['id']),
          fecha: _date(c['fecha']),
          documento: _text(c['documento']) ?? '',
          monto: _double(c['monto']),
        ),
    ],
    topProductos: _tops(j['top_productos']),
    topMarcas: _tops(j['top_marcas']),
    topCategorias: _tops(j['top_categorias']),
  );
}

/// La pestaña Documentos (`GET /seguimiento-clientes/{cliente}/documentos`): las cotizaciones y las ventas.
List<GestionDocumento> gestionDocumentosFromJson(dynamic json) {
  return [
    for (final d in _list(_map(json)['data']))
      GestionDocumento(
        clave: _text(d['clave']) ?? '${d['tipo']}-${d['id']}',
        id: _int(d['id']),
        tipo: GestionDocumentoTipo.fromKey(d['tipo']),
        numero: _text(d['numero']) ?? '-',
        nroDocumento: _int(d['nro_documento']),
        fecha: _date(d['fecha']),
        monto: _double(d['monto']),
        estado: _text(d['estado']) ?? '',
        ejecutivo: _text(d['ejecutivo']),
        almacen: _text(d['almacen']),
      ),
  ];
}

/// `2026-10-30`: la fecha que espera el backend en los filtros de `documentos`.
String gestionDiaApi(DateTime d) => '${d.year.toString().padLeft(4, '0')}-${_two(d.month)}-${_two(d.day)}';
