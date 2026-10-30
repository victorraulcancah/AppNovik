import 'dart:typed_data';

/// Qué lista de la pantalla Documentos se está viendo.
enum DocumentKind { venta, cotizacion }

/// Producto o concepto de un documento.
class DocumentItemEntity {
  final String name;
  final String? codigo;
  final String? marca;
  final double cantidad;
  final double precio;

  /// Importe de la línea ya con el descuento.
  final double subtotal;

  /// Descuento de la línea (monto).
  final double descuento;
  final bool dolares;

  const DocumentItemEntity({
    required this.name,
    this.codigo,
    this.marca,
    this.cantidad = 0,
    this.precio = 0,
    this.subtotal = 0,
    this.descuento = 0,
    this.dolares = false,
  });
}

/// Forma de pago de una venta.
class DocumentPaymentEntity {
  final String metodo;
  final double monto;

  const DocumentPaymentEntity({required this.metodo, required this.monto});
}

/// Datos del almacén que salen en el comprobante: según su configuración se usan
/// los del almacén, los del vendedor o los de la empresa.
class DocumentWarehouseEntity {
  final String name;

  /// El comprobante usa la dirección, teléfono, correo y web del almacén.
  final bool usaDatos;

  /// El comprobante usa el teléfono y correo del vendedor.
  final bool usaDatosVendedor;
  final String? direccion;
  final String? telefono;
  final String? email;
  final String? web;
  final String? comentarios;

  const DocumentWarehouseEntity({
    this.name = '-',
    this.usaDatos = false,
    this.usaDatosVendedor = false,
    this.direccion,
    this.telefono,
    this.email,
    this.web,
    this.comentarios,
  });
}

/// Comprobante electrónico (boleta o factura) de una venta.
class DocumentBoletaEntity {
  final int id;

  /// `b` boleta, `f` factura.
  final String tipo;

  /// Ya tiene la constancia de recepción (CDR) de SUNAT.
  final bool tieneCdr;
  final bool tieneGuia;
  final bool tieneNotaCredito;

  const DocumentBoletaEntity({
    required this.id,
    required this.tipo,
    this.tieneCdr = false,
    this.tieneGuia = false,
    this.tieneNotaCredito = false,
  });

  bool get esFactura => tipo == 'f';
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
  final String? clienteDocumento;
  final String? clienteDireccion;

  /// Quien figura como vendedor: el ejecutivo del cliente o, si no tiene, el vendedor elegido o quien registró.
  final String vendedor;
  final String? vendedorTelefono;
  final String? vendedorEmail;
  final String? usuario;
  final String almacen;
  final DocumentWarehouseEntity? datosAlmacen;
  final double monto;
  final bool esDolares;
  final double? tipoCambio;
  final double descuento;
  final DateTime? creado;
  final String? observaciones;
  final String? anuladoPor;
  final DateTime? anuladoAt;

  /// Solo cotizaciones: si reservó stock y hasta cuándo.
  final bool? reservado;
  final DateTime? vencimientoStock;
  final DocumentBoletaEntity? boleta;
  final List<DocumentItemEntity> items;
  final List<DocumentPaymentEntity> pagos;

  const DocumentEntity({
    required this.id,
    required this.kind,
    required this.numero,
    required this.comprobante,
    this.activo = true,
    this.cliente = '-',
    this.clienteDocumento,
    this.clienteDireccion,
    this.vendedor = '-',
    this.vendedorTelefono,
    this.vendedorEmail,
    this.usuario,
    this.almacen = '-',
    this.datosAlmacen,
    this.monto = 0,
    this.esDolares = false,
    this.tipoCambio,
    this.descuento = 0,
    this.creado,
    this.observaciones,
    this.anuladoPor,
    this.anuladoAt,
    this.reservado,
    this.vencimientoStock,
    this.boleta,
    this.items = const [],
    this.pagos = const [],
  });

  String get simboloMoneda => esDolares ? r'$' : 'S/';

  bool get esCotizacion => kind == DocumentKind.cotizacion;

  /// Se puede eliminar desde la lista: una venta con comprobante electrónico solo se anula con nota de crédito.
  bool get sePuedeEliminar => activo && boleta == null;

  /// Se puede emitir una nota de crédito sobre su boleta o factura.
  bool get sePuedeAnularConNotaCredito =>
      activo && kind == DocumentKind.venta && boleta != null && !boleta!.tieneNotaCredito;
}

class DocumentPageEntity {
  final List<DocumentEntity> items;
  final int currentPage;
  final int lastPage;
  final int total;

  /// Suma de todo lo filtrado (no solo la página), cada moneda por separado; las anuladas no cuentan.
  final double totalSoles;
  final double totalDolares;

  const DocumentPageEntity({
    required this.items,
    required this.currentPage,
    required this.lastPage,
    required this.total,
    this.totalSoles = 0,
    this.totalDolares = 0,
  });

  bool get hasMore => currentPage < lastPage;
}

/// Tipo de comprobante por el que se filtran las ventas.
enum DocumentTipo { boleta, factura, notaVenta }

/// Estado por el que se filtran las ventas.
enum DocumentEstado { activos, eliminados }

/// Estado por el que se filtran las cotizaciones: pendientes (sin procesar) o procesadas (pasaron a venta).
enum DocumentQuoteState { todas, pendientes, procesadas }

/// Si la cotización reservó stock.
enum DocumentReserve { todas, reservadas, noReservadas }

/// Filtros avanzados de Documentos (el panel del embudo de la web). Las fechas son días;
/// el servidor los toma como días de Perú. Sin fechas, sin límite.
class DocumentFilters {
  final DateTime? desde;
  final DateTime? hasta;
  final List<int> sucursales;
  final List<int> vendedores;
  final List<int> clientes;

  /// Solo ventas.
  final DocumentTipo? tipo;
  final DocumentEstado? estado;

  /// Solo cotizaciones.
  final DocumentQuoteState estadoCotizacion;
  final DocumentReserve reserva;

  const DocumentFilters({
    this.desde,
    this.hasta,
    this.sucursales = const [],
    this.vendedores = const [],
    this.clientes = const [],
    this.tipo,
    this.estado,
    this.estadoCotizacion = DocumentQuoteState.todas,
    this.reserva = DocumentReserve.todas,
  });

  /// Lo que se ve al entrar: solo los documentos de hoy.
  factory DocumentFilters.hoy(DateTime now) {
    final today = DateTime(now.year, now.month, now.day);
    return DocumentFilters(desde: today, hasta: today);
  }

  static const _keep = Object();

  /// Cambia solo lo indicado. Para poner `null` en un campo opcional, pásalo explícitamente.
  DocumentFilters copyWith({
    Object? desde = _keep,
    Object? hasta = _keep,
    List<int>? sucursales,
    List<int>? vendedores,
    List<int>? clientes,
    Object? tipo = _keep,
    Object? estado = _keep,
    DocumentQuoteState? estadoCotizacion,
    DocumentReserve? reserva,
  }) =>
      DocumentFilters(
        desde: identical(desde, _keep) ? this.desde : desde as DateTime?,
        hasta: identical(hasta, _keep) ? this.hasta : hasta as DateTime?,
        sucursales: sucursales ?? this.sucursales,
        vendedores: vendedores ?? this.vendedores,
        clientes: clientes ?? this.clientes,
        tipo: identical(tipo, _keep) ? this.tipo : tipo as DocumentTipo?,
        estado: identical(estado, _keep) ? this.estado : estado as DocumentEstado?,
        estadoCotizacion: estadoCotizacion ?? this.estadoCotizacion,
        reserva: reserva ?? this.reserva,
      );

  /// Hay algo distinto de "los de hoy", sin otros filtros.
  bool isActive(DateTime now) {
    final base = DocumentFilters.hoy(now);
    return desde != base.desde ||
        hasta != base.hasta ||
        sucursales.isNotEmpty ||
        vendedores.isNotEmpty ||
        clientes.isNotEmpty ||
        tipo != null ||
        estado != null ||
        estadoCotizacion != DocumentQuoteState.todas ||
        reserva != DocumentReserve.todas;
  }
}

/// Opciones de los filtros de sucursal, ejecutivo y cliente.
class DocumentFilterCatalogs {
  final List<({int id, String name})> sucursales;
  final List<({int id, String name})> vendedores;
  final List<({int id, String name})> clientes;

  const DocumentFilterCatalogs({
    this.sucursales = const [],
    this.vendedores = const [],
    this.clientes = const [],
  });
}

/// Archivo descargado del servidor (Excel, CDR).
class DownloadedFile {
  final String name;
  final Uint8List bytes;

  const DownloadedFile({required this.name, required this.bytes});
}
