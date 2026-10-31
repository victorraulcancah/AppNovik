/// Una opción de un filtro: su id (texto, porque los departamentos usan códigos con ceros como
/// `01`) y su nombre.
typedef ReportOption = ({String id, String name});

/// Filtros del reporte Ventas General: el rango de fechas y los filtros avanzados (cada lista
/// vacía significa "todos").
class SalesReportFilters {
  final DateTime desde;
  final DateTime hasta;
  final List<String> sucursales;
  final List<String> clientes;
  final List<String> vendedores;
  final List<String> marcas;
  final List<String> categorias;
  final List<String> departamentos;

  const SalesReportFilters({
    required this.desde,
    required this.hasta,
    this.sucursales = const [],
    this.clientes = const [],
    this.vendedores = const [],
    this.marcas = const [],
    this.categorias = const [],
    this.departamentos = const [],
  });

  SalesReportFilters copyWith({
    DateTime? desde,
    DateTime? hasta,
    List<String>? sucursales,
    List<String>? clientes,
    List<String>? vendedores,
    List<String>? marcas,
    List<String>? categorias,
    List<String>? departamentos,
  }) =>
      SalesReportFilters(
        desde: desde ?? this.desde,
        hasta: hasta ?? this.hasta,
        sucursales: sucursales ?? this.sucursales,
        clientes: clientes ?? this.clientes,
        vendedores: vendedores ?? this.vendedores,
        marcas: marcas ?? this.marcas,
        categorias: categorias ?? this.categorias,
        departamentos: departamentos ?? this.departamentos,
      );

  /// Cuántos filtros avanzados hay puestos (sin contar las fechas).
  int get advancedCount => [sucursales, clientes, vendedores, marcas, categorias, departamentos]
      .where((l) => l.isNotEmpty)
      .length;

  /// El mismo rango un año antes (el 29 de febrero pasa al 28).
  SalesReportFilters get yearBefore {
    DateTime back(DateTime d) {
      final year = d.year - 1;
      final lastDay = DateTime(year, d.month + 1, 0).day;
      return DateTime(year, d.month, d.day > lastDay ? lastDay : d.day);
    }

    return copyWith(desde: back(desde), hasta: back(hasta));
  }
}

/// Lo que se puede elegir en los filtros avanzados.
class SalesReportCatalogs {
  final List<ReportOption> sucursales;
  final List<ReportOption> clientes;
  final List<ReportOption> vendedores;
  final List<ReportOption> marcas;
  final List<ReportOption> categorias;
  final List<ReportOption> departamentos;

  const SalesReportCatalogs({
    this.sucursales = const [],
    this.clientes = const [],
    this.vendedores = const [],
    this.marcas = const [],
    this.categorias = const [],
    this.departamentos = const [],
  });
}

/// Ventas de un día (o de un mes, en rangos largos) para la gráfica.
class SalesReportDayEntity {
  /// Cómo lo rotula el servidor: `05-Octubre` o `Octubre`.
  final String name;
  final double ventasSoles;
  final double ventasDolares;
  final double ventasDolaresASoles;
  final double unidades;

  const SalesReportDayEntity({
    required this.name,
    this.ventasSoles = 0,
    this.ventasDolares = 0,
    this.ventasDolaresASoles = 0,
    this.unidades = 0,
  });
}

/// Un producto vendido en el rango, con lo que se vendió de él.
class SalesReportProductEntity {
  final int id;
  final String codigo;
  final String name;
  final String? marca;
  final String? imagen;
  final double cantidad;
  final double subtotal;
  final double descuento;
  final double venta;

  /// Costo promedio por unidad.
  final double costo;

  const SalesReportProductEntity({
    required this.id,
    required this.name,
    this.codigo = '',
    this.marca,
    this.imagen,
    this.cantidad = 0,
    this.subtotal = 0,
    this.descuento = 0,
    this.venta = 0,
    this.costo = 0,
  });

  double get costoTotal => costo * cantidad;

  /// Margen de la web: el subtotal menos lo que costó.
  double get margen => subtotal - costoTotal;
}

/// Una venta del rango (solo lo necesario para listarla bajo un producto).
class SalesReportDocumentEntity {
  final int id;

  /// `Boleta`, `Factura` o `Venta`.
  final String tipo;
  final String numero;
  final List<int> productIds;

  const SalesReportDocumentEntity({
    required this.id,
    required this.tipo,
    required this.numero,
    this.productIds = const [],
  });
}

/// Margen bruto y neto de un total de ventas y de costos, como los calcula la web.
class MarginFigures {
  final double bruto;
  final double brutoPct;
  final double neto;
  final double netoPct;

  const MarginFigures({this.bruto = 0, this.brutoPct = 0, this.neto = 0, this.netoPct = 0});

  /// [igv] y [renta] son fracciones (0.18, 0.015). El neto descuenta el IGV y la renta del margen.
  factory MarginFigures.of(double ventas, double costos, {double igv = 0, double renta = 0}) {
    final sinIgv = ventas / (1 + igv);
    final costosSinIgv = costos / (1 + igv);
    final margenSinIgv = sinIgv - costosSinIgv;
    final bruto = ventas - costos;
    final neto = bruto - (margenSinIgv * igv + sinIgv * renta);
    return MarginFigures(
      bruto: bruto,
      brutoPct: ventas > 0 ? bruto / ventas * 100 : 0,
      neto: neto,
      netoPct: ventas > 0 ? neto / ventas * 100 : 0,
    );
  }
}

/// El reporte Ventas General: las cifras del rango, la serie de la gráfica, las ventas y una
/// página de productos (el servidor pagina solo los productos; lo demás viene completo).
class SalesReportEntity {
  final List<SalesReportDayEntity> days;
  final List<SalesReportDocumentEntity> documents;
  final List<SalesReportProductEntity> products;

  /// Cuántos productos distintos se vendieron (todas las páginas).
  final int totalProducts;
  final int countVentas;
  final double unidades;
  final double totalVentas;
  final double totalCostos;

  const SalesReportEntity({
    this.days = const [],
    this.documents = const [],
    this.products = const [],
    this.totalProducts = 0,
    this.countVentas = 0,
    this.unidades = 0,
    this.totalVentas = 0,
    this.totalCostos = 0,
  });

  /// Lo vendido por día sumado, en soles (los dólares ya convertidos): base del ticket promedio.
  double get ventasDelRango => days.fold<double>(0, (sum, d) => sum + d.ventasSoles + d.ventasDolaresASoles);

  /// Ticket promedio de la web: lo vendido entre el número de ventas.
  double get ticketPromedio => ventasDelRango / (countVentas == 0 ? 1 : countVentas);

  bool get isEmpty => totalProducts == 0 && countVentas == 0;
}
