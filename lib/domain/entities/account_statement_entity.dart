import 'document_entity.dart';

/// Rangos rápidos de fechas, los mismos de la web (Última semana, Este mes…).
enum StatementRange {
  ultimaSemana('Última semana'),
  estaSemana('Esta semana'),
  ultimoMes('Último mes'),
  esteMes('Este mes'),
  ultimoAnio('Último año'),
  esteAnio('Este año'),
  personalizado('Elegir fechas');

  final String label;
  const StatementRange(this.label);

  /// Desde y hasta (días completos) de este rango, a la fecha [now]. [custom] solo vale en
  /// [personalizado].
  ({DateTime start, DateTime end}) datesFor(DateTime now, {({DateTime start, DateTime end})? custom}) {
    final today = DateTime(now.year, now.month, now.day);
    final monday = today.subtract(Duration(days: today.weekday - 1));
    return switch (this) {
      ultimaSemana => (
        start: monday.subtract(const Duration(days: 7)),
        end: monday.subtract(const Duration(days: 1)),
      ),
      estaSemana => (start: monday, end: today),
      ultimoMes => (start: DateTime(today.year, today.month - 1), end: DateTime(today.year, today.month, 0)),
      esteMes => (start: DateTime(today.year, today.month), end: today),
      ultimoAnio => (start: DateTime(today.year - 1), end: DateTime(today.year - 1, 12, 31)),
      esteAnio => (start: DateTime(today.year), end: today),
      personalizado => custom ?? (start: today, end: today),
    };
  }
}

/// Las tres pestañas del módulo.
enum StatementTab {
  estadoDeCuenta('Estado de Cuenta', 'Estado de cuenta'),
  pedidos('Pedidos', 'Estado de cuenta Pedidos'),
  pagos('Pagos', 'Estado de cuenta Pagos');

  final String label;

  /// Nombre base del archivo que se exporta.
  final String fileName;
  const StatementTab(this.label, this.fileName);
}

/// Qué se consulta: el cliente, las fechas y, en la pestaña principal, si va agrupado por venta y
/// el texto buscado en la descripción del producto.
class StatementQuery {
  final int clientId;
  final DateTime from;
  final DateTime to;
  final bool agrupado;
  final String? search;

  const StatementQuery({
    required this.clientId,
    required this.from,
    required this.to,
    this.agrupado = false,
    this.search,
  });
}

/// La cabecera: línea de crédito, crédito disponible, línea utilizada, deuda total y deuda anterior.
class StatementSummaryEntity {
  final double credito;
  final double creditoDisponible;
  final double lineaUtilizada;
  final double deudaTotalSoles;
  final double deudaTotalDolares;
  final double deudaAnteriorSoles;
  final double deudaAnteriorDolares;

  const StatementSummaryEntity({
    this.credito = 0,
    this.creditoDisponible = 0,
    this.lineaUtilizada = 0,
    this.deudaTotalSoles = 0,
    this.deudaTotalDolares = 0,
    this.deudaAnteriorSoles = 0,
    this.deudaAnteriorDolares = 0,
  });

  bool get hayDeudaAnterior => deudaAnteriorSoles > 0 || deudaAnteriorDolares > 0;
}

/// Una fila de cualquiera de las tres pestañas (venta, pedido o pago).
class StatementRowEntity {
  final String id;
  final DateTime? fecha;

  /// `B001-0123`, `V001-0045`… o `-` si no es de un documento.
  final String documento;
  final double? cantidad;

  /// Lo principal: el producto, "Pagó con EFECTIVO" o "Venta 45".
  final String titulo;

  /// Código y marca del producto.
  final String? detalle;
  final double soles;
  final double dolares;

  /// Quién registró el pago y de dónde salió ("Cobrado en la venta", "Pago de cuota"…).
  final String? registradoPor;
  final String? origen;

  /// Es un pago (sale en rojo) y no una venta.
  final bool esPago;

  /// La venta está anulada (sale en rojo).
  final bool anulado;

  /// El comprobante, para abrirlo al tocar el documento (solo en la pestaña principal).
  final DocumentEntity? document;

  const StatementRowEntity({
    required this.id,
    this.fecha,
    this.documento = '-',
    this.cantidad,
    required this.titulo,
    this.detalle,
    this.soles = 0,
    this.dolares = 0,
    this.registradoPor,
    this.origen,
    this.esPago = false,
    this.anulado = false,
    this.document,
  });

  bool get enRojo => esPago || anulado;
}

/// Una página de filas; la principal trae además la cabecera.
class StatementPageEntity {
  final List<StatementRowEntity> rows;
  final int total;
  final StatementSummaryEntity? summary;

  const StatementPageEntity({required this.rows, required this.total, this.summary});
}
