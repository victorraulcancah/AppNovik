/// Plan (perfil) contratado por la empresa: define límites y funciones.
class PlanEntity {
  final String name;
  final int? documentosMax;
  final int? almacenesMax;
  final bool estadoCuentaClientes;
  final bool ecommerce;

  const PlanEntity({
    required this.name,
    this.documentosMax,
    this.almacenesMax,
    this.estadoCuentaClientes = false,
    this.ecommerce = false,
  });
}

/// Empresa a la que pertenece el usuario. Todos los datos que ve la app son de esta empresa.
class CompanyEntity {
  final int id;
  final String razonSocial;
  final String? ruc;
  final String? direccion;
  final String? telefono;
  final double? igv;
  final PlanEntity? plan;

  /// Tiene certificado digital: puede emitir boletas y facturas a SUNAT.
  /// (Solo se guarda si existe; el certificado en sí nunca se conserva.)
  final bool emiteComprobantes;

  const CompanyEntity({
    required this.id,
    required this.razonSocial,
    this.ruc,
    this.direccion,
    this.telefono,
    this.igv,
    this.plan,
    this.emiteComprobantes = false,
  });
}
