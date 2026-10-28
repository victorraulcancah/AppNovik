/// Cifras de ventas del rango y del mismo rango del año anterior.
class SalesFiguresEntity {
  final double total;
  final double totalAnterior;
  final double? totalVariacion;
  final int numero;
  final int numeroAnterior;
  final double? numeroVariacion;
  final double ticket;
  final double ticketAnterior;
  final double? ticketVariacion;

  const SalesFiguresEntity({
    this.total = 0,
    this.totalAnterior = 0,
    this.totalVariacion,
    this.numero = 0,
    this.numeroAnterior = 0,
    this.numeroVariacion,
    this.ticket = 0,
    this.ticketAnterior = 0,
    this.ticketVariacion,
  });
}

/// Un renglón de un ranking (cliente, producto, departamento, almacén).
class RankedItemEntity {
  final String? codigo;
  final String nombre;
  final double monto;

  const RankedItemEntity({required this.nombre, required this.monto, this.codigo});
}

/// Color del avance de la meta: rojo bajo 50 %, ámbar hasta 100 %, verde desde ahí.
enum GoalLight { rojo, ambar, verde, gris }

/// Meta de ventas del mes. `aplica` es falso cuando el rango abarca varios
/// meses: la meta es mensual y no corresponde mostrarla.
class GoalEntity {
  final bool aplica;
  final double monto;
  final double venta;
  final double falta;
  final double? avance;
  final GoalLight semaforo;

  const GoalEntity({
    this.aplica = false,
    this.monto = 0,
    this.venta = 0,
    this.falta = 0,
    this.avance,
    this.semaforo = GoalLight.gris,
  });

  bool get conMeta => aplica && monto > 0;
}

enum QuotePriority { baja, media, alta }

/// Cotización que sigue sin procesar.
class PendingQuoteEntity {
  final int id;
  final String documento;
  final String cliente;
  final double monto;
  final int dias;
  final QuotePriority prioridad;

  const PendingQuoteEntity({
    required this.id,
    required this.documento,
    required this.cliente,
    required this.monto,
    required this.dias,
    required this.prioridad,
  });
}

/// Venta de un mes: este año contra el anterior.
class MonthSalesEntity {
  final int mes;
  final double anterior;
  final double actual;

  const MonthSalesEntity({required this.mes, required this.anterior, required this.actual});
}

class EvolutionEntity {
  final int anioActual;
  final int anioAnterior;
  final List<MonthSalesEntity> meses;

  const EvolutionEntity({
    required this.anioActual,
    required this.anioAnterior,
    this.meses = const [],
  });
}

/// Resumen ejecutivo del usuario: lo que vendió en el rango, su meta, la
/// evolución del año, sus mejores clientes y productos, y sus cotizaciones
/// pendientes. Lo arma el backend a partir de las ventas que se le atribuyen.
class ExecutiveSummaryEntity {
  final String vendedor;
  final DateTime desde;
  final DateTime hasta;
  final DateTime desdeAnterior;
  final DateTime hastaAnterior;
  final SalesFiguresEntity ventas;
  final List<RankedItemEntity> porAlmacen;
  final GoalEntity meta;
  final int cotizacionesCantidad;
  final double cotizacionesMonto;
  final List<PendingQuoteEntity> cotizaciones;
  final EvolutionEntity evolucion;
  final List<RankedItemEntity> topProductos;
  final List<RankedItemEntity> topClientes;
  final List<RankedItemEntity> departamentos;

  const ExecutiveSummaryEntity({
    required this.vendedor,
    required this.desde,
    required this.hasta,
    required this.desdeAnterior,
    required this.hastaAnterior,
    required this.ventas,
    required this.meta,
    required this.evolucion,
    this.porAlmacen = const [],
    this.cotizacionesCantidad = 0,
    this.cotizacionesMonto = 0,
    this.cotizaciones = const [],
    this.topProductos = const [],
    this.topClientes = const [],
    this.departamentos = const [],
  });

  /// El rango abarca un solo mes (solo entonces la meta tiene sentido).
  bool get unSoloMes => desde.year == hasta.year && desde.month == hasta.month;
}
