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
  /// Solo traslados: el producto, para marcarlo como recibido o validado.
  final int? productId;
  final double cantidad;
  final String? codigo;
  final String name;
  final String? marca;

  /// Entradas de stock: el costo de ingreso. Traslados: el costo promedio en el almacén de salida.
  final double costo;

  /// Solo traslados: si ya se recibió en el almacén de destino.
  final bool aceptado;

  /// Solo traslados: el código de barras del producto (con él se valida) y si ya se validó.
  final String? codBarra;
  final bool confirmado;

  const OtherDocumentLine({
    this.productId,
    required this.cantidad,
    required this.name,
    this.codigo,
    this.marca,
    this.costo = 0,
    this.aceptado = false,
    this.codBarra,
    this.confirmado = false,
  });

  double get total => cantidad * costo;

  OtherDocumentLine copyWith({bool? aceptado, bool? confirmado}) => OtherDocumentLine(
        productId: productId,
        cantidad: cantidad,
        name: name,
        codigo: codigo,
        marca: marca,
        costo: costo,
        aceptado: aceptado ?? this.aceptado,
        codBarra: codBarra,
        confirmado: confirmado ?? this.confirmado,
      );
}

/// Lo que se puede hacer con un producto de un traslado (como en la web).
enum TransferLineAction {
  /// Nada: ya está recibido, el traslado fue eliminado o no es un traslado.
  none,

  /// Marcarlo como recibido en el almacén de destino.
  receive,

  /// Validarlo escribiendo su código de barras.
  validate,
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

  /// `01` pública, `02` privada.
  final String? tipoGuia;

  /// Código del motivo de traslado (`01` venta, `02` compra...).
  final String? codTraslado;
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
    this.codTraslado,
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

  /// Traslados: el almacén de destino (`to`), para saber quién puede recibir.
  final int? haciaId;
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
    this.haciaId,
    this.lines = const [],
    this.guia,
    this.nota,
    this.comprobanteNumero,
    this.comprobante,
  });

  /// Lo mismo con otras líneas y otro estado (al marcar productos como recibidos o validados).
  OtherDocumentEntity copyWith({bool? activo, List<OtherDocumentLine>? lines}) => OtherDocumentEntity(
        kind: kind,
        id: id,
        numero: numero,
        creado: creado,
        activo: activo ?? this.activo,
        usuario: usuario,
        almacen: almacen,
        desde: desde,
        hacia: hacia,
        haciaId: haciaId,
        lines: lines ?? this.lines,
        guia: guia,
        nota: nota,
        comprobanteNumero: comprobanteNumero,
        comprobante: comprobante,
      );

  /// Qué se puede hacer con [line] en este traslado, igual que la web:
  ///  - Admin Empresa, Ceo Empresa o quien tenga el almacén de destino: **recibir** el producto
  ///    (si el traslado fue eliminado o el producto ya se recibió, nada).
  ///  - Los demás: **validar** el producto con su código de barras.
  ///
  /// [isAdminOrCeo] y [warehouseIds] (los almacenes del usuario) salen de la sesión.
  TransferLineAction actionFor(
    OtherDocumentLine line, {
    required bool isAdminOrCeo,
    required Iterable<int> warehouseIds,
  }) {
    if (kind != OtherDocumentKind.traslado || line.productId == null) return TransferLineAction.none;
    final hasDestination = haciaId != null && warehouseIds.contains(haciaId);
    if (!isAdminOrCeo && !hasDestination) return TransferLineAction.validate;
    if (!activo || line.aceptado) return TransferLineAction.none;
    return TransferLineAction.receive;
  }

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
