import '../../domain/entities/client_form_entity.dart';

String? _text(dynamic v) {
  if (v == null) return null;
  final t = '$v'.trim();
  return t.isEmpty ? null : t;
}

/// Departamentos, provincias o distritos: `[{id, name}]` (los ids son texto con ceros: `01`).
List<UbigeoItemEntity> ubigeoItemsFromJson(dynamic json) {
  if (json is! List) return const [];
  final result = <UbigeoItemEntity>[];
  for (final e in json) {
    if (e is! Map) continue;
    final id = _text(e['id']);
    final name = _text(e['name']);
    if (id != null && name != null) result.add(UbigeoItemEntity(id: id, name: name));
  }
  return result;
}

/// Respuesta de `GET /consulta/reniec`: con RUC trae razón social, dirección y ubigeo; con
/// DNI, nombres y apellidos.
DocumentLookupEntity documentLookupFromJson(Map<String, dynamic> json) {
  final esEmpresa = json['ruc'] != null || json['razonSocial'] != null;
  if (esEmpresa) {
    return DocumentLookupEntity(
      tipo: 'e',
      razonSocial: _text(json['razonSocial']),
      direccion: _text(json['direccion']),
      ubigeo: _text(json['ubigeo']),
    );
  }
  final apellidos = [_text(json['apellidoPaterno']), _text(json['apellidoMaterno'])]
      .whereType<String>()
      .join(' ');
  return DocumentLookupEntity(
    tipo: 'p',
    name: _text(json['nombres']),
    lastName: apellidos.isEmpty ? null : apellidos,
  );
}

/// Cuerpo de `POST /clientes` con los campos de la web.
Map<String, dynamic> newClientToJson(
  NewClientFormEntity f, {
  required int companyId,
  int? executiveId,
}) =>
    {
      'company_id': companyId,
      'tipo': f.tipo,
      'dni_ruc': f.dniRuc,
      'name': f.name,
      'last_name': ?f.lastName,
      // En personas el backend descarta la razón social.
      if (f.esEmpresa) 'razon_social': ?f.razonSocial,
      'telefono': f.telefono,
      'email': f.email,
      'department_id': f.departmentId,
      'province_id': f.provinceId,
      'district_id': f.districtId,
      'calle': ?f.calle,
      'direccion': ?f.direccion,
      'estado': true,
      'ejecutivo_comercial_id': ?executiveId,
    };
