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

  /// Línea de crédito y lo que le queda disponible (siempre en soles), y los puntos a favor.
  final double credito;
  final double creditoDisponible;
  final double creditoAFavor;

  const ClientEntity({
    required this.id,
    required this.name,
    this.documento,
    this.tipo,
    this.listPriceId,
    this.paymentMethodId,
    this.ejecutivoComercialId,
    this.ejecutivoComercial,
    this.credito = 0,
    this.creditoDisponible = 0,
    this.creditoAFavor = 0,
  });

  /// Puede comprar a crédito o a plazo.
  bool get tieneCredito => credito > 0 || creditoDisponible > 0;

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

  SaleProductEntity copyWith({Map<int, double>? stockPorAlmacen}) => SaleProductEntity(
        id: id,
        codigo: codigo,
        name: name,
        marca: marca,
        categoryId: categoryId,
        brandId: brandId,
        unidad: unidad,
        esServicio: esServicio,
        ventaSinStock: ventaSinStock,
        stockPorAlmacen: stockPorAlmacen ?? this.stockPorAlmacen,
        precioPorLista: precioPorLista,
      );
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

  String get _n => name.toUpperCase();

  /// Crédito del cliente (en cuotas).
  bool get esCredito => _n == 'CRÉDITO' || _n == 'CREDITO';

  /// Pago a plazo: igual que el crédito, pero el plazo por defecto es diario.
  bool get esPlazo => _n.contains('PLAZO');

  /// Canje de los puntos a favor del cliente.
  bool get esPuntos => _n == 'PUNTOS';

  /// Se paga más adelante, con cuotas: crédito o plazo.
  bool get conCuotas => esCredito || esPlazo;

  PaymentKind get kind => esPuntos
      ? PaymentKind.puntos
      : esPlazo
          ? PaymentKind.plazo
          : esCredito
              ? PaymentKind.credito
              : PaymentKind.normal;
}

/// Cómo se paga una parte de la venta, para las reglas que cambian según la forma de pago.
enum PaymentKind { normal, credito, plazo, puntos }

/// Cada cuánto vencen las cuotas de un crédito.
enum SalePlazo {
  day('day', 'Diario'),
  week('week', 'Semanal'),
  month('month', 'Mensual'),
  year('year', 'Anual');

  final String apiValue;
  final String label;
  const SalePlazo(this.apiValue, this.label);

  /// Fecha de vencimiento [n] periodos después de [from].
  DateTime after(DateTime from, int n) => switch (this) {
        SalePlazo.day => DateTime(from.year, from.month, from.day + n),
        SalePlazo.week => DateTime(from.year, from.month, from.day + 7 * n),
        SalePlazo.month => _addMonths(from, n),
        SalePlazo.year => _addMonths(from, 12 * n),
      };

  static DateTime _addMonths(DateTime d, int months) {
    final target = DateTime(d.year, d.month + months);
    final lastDay = DateTime(target.year, target.month + 1, 0).day;
    return DateTime(target.year, target.month, d.day > lastDay ? lastDay : d.day);
  }
}

/// Una cuota de un crédito: cuánto se paga y cuándo vence.
class SaleInstallmentEntity {
  final double monto;
  final DateTime fechaVencimiento;

  const SaleInstallmentEntity({required this.monto, required this.fechaVencimiento});
}

/// Reparte [total] en [cantidad] cuotas iguales al céntimo: lo que sobra va de a un céntimo a las
/// primeras (igual que `calcularCuotas` de la web).
List<double> splitInstallments(double total, int cantidad) {
  if (cantidad <= 0) return const [];
  final division = (total / cantidad * 100).floor() / 100;
  final rest = ((total - cantidad * division) * 100).round();
  return [for (var i = 0; i < cantidad; i++) roundMoney(division + (i < rest ? 0.01 : 0))];
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
  final PaymentKind kind;

  /// Cuotas (solo crédito o plazo) y cada cuánto vencen.
  final List<SaleInstallmentEntity> installments;
  final SalePlazo? plazo;

  const SalePaymentEntity({
    required this.paymentMethodId,
    required this.monto,
    this.kind = PaymentKind.normal,
    this.installments = const [],
    this.plazo,
  });

  bool get conCuotas => kind == PaymentKind.credito || kind == PaymentKind.plazo;
}

/// Lo que se llena en el modal "Crear venta": fecha, entrega, pagos y observaciones.
class SaleCheckoutEntity {
  /// `null` = hoy (la web solo manda la fecha cuando se elige otra).
  final DateTime? fechaEmision;
  final SaleDelivery delivery;
  final List<SalePaymentEntity> payments;
  final String observaciones;

  /// Venta en dólares: el tipo de cambio negociado (el oficial por defecto, editable).
  final double? tipoCambio;

  const SaleCheckoutEntity({
    this.fechaEmision,
    this.delivery = SaleDelivery.inmediata,
    required this.payments,
    this.observaciones = '',
    this.tipoCambio,
  });
}

/// Rango permitido del tipo de cambio de una venta en dólares (el backend lo exige).
const saleExchangeRateMin = 3.0;
const saleExchangeRateMax = 4.3;

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

  /// Venta en dólares (la lista de precios es en dólares) y el tipo de cambio de la venta.
  final bool dolares;
  final double? tipoCambio;

  /// Se culmina o edita esta cotización: la venta la marca como procesada; una cotización se
  /// actualiza en vez de crear otra.
  final int? fromQuoteId;

  /// Mínimo de puntos que se pueden canjear (según la empresa).
  final double minimoCanjePuntos;

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
    this.dolares = false,
    this.tipoCambio,
    this.fromQuoteId,
    this.minimoCanjePuntos = 0,
  });

  double get total =>
      roundMoney(lines.fold<double>(0, (sum, l) => sum + l.subtotal));

  /// Lo que vale la venta en soles (con el tipo de cambio si es en dólares).
  double get totalEnSoles => dolares ? roundMoney(total * (tipoCambio ?? 1)) : total;
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
