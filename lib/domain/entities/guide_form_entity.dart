/// Motivos de traslado de la guía de remisión (códigos de la SUNAT), como en la web.
const guideTransferReasons = {
  '01': 'Venta',
  '02': 'Compra',
  '03': 'Venta con entrega a terceros',
  '04': 'Traslado entre establecimientos',
  '08': 'Importación',
  '09': 'Exportación',
  '13': 'Otros',
};

/// Tipo de guía: `01` pública (el transporte lo hace una empresa de transporte, con su registro
/// MTC) o `02` privada (lo hace el propio remitente, con su chofer y su placa).
enum GuideKind {
  publica('01', 'Pública'),
  privada('02', 'Privada');

  final String code;
  final String label;
  const GuideKind(this.code, this.label);
}

/// Datos del formulario "Guía de remisión", con los mismos campos que la web.
class GuideFormEntity {
  /// La guía se emite sobre una boleta o factura (`boletaId`, se envía a la SUNAT) o sobre una
  /// venta sin comprobante electrónico (`saleId`, guía local).
  final int? boletaId;
  final int? saleId;
  final GuideKind tipo;
  final String codTraslado;
  final DateTime? fechaEmision;
  final DateTime? fechaTraslado;
  final double? pesoTotal;
  final String docTransportista;
  final String razonSocialTransportista;

  /// Solo guía pública: registro MTC del transportista.
  final String? matricula;

  /// Solo guía privada: el chofer y su vehículo.
  final String? dniChofer;
  final String? placaChofer;
  final String? nombreChofer;
  final String? apellidoChofer;
  final String? licenciaChofer;

  /// Códigos de distrito (6 dígitos) de salida y de llegada.
  final String ubigeoSalida;
  final String direccionSalida;
  final String ubigeoLlegada;
  final String direccionLlegada;
  final String? observaciones;

  const GuideFormEntity({
    this.boletaId,
    this.saleId,
    this.tipo = GuideKind.privada,
    this.codTraslado = '01',
    this.fechaEmision,
    this.fechaTraslado,
    this.pesoTotal,
    this.docTransportista = '',
    this.razonSocialTransportista = '',
    this.matricula,
    this.dniChofer,
    this.placaChofer,
    this.nombreChofer,
    this.apellidoChofer,
    this.licenciaChofer,
    this.ubigeoSalida = '',
    this.direccionSalida = '',
    this.ubigeoLlegada = '',
    this.direccionLlegada = '',
    this.observaciones,
  });
}

/// Lo que se sabe de la venta antes de armar su guía: si ya tiene una y a dónde llega por
/// defecto (la dirección predeterminada del cliente o, si no tiene, la principal).
class GuideDefaultsEntity {
  final bool tieneGuia;
  final String? departmentId;
  final String? provinceId;
  final String? districtId;
  final String? direccion;

  const GuideDefaultsEntity({
    this.tieneGuia = false,
    this.departmentId,
    this.provinceId,
    this.districtId,
    this.direccion,
  });

  bool get tieneUbigeo => departmentId != null && provinceId != null && districtId != null;
}

/// Chofer ya registrado (se reutiliza por su DNI).
class DriverEntity {
  final String name;
  final String lastName;
  final String license;

  const DriverEntity({this.name = '', this.lastName = '', this.license = ''});
}
