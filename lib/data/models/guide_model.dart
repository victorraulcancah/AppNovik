import '../../domain/entities/guide_form_entity.dart';

String? _text(dynamic v) {
  if (v == null) return null;
  final t = '$v'.trim();
  return t.isEmpty ? null : t;
}

/// Código de ubigeo como texto con sus ceros (`15`, `1501`, `150101`).
String? _code(dynamic v, int length) {
  return _text(v)?.padLeft(length, '0');
}

bool _truthy(dynamic v) => v == true || v == 1 || v == '1';

/// De `GET /ventas/{id}`: si la venta (o su boleta) ya tiene guía y la dirección del cliente.
GuideDefaultsEntity guideDefaultsFromJson(Map<String, dynamic> json) {
  final boleta = json['boleta'];
  final tieneGuia = json['guia'] != null || (boleta is Map && boleta['guia'] != null);

  final client = json['client'];
  if (client is! Map) return GuideDefaultsEntity(tieneGuia: tieneGuia);

  // Si el cliente tiene una dirección marcada como predeterminada se usa esa; si no, la principal.
  Map? preferred;
  final addresses = client['adresses'];
  if (addresses is List) {
    for (final a in addresses.whereType<Map>()) {
      if (_truthy(a['predeterminado'])) {
        preferred = a;
        break;
      }
    }
  }

  return GuideDefaultsEntity(
    tieneGuia: tieneGuia,
    departmentId: _code(preferred?['department_id'] ?? client['department_id'], 2),
    provinceId: _code(preferred?['province_id'] ?? client['province_id'], 4),
    districtId: _code(preferred?['district_id'] ?? client['district_id'], 6),
    direccion: _text(preferred?['direccion']) ?? _text(client['direccion']),
  );
}

/// De `GET /conductores/{dni}`.
DriverEntity driverFromJson(Map<String, dynamic> json) => DriverEntity(
      name: _text(json['name']) ?? '',
      lastName: _text(json['last_name']) ?? '',
      license: _text(json['license']) ?? '',
    );

String _day(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// Sin guiones y en mayúsculas, como normaliza la web la placa, la licencia y la matrícula.
String _plate(String v) => v.replaceAll('-', '').toUpperCase();

/// Cuerpo de `POST /guia-remision`, con los mismos campos que arma la web.
Map<String, dynamic> guideToJson(GuideFormEntity f) {
  final public = f.tipo == GuideKind.publica;
  String? clean(String? v) => (v == null || v.trim().isEmpty) ? null : v.trim();
  final observaciones = clean(f.observaciones);

  return {
    if (f.boletaId != null) 'boleta_id': f.boletaId else 'sale_id': f.saleId,
    'tipo_guia': f.tipo.code,
    'cod_traslado': f.codTraslado,
    if (f.fechaEmision != null) 'fecha_emision': _day(f.fechaEmision!),
    if (f.fechaTraslado != null) 'fecha_traslado': _day(f.fechaTraslado!),
    'peso_total': f.pesoTotal,
    'doc_transportista': f.docTransportista.trim(),
    'rzn_social_transportista': f.razonSocialTransportista.trim(),
    if (public) 'matricula_transportista': _plate(f.matricula ?? ''),
    if (!public) ...{
      'dni_chofer': (f.dniChofer ?? '').replaceAll('-', '').trim(),
      'placa_chofer': _plate(f.placaChofer ?? ''),
      'nombre_chofer': (f.nombreChofer ?? '').trim(),
      'apellido_chofer': (f.apellidoChofer ?? '').trim(),
      'licencia_chofer': _plate(f.licenciaChofer ?? ''),
    },
    'ubigeo_salida': f.ubigeoSalida,
    'direccion_salida': f.direccionSalida.trim(),
    'ubigeo_llegada': f.ubigeoLlegada,
    'direccion_llegada': f.direccionLlegada.trim(),
    'observaciones': ?observaciones,
  };
}
