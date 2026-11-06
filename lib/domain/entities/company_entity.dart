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
  final String? email;
  final String? web;
  final double? igv;

  /// Impuesto a la renta (fracción, 0.015 = 1.5 %): se descuenta del margen neto en Reportes.
  final double? renta;

  /// Programa de puntos: si está activo y el mínimo de puntos que se pueden canjear al pagar.
  final bool programaDePuntos;
  final double minimoCanjePuntos;
  final PlanEntity? plan;

  /// Tiene certificado digital: puede emitir boletas y facturas a SUNAT.
  /// (Solo se guarda si existe; el certificado en sí nunca se conserva.)
  final bool emiteComprobantes;

  /// Serie y último número usado de las guías de remisión (la próxima es la siguiente).
  final int? guiaSerie;
  final int? guiaNumero;

  const CompanyEntity({
    required this.id,
    required this.razonSocial,
    this.ruc,
    this.direccion,
    this.telefono,
    this.email,
    this.web,
    this.igv,
    this.renta,
    this.programaDePuntos = false,
    this.minimoCanjePuntos = 0,
    this.plan,
    this.emiteComprobantes = false,
    this.guiaSerie,
    this.guiaNumero,
  });
}
