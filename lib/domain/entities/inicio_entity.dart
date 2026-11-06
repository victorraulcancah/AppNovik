/// Datos del módulo Inicio (el Dashboard de la web): la pantalla general y los tres resúmenes por
/// rol (Ejecutivo, Jefe y CEO). Los nombres de los campos siguen a los del backend
/// (`/ventas/reporte-almacenes`, `/ventas/resumen-ejecutivo`, `/ventas/resumen-equipo`,
/// `/ventas/resumen-ceo`).
library;

/// Semáforo de la meta (el de Metas Comerciales): rojo debajo del 50 %, ámbar hasta el 100 %,
/// verde desde ahí; gris sin meta.
enum GoalLight { rojo, ambar, verde, gris }

/// Lo vendido en un almacén en el mes (pantalla general).
class WarehouseSalesEntity {
  final int id;
  final String nombre;
  final double total;

  const WarehouseSalesEntity({required this.id, required this.nombre, required this.total});
}

/// La meta del mes en que termina el rango. `aplica` es falso cuando el rango abarca varios
/// meses: la meta es mensual y no corresponde mostrarla.
class GoalEntity {
  final bool aplica;
  final int anio;
  final int mes;
  final double monto;
  final double venta;
  final double falta;
  final double? avance;
  final GoalLight semaforo;

  const GoalEntity({
    this.aplica = false,
    this.anio = 0,
    this.mes = 0,
    this.monto = 0,
    this.venta = 0,
    this.falta = 0,
    this.avance,
    this.semaforo = GoalLight.gris,
  });

  /// Hay una meta cargada para mostrar.
  bool get hasGoal => aplica && monto > 0;
}

/// Ventas del rango contra el mismo rango del año pasado (Ejecutivo y Jefe).
class SalesFiguresEntity {
  final double total;
  final double totalAnterior;
  final double? variacionPct;
  final int numero;
  final int numeroAnterior;
  final double? numeroVariacionPct;
  final double ticket;
  final double ticketAnterior;
  final double? ticketVariacionPct;

  const SalesFiguresEntity({
    this.total = 0,
    this.totalAnterior = 0,
    this.variacionPct,
    this.numero = 0,
    this.numeroAnterior = 0,
    this.numeroVariacionPct,
    this.ticket = 0,
    this.ticketAnterior = 0,
    this.ticketVariacionPct,
  });
}

/// Un monto con su nombre (top de clientes, productos, departamentos, almacenes...).
class RankedAmountEntity {
  final int? id;
  final String? codigo;
  final String nombre;
  final double monto;
  final double unidades;

  const RankedAmountEntity({
    this.id,
    this.codigo,
    required this.nombre,
    required this.monto,
    this.unidades = 0,
  });
}

/// Las ventas de un mes este año y el anterior.
class MonthPairEntity {
  final int mes;
  final double anterior;
  final double actual;

  const MonthPairEntity({required this.mes, required this.anterior, required this.actual});
}

class EvolutionEntity {
  final int anioActual;
  final int anioAnterior;
  final List<MonthPairEntity> meses;

  const EvolutionEntity({this.anioActual = 0, this.anioAnterior = 0, this.meses = const []});
}

/// Cuántos hay en cada estado de caída (Crítico, En riesgo, En seguimiento...).
class StatusCountsEntity {
  final int critico;
  final int riesgo;
  final int seguimiento;

  const StatusCountsEntity({this.critico = 0, this.riesgo = 0, this.seguimiento = 0});

  /// Los que están en caída: Crítico + En riesgo + En seguimiento.
  int get enCaida => critico + riesgo + seguimiento;
}

/// Suma de lo vendido el año pasado y este año por todos los de una lista, y su variación en soles.
class FallTotalsEntity {
  final double anterior;
  final double actual;
  final double variacion;

  const FallTotalsEntity({this.anterior = 0, this.actual = 0, this.variacion = 0});
}

/// Un cliente en caída: lo del año pasado, lo de este año y el estado (`critico`, `riesgo`...).
class FallClientEntity {
  final int id;
  final String cliente;
  final String? vendedor;
  final double anterior;
  final double actual;
  final double? caidaPct;
  final String estado;

  const FallClientEntity({
    required this.id,
    required this.cliente,
    this.vendedor,
    required this.anterior,
    required this.actual,
    this.caidaPct,
    required this.estado,
  });

  /// Variación en soles (este año menos el año pasado).
  double get variacion => actual - anterior;
}

class FallClientsEntity {
  final int total;
  final FallTotalsEntity totales;
  final List<FallClientEntity> filas;

  const FallClientsEntity({this.total = 0, this.totales = const FallTotalsEntity(), this.filas = const []});
}

/// Un producto con caída contra el mismo rango del año pasado.
class FallProductEntity {
  final int id;
  final String? codigo;
  final String producto;
  final double anterior;
  final double actual;
  final double variacion;
  final double? caidaPct;

  const FallProductEntity({
    required this.id,
    this.codigo,
    required this.producto,
    required this.anterior,
    required this.actual,
    required this.variacion,
    this.caidaPct,
  });
}

/// Prioridad de una cotización pendiente por días desde su emisión (0-3 baja, 4-7 media, 8+ alta).
enum QuotePriority { baja, media, alta }

class PendingQuoteEntity {
  final int id;
  final String cliente;
  final String? vendedor;

  /// Monto en soles.
  final double monto;

  /// Monto en su moneda (`soles` o `dolares`); en el resumen del Ejecutivo es el mismo `monto`.
  final double montoMoneda;
  final bool enDolares;
  final int dias;
  final QuotePriority prioridad;

  const PendingQuoteEntity({
    required this.id,
    required this.cliente,
    this.vendedor,
    required this.monto,
    required this.montoMoneda,
    this.enDolares = false,
    required this.dias,
    required this.prioridad,
  });
}

/// Una gestión programada (llamada, WhatsApp, visita o correo) del vendedor.
class TaskEntity {
  final int id;
  final int clienteId;
  final String cliente;
  final String tipo;
  final String tipoEtiqueta;
  final String? accion;
  final DateTime fecha;
  final bool vencida;

  const TaskEntity({
    required this.id,
    required this.clienteId,
    required this.cliente,
    required this.tipo,
    required this.tipoEtiqueta,
    this.accion,
    required this.fecha,
    required this.vencida,
  });
}

class BirthdayEntity {
  final int id;
  final String nombre;
  final String? telefono;
  final int dia;
  final int mes;
  final bool esHoy;
  final bool yaPaso;

  const BirthdayEntity({
    required this.id,
    required this.nombre,
    this.telefono,
    required this.dia,
    required this.mes,
    required this.esHoy,
    required this.yaPaso,
  });
}

/// Lo vendido por un vendedor contra su meta del mes.
class SellerGoalEntity {
  final int id;
  final String nombre;
  final double venta;
  final double? meta;
  final double? avance;
  final GoalLight semaforo;

  const SellerGoalEntity({
    required this.id,
    required this.nombre,
    required this.venta,
    this.meta,
    this.avance,
    this.semaforo = GoalLight.gris,
  });
}

class DepartmentEntity {
  final String nombre;
  final double monto;
  final double participacion;

  const DepartmentEntity({required this.nombre, required this.monto, required this.participacion});
}

/// Resumen Ejecutivo (rol Vendedor): sus ventas, meta, cartera, tareas y cumpleaños.
class ExecutiveSummaryEntity {
  final String vendedor;
  final DateTime desde;
  final DateTime hasta;
  final DateTime desdeAnterior;
  final DateTime hastaAnterior;
  final SalesFiguresEntity ventas;
  final List<RankedAmountEntity> porAlmacen;
  final GoalEntity meta;
  final int cotizacionesCantidad;
  final double cotizacionesMonto;
  final List<PendingQuoteEntity> cotizaciones;
  final EvolutionEntity evolucion;
  final List<RankedAmountEntity> topProductos;
  final List<RankedAmountEntity> topClientes;
  final List<RankedAmountEntity> departamentos;
  final StatusCountsEntity clientesSinCompra;
  final StatusCountsEntity productosSinVenta;
  final FallClientsEntity conCaida;
  final List<TaskEntity> tareas;
  final List<BirthdayEntity> cumpleanos;

  const ExecutiveSummaryEntity({
    required this.vendedor,
    required this.desde,
    required this.hasta,
    required this.desdeAnterior,
    required this.hastaAnterior,
    required this.ventas,
    this.porAlmacen = const [],
    required this.meta,
    this.cotizacionesCantidad = 0,
    this.cotizacionesMonto = 0,
    this.cotizaciones = const [],
    required this.evolucion,
    this.topProductos = const [],
    this.topClientes = const [],
    this.departamentos = const [],
    this.clientesSinCompra = const StatusCountsEntity(),
    this.productosSinVenta = const StatusCountsEntity(),
    this.conCaida = const FallClientsEntity(),
    this.tareas = const [],
    this.cumpleanos = const [],
  });
}

/// Gestiones del equipo de un tipo en un periodo: hechas / programadas.
class ManagementEntity {
  final String tipo;
  final int hechas;
  final int programadas;
  final double? pct;

  const ManagementEntity({required this.tipo, required this.hechas, required this.programadas, this.pct});
}

/// Periodo de las tareas y gestiones: hoy, esta semana (lunes a domingo) o este mes.
enum TaskPeriod {
  hoy('Hoy', 'hoy'),
  semana('Semana', 'semana'),
  mes('Mes', 'mes');

  final String label;

  /// Clave que usa el backend.
  final String key;
  const TaskPeriod(this.label, this.key);
}

/// Resumen del Jefe Comercial: las ventas de todo el equipo contra la meta de la empresa.
class TeamSummaryEntity {
  final String jefe;
  final DateTime desde;
  final DateTime hasta;
  final DateTime desdeAnterior;
  final DateTime hastaAnterior;
  final SalesFiguresEntity ventas;
  final GoalEntity meta;
  final EvolutionEntity evolucion;
  final List<SellerGoalEntity> vendedores;
  final List<RankedAmountEntity> topProductos;
  final List<DepartmentEntity> departamentos;
  final StatusCountsEntity clientesCaidaEstados;
  final FallClientsEntity clientesCaida;
  final StatusCountsEntity productosSinVentasEstados;
  final List<FallProductEntity> productosMayorCaida;
  final int cotizacionesCantidad;
  final double cotizacionesMonto;
  final double cotizacionesSoles;
  final double cotizacionesDolares;
  final List<PendingQuoteEntity> cotizaciones;
  final Map<TaskPeriod, List<ManagementEntity>> gestiones;

  const TeamSummaryEntity({
    required this.jefe,
    required this.desde,
    required this.hasta,
    required this.desdeAnterior,
    required this.hastaAnterior,
    required this.ventas,
    required this.meta,
    required this.evolucion,
    this.vendedores = const [],
    this.topProductos = const [],
    this.departamentos = const [],
    this.clientesCaidaEstados = const StatusCountsEntity(),
    this.clientesCaida = const FallClientsEntity(),
    this.productosSinVentasEstados = const StatusCountsEntity(),
    this.productosMayorCaida = const [],
    this.cotizacionesCantidad = 0,
    this.cotizacionesMonto = 0,
    this.cotizacionesSoles = 0,
    this.cotizacionesDolares = 0,
    this.cotizaciones = const [],
    this.gestiones = const {},
  });
}

/// Ventas de la empresa: contra el mismo rango del año pasado y contra el mes anterior.
class CeoSalesEntity {
  final double total;
  final double totalAnterior;
  final double? variacionPct;
  final double mesAnterior;
  final double? mesAnteriorPct;
  final DateTime mesAnteriorDesde;
  final DateTime mesAnteriorHasta;

  /// Venta ÷ días transcurridos × días del mes; solo con el mes en curso.
  final double? proyeccion;
  final int numero;
  final double ticket;

  const CeoSalesEntity({
    this.total = 0,
    this.totalAnterior = 0,
    this.variacionPct,
    this.mesAnterior = 0,
    this.mesAnteriorPct,
    required this.mesAnteriorDesde,
    required this.mesAnteriorHasta,
    this.proyeccion,
    this.numero = 0,
    this.ticket = 0,
  });
}

/// Indicadores estratégicos del año (YTD).
class CeoIndicatorsEntity {
  final double ventasAcumuladas;
  final double ventasAcumuladasAnterior;
  final double? ventasAcumuladasPct;
  final double utilidadEstimada;
  final double? margenPct;
  final double cotizacionesMonto;
  final int cotizacionesCantidad;
  final int clientesActivos;
  final int clientesActivosAnterior;
  final double? clientesActivosPct;

  const CeoIndicatorsEntity({
    this.ventasAcumuladas = 0,
    this.ventasAcumuladasAnterior = 0,
    this.ventasAcumuladasPct,
    this.utilidadEstimada = 0,
    this.margenPct,
    this.cotizacionesMonto = 0,
    this.cotizacionesCantidad = 0,
    this.clientesActivos = 0,
    this.clientesActivosAnterior = 0,
    this.clientesActivosPct,
  });
}

/// Ventas por canal: los clientes de una categoría y lo vendido a ellos.
class ChannelEntity {
  final String? codigo;
  final String nombre;
  final int clientes;
  final double monto;

  const ChannelEntity({this.codigo, required this.nombre, required this.clientes, required this.monto});
}

/// Cuentas por cobrar de hoy.
class ReceivablesEntity {
  final double total;
  final double porVencer;
  final double porVencerPct;
  final double vencido;
  final double vencidoPct;

  const ReceivablesEntity({
    this.total = 0,
    this.porVencer = 0,
    this.porVencerPct = 0,
    this.vencido = 0,
    this.vencidoPct = 0,
  });
}

/// Depósitos registrados por un vendedor en Pagos de Vendedores.
class SellerCollectionEntity {
  final int id;
  final String nombre;

  /// Todo en soles (dólares convertidos).
  final double cobrado;
  final double soles;
  final double dolares;
  final double pendiente;

  const SellerCollectionEntity({
    required this.id,
    required this.nombre,
    this.cobrado = 0,
    this.soles = 0,
    this.dolares = 0,
    this.pendiente = 0,
  });
}

/// Lo cobrado por un método de pago (con su banco o entidad), hoy y en el mes anterior.
class PaymentIncomeEntity {
  final String metodo;
  final String entidad;
  final double monto;
  final double soles;
  final double dolares;
  final double montoAnterior;
  final double solesAnterior;
  final double dolaresAnterior;

  const PaymentIncomeEntity({
    required this.metodo,
    this.entidad = '',
    this.monto = 0,
    this.soles = 0,
    this.dolares = 0,
    this.montoAnterior = 0,
    this.solesAnterior = 0,
    this.dolaresAnterior = 0,
  });
}

/// Ingresos del rango por método de pago, contra el mismo rango un mes antes.
class IncomesEntity {
  final double total;
  final double totalSoles;
  final double totalDolares;
  final double totalAnterior;
  final double? variacionPct;
  final double totalSolesAnterior;
  final double totalDolaresAnterior;
  final double? variacionSolesPct;
  final double? variacionDolaresPct;
  final DateTime? desdeAnterior;
  final DateTime? hastaAnterior;
  final List<PaymentIncomeEntity> metodos;

  const IncomesEntity({
    this.total = 0,
    this.totalSoles = 0,
    this.totalDolares = 0,
    this.totalAnterior = 0,
    this.variacionPct,
    this.totalSolesAnterior = 0,
    this.totalDolaresAnterior = 0,
    this.variacionSolesPct,
    this.variacionDolaresPct,
    this.desdeAnterior,
    this.hastaAnterior,
    this.metodos = const [],
  });
}

class NewClientsEntity {
  final int cantidad;
  final double? cantidadPct;
  final double ventas;
  final double? ventasPct;
  final List<RankedAmountEntity> top;

  const NewClientsEntity({
    this.cantidad = 0,
    this.cantidadPct,
    this.ventas = 0,
    this.ventasPct,
    this.top = const [],
  });
}

/// Resumen del CEO: el panorama de toda la empresa, con filtro de almacén (`sucursal`).
class CeoSummaryEntity {
  final String ceo;
  final String empresa;
  final DateTime desde;
  final DateTime hasta;
  final DateTime desdeAnterior;
  final DateTime hastaAnterior;

  /// Almacén elegido (`null`: todos) y los que se pueden elegir.
  final int? sucursal;
  final List<WarehouseOption> sucursales;
  final CeoSalesEntity ventas;
  final GoalEntity meta;
  final EvolutionEntity evolucion;
  final CeoIndicatorsEntity indicadores;
  final List<SellerGoalEntity> vendedores;
  final List<DepartmentEntity> departamentos;
  final List<ChannelEntity> canales;
  final ReceivablesEntity cuentasPorCobrar;
  final List<SellerCollectionEntity> cobroPorVendedor;
  final IncomesEntity ingresos;
  final NewClientsEntity nuevosClientes;
  final FallClientsEntity clientesCaida;
  final List<FallProductEntity> productosMayorCaida;

  const CeoSummaryEntity({
    required this.ceo,
    required this.empresa,
    required this.desde,
    required this.hasta,
    required this.desdeAnterior,
    required this.hastaAnterior,
    this.sucursal,
    this.sucursales = const [],
    required this.ventas,
    required this.meta,
    required this.evolucion,
    this.indicadores = const CeoIndicatorsEntity(),
    this.vendedores = const [],
    this.departamentos = const [],
    this.canales = const [],
    this.cuentasPorCobrar = const ReceivablesEntity(),
    this.cobroPorVendedor = const [],
    this.ingresos = const IncomesEntity(),
    this.nuevosClientes = const NewClientsEntity(),
    this.clientesCaida = const FallClientsEntity(),
    this.productosMayorCaida = const [],
  });
}

class WarehouseOption {
  final int id;
  final String name;

  const WarehouseOption({required this.id, required this.name});
}
