import '../../domain/entities/client_record_entity.dart';

String? _text(dynamic v) {
  if (v == null) return null;
  final t = '$v'.trim();
  return t.isEmpty ? null : t;
}

int? _int(dynamic v) {
  if (v == null) return null;
  if (v is num) return v.toInt();
  return int.tryParse('$v');
}

double? _doubleOrNull(dynamic v) {
  if (v == null) return null;
  if (v is num) return v.toDouble();
  return double.tryParse('$v');
}

double _double(dynamic v) => _doubleOrNull(v) ?? 0;

bool _bool(dynamic v, {bool fallback = false}) {
  if (v == null) return fallback;
  if (v is bool) return v;
  if (v is num) return v != 0;
  final t = '$v'.toLowerCase();
  return t == 'true' || t == '1';
}

Map<String, dynamic>? _map(dynamic v) => v is Map ? v.cast<String, dynamic>() : null;

/// Fecha `yyyy-MM-dd` de un valor que puede venir con hora (`1990-05-12T00:00:00.000000Z`).
String? _date(dynamic v) {
  final t = _text(v);
  if (t == null) return null;
  return t.length >= 10 ? t.substring(0, 10) : t;
}

ClientAddressEntity clientAddressFromJson(Map<String, dynamic> j) => ClientAddressEntity(
      id: _int(j['id']),
      direccion: _text(j['direccion']) ?? '',
      calle: _text(j['calle']),
      lote: _text(j['lote']),
      indicaciones: _text(j['indicaciones']),
      latitud: _doubleOrNull(j['latitud']),
      longitud: _doubleOrNull(j['longitud']),
      departmentId: _text(j['department_id']),
      provinceId: _text(j['province_id']),
      districtId: _text(j['district_id']),
      provinceName: _text(_map(j['province'])?['name']),
      districtName: _text(_map(j['district'])?['name']),
      predeterminado: _bool(j['predeterminado']),
    );

ClientContactEntity clientContactFromJson(Map<String, dynamic> j) => ClientContactEntity(
      id: _int(j['id']),
      name: _text(j['name']) ?? '',
      lastName: _text(j['last_name']),
      email: _text(j['email']),
      telefono: _text(j['telefono']),
    );

ClientRecordEntity clientRecordFromJson(Map<String, dynamic> j) {
  final ejecutivo = _map(j['ejecutivo_comercial']);
  final categoria = _map(j['categoria_cliente']);
  final addresses = j['adresses'];
  final contacts = j['contacts'];
  return ClientRecordEntity(
    id: _int(j['id']) ?? 0,
    codigo: _text(j['codigo']),
    tipo: _text(j['tipo']) ?? 'p',
    dniRuc: _text(j['dni_ruc']) ?? '',
    name: _text(j['name']) ?? '',
    lastName: _text(j['last_name']),
    razonSocial: _text(j['razon_social']),
    direccion: _text(j['direccion']),
    calle: _text(j['calle']),
    lote: _text(j['lote']),
    indicaciones: _text(j['indicaciones']),
    email: _text(j['email']),
    telefono: _text(j['telefono']),
    giro: _text(j['giro']),
    nota: _text(j['nota']),
    redes: _text(j['redes']),
    pagina2: _text(j['pagina_2']),
    pagina3: _text(j['pagina_3']),
    cumple: _date(j['cumple']),
    estado: _bool(j['estado'], fallback: true),
    extranjero: _bool(j['extranjero']),
    credito: _double(j['credito']),
    creditoDisponible: _double(j['credito_disponible_real'] ?? j['credito_disponible']),
    lineaUtilizada: _double(j['linea_utilizada']),
    ejecutivoId: _int(j['ejecutivo_comercial_id']) ?? _int(ejecutivo?['id']),
    ejecutivoNombre: _text(ejecutivo?['name']),
    categoriaId: _int(j['categoria_cliente_id']) ?? _int(categoria?['id']),
    categoriaNombre: _text(categoria?['nombre']),
    categoriaCodigo: _text(categoria?['codigo']),
    listPriceId: _int(j['list_price_id']),
    paymentMethodId: _int(j['payment_method_id']),
    departmentId: _text(j['department_id']),
    provinceId: _text(j['province_id']),
    districtId: _text(j['district_id']),
    departmentName: _text(_map(j['department'])?['name']),
    provinceName: _text(_map(j['province'])?['name']),
    districtName: _text(_map(j['district'])?['name']),
    registradoPor: _text(_map(j['user'])?['name']),
    creado: DateTime.tryParse(_text(j['created_at']) ?? ''),
    addresses: addresses is List
        ? [for (final a in addresses) if (a is Map) clientAddressFromJson(a.cast<String, dynamic>())]
        : const [],
    contacts: contacts is List
        ? [for (final c in contacts) if (c is Map) clientContactFromJson(c.cast<String, dynamic>())]
        : const [],
  );
}

/// Respuesta paginada de `GET /clientes`.
ClientPageEntity clientPageFromJson(Map<String, dynamic> j) {
  final data = j['data'];
  return ClientPageEntity(
    items: data is List
        ? [for (final c in data) if (c is Map) clientRecordFromJson(c.cast<String, dynamic>())]
        : const [],
    currentPage: _int(j['current_page']) ?? 1,
    lastPage: _int(j['last_page']) ?? 1,
    total: _int(j['total']) ?? 0,
    totalPersonas: _int(j['total_personas']) ?? 0,
    totalEmpresas: _int(j['total_empresas']) ?? 0,
  );
}

/// Filtros, categorías, ejecutivos y departamentos que ofrece el filtro de la lista. Se arman de
/// `GET /clientes/categorias`, `/clientes/ejecutivos` y `/clientes/ubicaciones`.
ClientFilterCatalogsEntity clientFilterCatalogsFromJson({
  required dynamic categorias,
  required dynamic ejecutivos,
  required dynamic ubicaciones,
}) {
  final cat = _map(categorias);
  final loc = _map(ubicaciones);
  final catList = cat?['categorias'];
  final depList = loc?['departamentos'];
  return ClientFilterCatalogsEntity(
    categorias: catList is List
        ? [
            for (final c in catList)
              if (c is Map && _int(c['id']) != null)
                ClientFilterOption(
                  id: '${_int(c['id'])}',
                  name: _text(c['nombre']) ?? '',
                  clientes: _int(c['clientes']) ?? 0,
                ),
          ]
        : const [],
    sinCategoria: _int(cat?['sin_categoria']) ?? 0,
    conCategoria: _int(cat?['con_categoria']) ?? 0,
    ejecutivos: ejecutivos is List
        ? [
            for (final e in ejecutivos)
              if (e is Map && _int(e['id']) != null)
                ClientFilterOption(
                  id: '${_int(e['id'])}',
                  name: _text(e['name']) ?? '',
                  clientes: _int(e['clientes_count']) ?? 0,
                ),
          ]
        : const [],
    departamentos: depList is List
        ? [
            for (final d in depList)
              if (d is Map && _text(d['id']) != null)
                ClientFilterOption(
                  id: _text(d['id'])!,
                  name: _text(d['nombre']) ?? '',
                  clientes: _int(d['clientes']) ?? 0,
                ),
          ]
        : const [],
  );
}

List<ClientOption> clientOptionsFromJson(dynamic json, {String key = 'name'}) {
  final list = json is Map ? (json['data'] ?? json['items']) : json;
  if (list is! List) return const [];
  return [
    for (final e in list)
      if (e is Map && _int(e['id']) != null && _text(e[key]) != null)
        ClientOption(id: _int(e['id'])!, name: _text(e[key])!),
  ];
}

ClientCategoryEntity clientCategoryFromJson(Map<String, dynamic> j) {
  final rangos = <String, CategoryRange>{};
  final raw = _map(j['rangos']);
  if (raw != null) {
    for (final entry in raw.entries) {
      final r = _map(entry.value);
      rangos[entry.key.toLowerCase()] = CategoryRange(desde: _doubleOrNull(r?['desde']), hasta: _doubleOrNull(r?['hasta']));
    }
  }
  return ClientCategoryEntity(
    id: _int(j['id']) ?? 0,
    nombre: _text(j['nombre']) ?? '',
    codigo: _text(j['codigo']) ?? '',
    orden: _int(j['orden']) ?? 0,
    montoDesde: _doubleOrNull(j['monto_desde']),
    montoHasta: _doubleOrNull(j['monto_hasta']),
    rangos: rangos,
  );
}

/// Respuesta de `GET /categorias-cliente`: `{data: [...], ciclo: {tipo, periodos}}`.
CategoriesConfigEntity categoriesConfigFromJson(Map<String, dynamic> j) {
  final data = j['data'];
  final ciclo = _map(j['ciclo']);
  final periodos = <String, CategoryPeriod>{};
  final rawPeriodos = _map(ciclo?['periodos']);
  if (rawPeriodos != null) {
    for (final entry in rawPeriodos.entries) {
      final p = _map(entry.value);
      periodos[entry.key.toLowerCase()] = CategoryPeriod(
        evaluadoDesde: _date(p?['evaluado_desde']),
        evaluadoHasta: _date(p?['evaluado_hasta']),
        vigenteDesde: _date(p?['vigente_desde']),
        cambiaEl: _date(p?['cambia_el']),
      );
    }
  }
  return CategoriesConfigEntity(
    categorias: data is List
        ? [for (final c in data) if (c is Map) clientCategoryFromJson(c.cast<String, dynamic>())]
        : const [],
    ciclo: (_text(ciclo?['tipo']) ?? 'mensual').toLowerCase(),
    periodos: periodos,
  );
}

CategoryCalcEntity categoryCalcFromJson(dynamic json) {
  final j = _map(json);
  final ciclo = j?['ciclo'];
  return CategoryCalcEntity(
    recalculado: _bool(j?['recalculado']),
    mensaje: _text(j?['mensaje']),
    desde: ciclo is List && ciclo.isNotEmpty ? _date(ciclo[0]) : null,
    hasta: ciclo is List && ciclo.length > 1 ? _date(ciclo[1]) : null,
    clientesActualizados: _int(j?['clientes_actualizados']) ?? 0,
  );
}

Map<String, dynamic> clientAddressToJson(ClientAddressEntity a) => {
      'id': ?a.id,
      'direccion': a.direccion,
      'calle': ?a.calle,
      'lote': ?a.lote,
      'indicaciones': ?a.indicaciones,
      'latitud': ?a.latitud,
      'longitud': ?a.longitud,
      'department_id': ?a.departmentId,
      'province_id': ?a.provinceId,
      'district_id': ?a.districtId,
      'predeterminado': a.predeterminado,
    };

Map<String, dynamic> clientContactToJson(ClientContactEntity c) => {
      'id': ?c.id,
      'name': c.name,
      'last_name': ?c.lastName,
      'email': ?c.email,
      'telefono': ?c.telefono,
    };

/// Cuerpo de `POST /clientes` o `PUT /clientes/{id}` con los campos de la web. Al editar, los
/// campos que se vaciaron van como `null` (el backend deja el valor anterior si no llegan); al
/// crear, simplemente no se mandan.
Map<String, dynamic> clientFormToJson(
  ClientFormEntity f, {
  required int companyId,
  required bool editing,
}) {
  final body = <String, dynamic>{'company_id': companyId};

  void put(String key, String? value) {
    final empty = value == null || value.trim().isEmpty;
    if (!empty) {
      body[key] = value.trim();
    } else if (editing) {
      body[key] = null;
    }
  }

  if (f.incluyeBasica) {
    body['tipo'] = f.tipo;
    body['dni_ruc'] = f.dniRuc;
    body['name'] = f.name;
    put('last_name', f.lastName);
    // En personas el backend descarta la razón social.
    if (f.esEmpresa) put('razon_social', f.razonSocial);
    body['telefono'] = f.telefono;
    body['email'] = f.email;
    put('giro', f.giro);
    body['extranjero'] = f.extranjero;
    body['estado'] = f.estado;
    if (f.departmentId.isNotEmpty) body['department_id'] = f.departmentId;
    if (f.provinceId.isNotEmpty) body['province_id'] = f.provinceId;
    if (f.districtId.isNotEmpty) body['district_id'] = f.districtId;
    put('calle', f.calle);
    put('direccion', f.direccion);
    put('lote', f.lote);
    put('indicaciones', f.indicaciones);
    // Al editar, un ejecutivo vaciado se manda como null para que se quite.
    if (editing || f.ejecutivoId != null) body['ejecutivo_comercial_id'] = f.ejecutivoId;
    put('redes', f.redes);
    put('pagina_2', f.pagina2);
    put('pagina_3', f.pagina3);
    put('cumple', f.cumple);
    put('nota', f.nota);
  }

  if (f.incluyeCondiciones) {
    if (editing || f.listPriceId != null) body['list_price_id'] = f.listPriceId;
    if (editing || f.paymentMethodId != null) body['payment_method_id'] = f.paymentMethodId;
    if (f.credito != null) body['credito'] = f.credito;
  }

  if (f.addresses != null) body['adresses'] = [for (final a in f.addresses!) clientAddressToJson(a)];
  if (f.contacts != null) body['contacts'] = [for (final c in f.contacts!) clientContactToJson(c)];
  return body;
}
