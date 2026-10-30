import 'document_entity.dart';

/// Tipo de comprobante de una venta. `apiValue` es el texto que espera el backend.
enum SaleDocumentType {
  ticket('Ticket de Venta', 'Nota de venta'),
  boleta('Boleta de Venta', 'Boleta'),
  factura('Factura', 'Factura');

  final String apiValue;
  final String label;
  const SaleDocumentType(this.apiValue, this.label);

  /// Boleta y factura se envían a SUNAT.
  bool get esFiscal => this != ticket;
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

  /// Los pagos a plazo, con puntos o contraentrega llevan cuotas o saldos que
  /// esta versión de la app aún no maneja.
  bool get alContado {
    final n = name.toUpperCase();
    return !(n.contains('CRÉDITO') ||
        n.contains('CREDITO') ||
        n.contains('PLAZO') ||
        n.contains('PUNTOS') ||
        n.contains('CONTRAENTREGA'));
  }
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
  final int? paymentMethodId;
  final List<SaleLineEntity> lines;
  final String? observaciones;

  const SaleFormEntity({
    required this.tipoDocumento,
    required this.client,
    required this.warehouseId,
    required this.paymentMethodId,
    required this.lines,
    this.observaciones,
  });

  double get total =>
      roundMoney(lines.fold<double>(0, (sum, l) => sum + l.subtotal));
}

/// Resultado de registrar la venta.
typedef SaleResultEntity = DocumentEntity;
