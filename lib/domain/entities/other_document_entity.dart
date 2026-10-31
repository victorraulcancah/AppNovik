import 'document_entity.dart';

/// Las otras listas de Documentos en la web (además de ventas y cotizaciones).
enum OtherDocumentKind {
  traslado('Traslados de Stock', 'traslados', 'despachos.transferir.index'),
  guia('Guías de Remisión', 'guías de remisión', 'documentos.guia_remision.index'),
  notaCredito('Notas de Crédito', 'notas de crédito', 'documentos.nota_credito.index'),
  entradaStock('Entrada de Stock', 'entradas de stock', 'documentos.stock.index');

  final String label;
  final String plural;

  /// Permiso que la web exige para ver la lista.
  final String permission;
  const OtherDocumentKind(this.label, this.plural, this.permission);
}

/// Un producto de un traslado o de una entrada de stock.
class OtherDocumentLine {
  final double cantidad;
  final String? codigo;
  final String name;
  final String? marca;

  /// Entradas de stock: el costo de ingreso. Traslados: el costo promedio en el almacén de salida.
  final double costo;

  /// Solo traslados: si ya se recibió en el almacén de destino.
  final bool aceptado;

  const OtherDocumentLine({
    required this.cantidad,
    required this.name,
    this.codigo,
    this.marca,
    this.costo = 0,
    this.aceptado = false,
  });

  double get total => cantidad * costo;
}

/// Datos propios de una guía de remisión.
class GuideInfo {
  final double pesoTotal;
  final String? direccionSalida;
  final String? direccionLlegada;
  final String? ubigeoSalida;
  final String? ubigeoLlegada;
  final DateTime? fechaEmision;
  final DateTime? fechaTraslado;

  /// `01` remitente, `02` transportista.
  final String? tipoGuia;
  final String? documentoTransportista;
  final String? transportista;
  final String? matricula;
  final String? dniChofer;
  final String? placaChofer;
  final String? observaciones;

  const GuideInfo({
    this.pesoTotal = 0,
    this.direccionSalida,
    this.direccionLlegada,
    this.ubigeoSalida,
    this.ubigeoLlegada,
    this.fechaEmision,
    this.fechaTraslado,
    this.tipoGuia,
    this.documentoTransportista,
    this.transportista,
    this.matricula,
    this.dniChofer,
    this.placaChofer,
    this.observaciones,
  });
}

/// Datos propios de una nota de crédito.
class CreditNoteInfo {
  final DateTime? fechaEmision;
  final String? descripcion;

  const CreditNoteInfo({this.fechaEmision, this.descripcion});
}

/// Un traslado de stock, una guía de remisión, una nota de crédito o una entrada de stock,
/// con lo que la web muestra de cada uno en Documentos.
class OtherDocumentEntity {
  final OtherDocumentKind kind;
  final int id;

  /// Como lo arma la web: `T001-0001`, `TG01-0001`, `BC01-0001`, `S001-0001`.
  final String numero;
  final DateTime? creado;

  /// `false` si fue eliminado (solo traslados).
  final bool activo;
  final String? usuario;

  /// Entradas de stock: el almacén al que ingresó.
  final String? almacen;

  /// Traslados: de qué almacén a cuál.
  final String? desde;
  final String? hacia;
  final List<OtherDocumentLine> lines;
  final GuideInfo? guia;
  final CreditNoteInfo? nota;

  /// Guías y notas de crédito: el comprobante al que pertenecen (`B001-0001`, `V001-0003`) y
  /// la venta, para abrir su PDF.
  final String? comprobanteNumero;
  final DocumentEntity? comprobante;

  const OtherDocumentEntity({
    required this.kind,
    required this.id,
    required this.numero,
    this.creado,
    this.activo = true,
    this.usuario,
    this.almacen,
    this.desde,
    this.hacia,
    this.lines = const [],
    this.guia,
    this.nota,
    this.comprobanteNumero,
    this.comprobante,
  });

  /// Falta recibir al menos un producto del traslado.
  bool get pendienteRecepcion =>
      kind == OtherDocumentKind.traslado && activo && lines.any((l) => !l.aceptado);

  /// Un traslado se elimina mientras no se haya recibido ningún producto.
  bool get sePuedeEliminar =>
      kind == OtherDocumentKind.traslado && activo && !lines.any((l) => l.aceptado);

  /// Entradas de stock: costo total de lo que ingresó.
  double get monto => lines.fold<double>(0, (sum, l) => sum + l.total);

  double get unidades => lines.fold<double>(0, (sum, l) => sum + l.cantidad);
}

class OtherDocumentPageEntity {
  final List<OtherDocumentEntity> items;
  final int currentPage;
  final int lastPage;
  final int total;

  const OtherDocumentPageEntity({
    required this.items,
    required this.currentPage,
    required this.lastPage,
    required this.total,
  });

  bool get hasMore => currentPage < lastPage;
}

/// Filtros de las otras listas: el rango de "Creado" (por defecto, hoy) y la búsqueda por número.
class OtherDocumentFilters {
  final DateTime? desde;
  final DateTime? hasta;

  const OtherDocumentFilters({this.desde, this.hasta});

  factory OtherDocumentFilters.hoy(DateTime now) {
    final today = DateTime(now.year, now.month, now.day);
    return OtherDocumentFilters(desde: today, hasta: today);
  }

  /// Hay un rango distinto de "todas las fechas".
  bool get hasRange => desde != null && hasta != null;
}
