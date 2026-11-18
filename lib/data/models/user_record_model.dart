import '../../domain/entities/user_record_entity.dart';

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

bool _bool(dynamic v, {bool fallback = false}) {
  if (v == null) return fallback;
  if (v is bool) return v;
  if (v is num) return v != 0;
  final t = '$v'.toLowerCase();
  return t == 'true' || t == '1';
}

/// Fecha `yyyy-MM-dd` de un valor que puede venir con hora (`1995-05-28T00:00:00.000000Z`).
String? _date(dynamic v) {
  final t = _text(v);
  if (t == null) return null;
  return t.length >= 10 ? t.substring(0, 10) : t;
}

/// `[{id, name}]` (roles, almacenes, listas de precios, métodos de pago).
List<UserOption> userOptionsFromJson(dynamic json) {
  if (json is! List) return const [];
  final result = <UserOption>[];
  for (final e in json) {
    if (e is! Map) continue;
    final id = _int(e['id']);
    final name = _text(e['name']);
    if (id != null && name != null) result.add(UserOption(id: id, name: name));
  }
  return result;
}

List<UserPermissionEntity> userPermissionsFromJson(dynamic json) => [
      for (final o in userOptionsFromJson(json)) UserPermissionEntity(id: o.id, name: o.name),
    ];

UserRecordEntity userRecordFromJson(Map<String, dynamic> j) {
  return UserRecordEntity(
    id: _int(j['id']) ?? 0,
    codigo: _text(j['codigo']),
    usuario: _text(j['usuario']),
    name: _text(j['name']) ?? '',
    email: _text(j['email']),
    telefono: _text(j['telefono']),
    estado: _bool(j['estado'], fallback: true),
    ventasAjenas: _bool(j['ventas_ajenas']),
    tipoDocumento: _text(j['tipo_documento']),
    numeroDocumento: _text(j['numero_documento']),
    nombres: _text(j['nombres']),
    apellidos: _text(j['apellidos']),
    cumple: _date(j['cumple']),
    direccion: _text(j['direccion']),
    departmentId: _text(j['department_id']),
    provinceId: _text(j['province_id']),
    districtId: _text(j['district_id']),
    contactoEmergencia: _text(j['contacto_emergencia']),
    telefonoEmergencia: _text(j['telefono_emergencia']),
    area: _text(j['area']),
    fechaIngreso: _date(j['fecha_ingreso']),
    foto: _text(j['foto']),
    warehouseId: _int(j['warehouse_id']),
    listPriceId: _int(j['list_price_id']),
    paymentMethodId: _int(j['payment_method_id']),
    metodoEntrega: _text(j['metodo_entrega']),
    roles: userOptionsFromJson(j['roles']),
    warehouses: userOptionsFromJson(j['warehouses']),
    listPrices: userOptionsFromJson(j['list_prices']),
    paymentMethods: userOptionsFromJson(j['payment_methods']),
    permissions: userPermissionsFromJson(j['permissions']),
    creado: DateTime.tryParse(_text(j['created_at']) ?? '')?.toLocal(),
  );
}

UserPageEntity userPageFromJson(Map<String, dynamic> j) {
  final data = j['data'];
  return UserPageEntity(
    items: data is List
        ? [for (final u in data) if (u is Map) userRecordFromJson(u.cast<String, dynamic>())]
        : const [],
    currentPage: _int(j['current_page']) ?? 1,
    lastPage: _int(j['last_page']) ?? 1,
    total: _int(j['total']) ?? 0,
  );
}

/// El cuerpo de `POST /usuarios` o `PUT /usuarios/{id}`: los mismos campos que manda la web (más
/// `name`, el nombre completo, y `company_id`). Nunca lleva contraseña: la cuenta se activa con el
/// correo que el servidor envía al crear el usuario.
///
/// Como la web, lo que no aplica al rol elegido (métodos de pago, listas de precios, ventas
/// ajenas, método de entrega) no se manda. Al crear solo va lo escrito; al editar, un texto que se
/// vació va como `null` para que el servidor lo borre.
Map<String, dynamic> userFormToJson(UserFormEntity f, {required int companyId, required bool editing}) {
  String? text(String value) {
    final t = value.trim();
    return t.isEmpty ? null : t;
  }

  void optional(Map<String, dynamic> map, String key, Object? value) {
    if (value != null || editing) map[key] = value;
  }

  final map = <String, dynamic>{
    'company_id': companyId,
    'name': f.fullName,
    'tipo_documento': f.tipoDocumento,
    'numero_documento': f.numeroDocumento.trim(),
    'nombres': f.nombres.trim(),
    'apellidos': f.apellidos.trim(),
    'cumple': f.cumple,
    'telefono': f.telefono.trim(),
    'email': f.email.trim(),
    'estado': f.estado,
    'roles': f.roles,
    'almacenes': f.almacenes,
    if (f.warehouseId != null) 'warehouse_id': f.warehouseId,
  };
  optional(map, 'fecha_ingreso', f.fechaIngreso);
  optional(map, 'direccion', text(f.direccion));
  optional(map, 'contacto_emergencia', text(f.contactoEmergencia));
  optional(map, 'telefono_emergencia', text(f.telefonoEmergencia));
  if (f.departmentId != null) map['department_id'] = f.departmentId;
  if (f.provinceId != null) map['province_id'] = f.provinceId;
  if (f.districtId != null) map['district_id'] = f.districtId;

  if (f.esVendedor) {
    map['ventas_ajenas'] = f.ventasAjenas;
    if (f.metodoEntrega != null) map['metodo_entrega'] = f.metodoEntrega;
  }
  if (f.conPagos) {
    map['payment_methods'] = f.paymentMethods;
    if (f.paymentMethodId != null) map['payment_method_id'] = f.paymentMethodId;
  }
  if (f.conListas) {
    map['listPrices'] = f.listPrices;
    if (f.listPriceId != null) map['list_price_id'] = f.listPriceId;
  }
  if (editing || f.permisos.isNotEmpty) map['permisos'] = f.permisos;
  return map;
}
