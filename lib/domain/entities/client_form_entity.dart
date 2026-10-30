/// Departamento, provincia o distrito. Los códigos son texto (`15`, `1501`, `150101`).
class UbigeoItemEntity {
  final String id;
  final String name;

  const UbigeoItemEntity({required this.id, required this.name});
}

/// Lo que devuelve la consulta de un DNI o RUC (RENIEC / SUNAT) para rellenar el cliente.
class DocumentLookupEntity {
  /// `p` persona (DNI) o `e` empresa (RUC).
  final String tipo;
  final String? name;
  final String? lastName;
  final String? razonSocial;
  final String? direccion;

  /// Código de ubigeo de 6 dígitos (departamento + provincia + distrito), solo en empresas.
  final String? ubigeo;

  const DocumentLookupEntity({
    required this.tipo,
    this.name,
    this.lastName,
    this.razonSocial,
    this.direccion,
    this.ubigeo,
  });

  bool get esEmpresa => tipo == 'e';

  String? get departmentId => (ubigeo != null && ubigeo!.length >= 2) ? ubigeo!.substring(0, 2) : null;
  String? get provinceId => (ubigeo != null && ubigeo!.length >= 4) ? ubigeo!.substring(0, 4) : null;
  String? get districtId => (ubigeo != null && ubigeo!.length >= 6) ? ubigeo!.substring(0, 6) : null;
}

/// Datos para crear un cliente desde Ventas, con los campos que la web exige al crear.
class NewClientFormEntity {
  /// `p` persona o `e` empresa.
  final String tipo;
  final String dniRuc;
  final String name;
  final String? lastName;
  final String? razonSocial;
  final String telefono;
  final String email;
  final String departmentId;
  final String provinceId;
  final String districtId;
  final String? calle;
  final String? direccion;

  const NewClientFormEntity({
    required this.tipo,
    required this.dniRuc,
    required this.name,
    this.lastName,
    this.razonSocial,
    required this.telefono,
    required this.email,
    required this.departmentId,
    required this.provinceId,
    required this.districtId,
    this.calle,
    this.direccion,
  });

  bool get esEmpresa => tipo == 'e';
}
