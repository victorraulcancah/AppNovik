import 'document_entity.dart';

/// Tipo de comprobante de una venta. `apiValue` es el texto que espera el backend.
enum SaleDocumentType {
  ticket('Ticket de Venta', 'Ticket de Venta'),
  boleta('Boleta de Venta', 'Boleta'),
  factura('Factura', 'Factura'),

  /// No es una venta: no descuenta stock (salvo que se reserve) ni se cobra.
  cotizacion('cotizacion', 'Cotización');

  final String apiValue;
  final String label;
  const SaleDocumentType(this.apiValue, this.label);

  /// Boleta y factura se envían a SUNAT.
  bool get esFiscal => this == boleta || this == factura;

  bool get esCotizacion => this == cotizacion;
}

/// Cliente al que se le vende.
class ClientEntity {
  final int id;
  final String name;
  final String? documento;

  /// `p` persona, `e` empresa.
  final String? tipo;
  final int? listPriceId;
  final int? paymentMethodId;
  final int? ejecutivoComercialId;
  final String? ejecutivoComercial;

  const ClientEntity({
    required this.id,
    required this.name,
    this.documento,
    this.tipo,
    this.listPriceId,
    this.paymentMethodId,
    this.ejecutivoComercialId,
    this.ejecutivoComercial,
  });

  /// "Cliente varios": ventas sin documento del cliente.
  bool get esVarios => documento == varios;

  bool get esPersona => tipo == 'p';

  static const varios = '00000000';
}

/// Producto tal como lo devuelve la búsqueda para vender: con su stock por
/// almacén y su precio por lista.
class SaleProductEntity {
  final int id;
  final String codigo;
  final String name;
  final String? marca;
  final bool esServicio;
  final bool ventaSinStock;
  final Map<int, double> stockPorAlmacen;
  final Map<int, double> precioPorLista;

  /// Para filtrar el buscador por categoría o marca.
  final int? categoryId;
  final int? brandId;

  /// Unidad de medida del producto ("Kilogramo", "Unidad"...).
  final String? unidad;

  const SaleProductEntity({
    required this.id,
    required this.codigo,
    required this.name,
    this.marca,
    this.categoryId,
    this.brandId,
    this.unidad,
    this.esServicio = false,
    this.ventaSinStock = false,
    this.stockPorAlmacen = const {},
    this.precioPorLista = const {},
  });

  double stockEn(int warehouseId) => stockPorAlmacen[warehouseId] ?? 0;

  /// 0 si el producto no está en esa lista (la web lo deja igual).
  double precioEn(int listPriceId) => precioPorLista[listPriceId] ?? 0;

  /// Cuánto se puede vender en [warehouseId]; `null` si no hay tope.
  double? maximoEn(int warehouseId) =>
      (ventaSinStock || esServicio) ? null : stockEn(warehouseId);
}

/// Categorías y marcas de la empresa para filtrar el buscador de productos.
class SaleProductFiltersEntity {
  final List<({int id, String name})> categorias;
  final List<({int id, String name})> marcas;

  const SaleProductFiltersEntity({this.categorias = const [], this.marcas = const []});

  String? categoriaName(int? id) {
    for (final c in categorias) {
      if (c.id == id) return c.name;
    }
    return null;
  }
}

/// Forma de pago disponible para el usuario.
class PaymentMethodEntity {
  final int id;
  final String name;

  const PaymentMethodEntity({required this.id, required this.name});

  /// El crédito, el plazo y los puntos llevan cuotas o saldos del cliente que
  /// esta versión de la app aún no maneja.
  bool get soportado {
    final n = name.toUpperCase();
    return !(n.contains('CRÉDITO') || n.contains('CREDITO') || n.contains('PLAZO') || n.contains('PUNTOS'));
  }
}

/// Cuándo se entrega lo vendido. `apiValue` es lo que espera el backend (`metodo_entrega`).
enum SaleDelivery {
  inmediata('e', 'Entrega Inmediata'),
  despacho('d', 'Despacho');

  final String apiValue;
  final String label;
  const SaleDelivery(this.apiValue, this.label);

  static SaleDelivery fromApi(String? value) =>
      values.firstWhere((d) => d.apiValue == value, orElse: () => inmediata);
}

/// Una forma de pago de la venta con lo que se cobra por ella.
class SalePaymentEntity {
  final int paymentMethodId;
  final double monto;

  const SalePaymentEntity({required this.paymentMethodId, required this.monto});
}

/// Lo que se llena en el modal "Crear venta": fecha, entrega, pagos y observaciones.
class SaleCheckoutEntity {
  /// `null` = hoy (la web solo manda la fecha cuando se elige otra).
  final DateTime? fechaEmision;
  final SaleDelivery delivery;
  final List<SalePaymentEntity> payments;
  final String observaciones;

  const SaleCheckoutEntity({
    this.fechaEmision,
    this.delivery = SaleDelivery.inmediata,
    required this.payments,
    this.observaciones = '',
  });
}

/// Días en que se puede emitir el comprobante: un ticket, hasta 30 días atrás; una boleta o
/// factura, hoy y los dos días anteriores (igual que la web).
({DateTime first, DateTime last}) saleIssueDateRange(SaleDocumentType tipo, DateTime now) {
  final today = DateTime(now.year, now.month, now.day);
  final back = tipo == SaleDocumentType.ticket ? 30 : 2;
  return (first: today.subtract(Duration(days: back)), last: today);
}

/// Una línea de la venta: producto, cantidad y precio unitario en soles.
class SaleLineEntity {
  final SaleProductEntity product;
  final int cantidad;
  final double precio;

  const SaleLineEntity({
    required this.product,
    required this.cantidad,
    required this.precio,
  });

  double get subtotal => roundMoney(precio * cantidad);

  SaleLineEntity copyWith({int? cantidad, double? precio}) => SaleLineEntity(
        product: product,
        cantidad: cantidad ?? this.cantidad,
        precio: precio ?? this.precio,
      );
}

/// Redondea a 2 decimales (importes que se envían al backend).
double roundMoney(double value) => (value * 100).roundToDouble() / 100;

/// Lo que el usuario llenó para registrar una venta al contado en soles.
class SaleFormEntity {
  final SaleDocumentType tipoDocumento;
  final ClientEntity? client;
  final int? warehouseId;

  /// Cómo se paga la venta (vacío en una cotización).
  final List<SalePaymentEntity> payments;
  final List<SaleLineEntity> lines;
  final String? observaciones;

  final SaleDelivery delivery;

  /// Fecha de emisión elegida; `null` = hoy.
  final DateTime? fechaEmision;

  /// Lista de precios con la que se armó la venta (la cotización la guarda).
  final int? priceListId;

  /// Solo cotizaciones: si reserva el stock y hasta qué día.
  final bool reservarStock;
  final DateTime? vencimientoStock;

  const SaleFormEntity({
    required this.tipoDocumento,
    required this.client,
    required this.warehouseId,
    this.payments = const [],
    required this.lines,
    this.observaciones,
    this.delivery = SaleDelivery.inmediata,
    this.fechaEmision,
    this.priceListId,
    this.reservarStock = false,
    this.vencimientoStock,
  });

  double get total =>
      roundMoney(lines.fold<double>(0, (sum, l) => sum + l.subtotal));
}

/// Tipo de cambio comercial vigente (interbancario + margen de la empresa), el que se
/// aplica en cotizaciones y ventas en dólares.
class ExchangeRateEntity {
  /// Con margen: el valor que se usa.
  final double valorFinal;

  /// Interbancario del que se parte, su fuente (`bloomberg`, `manual`...) y su fecha.
  final double valorFuente;
  final String fuente;
  final DateTime? fechaFuente;
  final double margen;

  const ExchangeRateEntity({
    required this.valorFinal,
    this.valorFuente = 0,
    this.fuente = '',
    this.fechaFuente,
    this.margen = 0,
  });

  String get fuenteNombre {
    if (fuente == 'bloomberg') return 'Bloomberg';
    if (fuente.startsWith('manual')) return 'Manual';
    return fuente;
  }
}

/// Resultado de registrar la venta (o la cotización).
typedef SaleResultEntity = DocumentEntity;
