/// Qué lista de la pantalla Documentos se está viendo.
enum DocumentKind { venta, cotizacion }

/// Producto o concepto de un documento.
class DocumentItemEntity {
  final String name;
  final String? codigo;
  final String? marca;
  final double cantidad;
  final double precio;
  final double subtotal;
  final bool dolares;

  const DocumentItemEntity({
    required this.name,
    this.codigo,
    this.marca,
    this.cantidad = 0,
    this.precio = 0,
    this.subtotal = 0,
    this.dolares = false,
  });
}

/// Forma de pago de una venta.
class DocumentPaymentEntity {
  final String metodo;
  final double monto;

  const DocumentPaymentEntity({required this.metodo, required this.monto});
}

/// Venta o cotización, con los datos que la web muestra en Documentos.
class DocumentEntity {
  final int id;
  final DocumentKind kind;

  /// Número como lo arma la web: `B001-00123`, `F001-0045`, `V001-0012`, `C001-0034`.
  final String numero;

  /// "Boleta", "Factura", "Nota de venta" o "Cotización".
  final String comprobante;

  /// `false` si el documento fue eliminado/anulado (o, en cotizaciones, ya usado).
  final bool activo;
  final String cliente;
  final String vendedor;
  final String? usuario;
  final String almacen;
  final double monto;
  final bool esDolares;
  final DateTime? creado;
  final String? observaciones;
  final String? anuladoPor;
  final DateTime? anuladoAt;

  /// Solo cotizaciones: si reservó stock.
  final bool? reservado;
  final List<DocumentItemEntity> items;
  final List<DocumentPaymentEntity> pagos;

  const DocumentEntity({
    required this.id,
    required this.kind,
    required this.numero,
    required this.comprobante,
    this.activo = true,
    this.cliente = '-',
    this.vendedor = '-',
    this.usuario,
    this.almacen = '-',
    this.monto = 0,
    this.esDolares = false,
    this.creado,
    this.observaciones,
    this.anuladoPor,
    this.anuladoAt,
    this.reservado,
    this.items = const [],
    this.pagos = const [],
  });

  String get simboloMoneda => esDolares ? r'$' : 'S/';
}

class DocumentPageEntity {
  final List<DocumentEntity> items;
  final int currentPage;
  final int lastPage;
  final int total;

  const DocumentPageEntity({
    required this.items,
    required this.currentPage,
    required this.lastPage,
    required this.total,
  });

  bool get hasMore => currentPage < lastPage;
}

/// Tipo de comprobante por el que se filtran las ventas.
enum DocumentTipo { boleta, factura, notaVenta }

/// Estado por el que se filtran los documentos.
enum DocumentEstado { activos, eliminados }

/// Rango de fechas del filtro; por defecto, igual que la web, solo hoy.
enum DocumentDateRange {
  hoy('Hoy'),
  semana('Últimos 7 días'),
  mes('Este mes'),
  todos('Todos');

  final String label;
  const DocumentDateRange(this.label);

  /// Primer y último día (inclusive) para [now]; `null` si no hay límite.
  (DateTime from, DateTime to)? bounds(DateTime now) {
    final today = DateTime(now.year, now.month, now.day);
    return switch (this) {
      DocumentDateRange.hoy => (today, today),
      DocumentDateRange.semana => (today.subtract(const Duration(days: 6)), today),
      DocumentDateRange.mes => (DateTime(now.year, now.month, 1), today),
      DocumentDateRange.todos => null,
    };
  }
}
