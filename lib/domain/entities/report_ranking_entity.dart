/// Los reportes de Reportes: "Venta general" (el de siempre) y los rankings por departamento,
/// vendedor, marca, categoría y cliente.
enum ReportKind {
  general(
    chip: 'Venta general',
    subtitle: 'Ventas General',
    permission: 'reportes.ventas.index',
  ),
  departamentos(
    chip: 'Departamentos',
    subtitle: 'Departamentos',
    cardTitle: 'Ventas por departamentos',
    plural: 'departamentos',
    permission: 'reportes.sucursal.index',
  ),
  vendedores(
    chip: 'Vendedor',
    subtitle: 'Vendedor',
    cardTitle: 'Ventas por vendedores',
    plural: 'vendedores',
    permission: 'reportes.vendedor.index',
  ),
  marcas(
    chip: 'Marcas',
    subtitle: 'Marcas',
    cardTitle: 'Ventas por marcas',
    plural: 'marcas',
    permission: 'reportes.marcas.index',
  ),
  categorias(
    chip: 'Categoría',
    subtitle: 'Categorías',
    cardTitle: 'Ventas por categorías',
    plural: 'categorías',
    permission: 'reportes.categorias.index',
  ),
  clientes(
    chip: 'Cliente',
    subtitle: 'Clientes',
    cardTitle: 'Ventas por clientes',
    plural: 'clientes',
    permission: 'reportes.cliente_comparativa.index',
  );

  /// Cómo se rotula en el selector de reportes.
  final String chip;

  /// Lo que dice el encabezado de la pantalla bajo "Reportes".
  final String subtitle;

  /// Título de la tarjeta del resumen y de la lista completa ("Ventas por marcas").
  final String cardTitle;

  /// Plural en minúsculas, para el conteo ("12 marcas").
  final String plural;

  /// Permiso de la web que da acceso a este reporte (además de `reportes.index`).
  final String permission;

  const ReportKind({
    required this.chip,
    required this.subtitle,
    required this.permission,
    this.cardTitle = '',
    this.plural = '',
  });

  /// Los reportes por entidad (todos menos "Venta general").
  bool get isRanking => this != ReportKind.general;
}

/// Una fila de un ranking: a quién (departamento, vendedor, marca, categoría o cliente) y cuánto
/// se le vendió en el rango.
class RankingRow {
  final int? id;
  final String name;

  /// Venta total en soles.
  final double venta;

  /// Cuántas ventas tuvo (0 si el reporte no lo trae).
  final int nVentas;
  final double subtotal;
  final double descuento;
  final double margen;

  /// Solo clientes: su documento y su categoría.
  final String? documento;
  final String? categoria;

  const RankingRow({
    this.id,
    required this.name,
    this.venta = 0,
    this.nVentas = 0,
    this.subtotal = 0,
    this.descuento = 0,
    this.margen = 0,
    this.documento,
    this.categoria,
  });

  /// Lo vendido entre el número de ventas; `null` sin número de ventas.
  double? get ticketPromedio => nVentas > 0 ? venta / nVentas : null;
}

/// Un producto vendido a una entidad (departamento, vendedor, marca, categoría o cliente): lo que
/// responden los `productos-por-*` de la web. [venta] es el `subtotal` del servidor (la venta ya con
/// descuento, la columna "Venta Total" de la web).
class RankingProduct {
  final int id;
  final String codigo;
  final String name;
  final double cantidad;
  final double venta;
  final double margen;

  const RankingProduct({
    required this.id,
    required this.name,
    this.codigo = '',
    this.cantidad = 0,
    this.venta = 0,
    this.margen = 0,
  });
}

/// Una página de productos de una entidad.
class RankingProductsPage {
  final List<RankingProduct> products;

  /// ¿Faltan páginas por pedir? (los reportes que no paginan responden todo de una vez: `false`).
  final bool hasMore;

  const RankingProductsPage({this.products = const [], this.hasMore = false});
}

/// Una página de un ranking, de mayor a menor venta, con el total del rango: de él sale el
/// porcentaje de cada fila.
class RankingReport {
  final List<RankingRow> rows;

  /// Venta total de todo el reporte (todas las filas, no solo las de esta página).
  final double total;

  /// Cuántas filas hay en total (todas las páginas).
  final int totalRows;

  /// ¿Faltan páginas por pedir?
  final bool hasMore;

  const RankingReport({
    this.rows = const [],
    this.total = 0,
    this.totalRows = 0,
    this.hasMore = false,
  });

  /// Lo que representa [row] del total, de 0 a 100.
  double share(RankingRow row) => total > 0 ? row.venta / total * 100 : 0;
}
