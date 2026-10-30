import '../../domain/entities/document_entity.dart';

double _double(dynamic v) =>
    v is num ? v.toDouble() : (v is String ? double.tryParse(v) ?? 0 : 0);

int? _int(dynamic v) =>
    v is num ? v.toInt() : (v is String ? int.tryParse(v) : null);

bool _bool(dynamic v, {bool defaultValue = false}) {
  if (v == null) return defaultValue;
  return v == true || v == 1 || v == '1';
}

/// Hay algo en el campo (un texto no vacío, un objeto, un `true`).
bool _present(dynamic v) {
  if (v == null || v == false || v == 0) return false;
  if (v is String) return v.trim().isNotEmpty;
  return true;
}

String? _text(dynamic v) {
  if (v is! String) return null;
  final t = v.trim();
  return t.isEmpty ? null : t;
}

String? _name(dynamic relation) =>
    relation is Map ? relation['name'] as String? : null;

DateTime? _date(dynamic v) =>
    v is String ? DateTime.tryParse(v)?.toLocal() : null;

String _pad(dynamic value, int width) => '${value ?? ''}'.padLeft(width, '0');

/// Número del documento como lo arma la web: con boleta, `B001-00123` (la
/// factura lleva 4 dígitos); sin ella, `V001-0012` (venta) o `C001-0034`.
String documentNumber(Map<String, dynamic> json, DocumentKind kind) {
  final boleta = json['boleta'];
  if (boleta is Map && boleta['tipo'] is String) {
    final tipo = (boleta['tipo'] as String).toLowerCase();
    return '${tipo.toUpperCase()}${_pad(boleta['serie'], 3)}-${_pad(boleta['numero'], tipo == 'f' ? 4 : 5)}';
  }
  final prefix = kind == DocumentKind.cotizacion ? 'C' : 'V';
  return '${prefix}001-${_pad(json['nro_documento'], 4)}';
}

String _comprobante(Map<String, dynamic> json, DocumentKind kind) {
  if (kind == DocumentKind.cotizacion) return 'Cotización';
  final boleta = json['boleta'];
  if (boleta is Map) {
    return boleta['tipo'] == 'f' ? 'Factura' : 'Boleta';
  }
  return 'Nota de venta';
}

/// Cliente: razón social o nombre y apellido.
String _cliente(dynamic client) {
  if (client is! Map) return '-';
  final razon = client['razon_social'];
  if (razon is String && razon.isNotEmpty) return razon;
  final name = '${client['name'] ?? ''} ${client['last_name'] ?? ''}'.trim();
  return name.isEmpty ? '-' : name;
}

/// Dirección que sale en el comprobante: la predeterminada del cliente o la suya.
String? _direccionCliente(dynamic client) {
  if (client is! Map) return null;
  final adresses = client['adresses'];
  if (adresses is List) {
    for (final a in adresses) {
      if (a is Map && _bool(a['predeterminado'])) {
        final d = _text(a['direccion']);
        if (d != null) return d;
      }
    }
  }
  return _text(client['direccion']);
}

DocumentItemEntity _item(Map<String, dynamic> p) {
  final pivot = p['pivot'] is Map ? p['pivot'] as Map : const {};
  final name = (p['name'] as String?) ?? (pivot['concepto_libre'] as String?) ?? '-';
  return DocumentItemEntity(
    name: name,
    codigo: p['codigo'] as String?,
    marca: _name(p['brand']),
    cantidad: _double(pivot['cantidad']),
    precio: _double(pivot['precio']),
    subtotal: _double(pivot['subtotal_con_dto'] ?? pivot['subtotal']),
    descuento: _double(pivot['monto_dto']),
    dolares: _bool(pivot['dolares']),
  );
}

DocumentWarehouseEntity? _warehouse(dynamic w) {
  if (w is! Map) return null;
  return DocumentWarehouseEntity(
    name: (w['name'] as String?) ?? '-',
    usaDatos: _bool(w['datos']),
    usaDatosVendedor: _bool(w['datos_vendedor']),
    direccion: _text(w['direccion']),
    telefono: _text(w['telefono']),
    email: _text(w['email']),
    web: _text(w['web']),
    comentarios: _text(w['comentarios']),
  );
}

DocumentBoletaEntity? _boleta(dynamic b) {
  if (b is! Map) return null;
  final id = _int(b['id']);
  final tipo = b['tipo'];
  if (id == null || tipo is! String) return null;
  return DocumentBoletaEntity(
    id: id,
    tipo: tipo.toLowerCase(),
    tieneCdr: _present(b['cdr']),
    tieneGuia: _present(b['guia']),
    tieneNotaCredito: _present(b['nota_credito']),
  );
}

DocumentEntity documentFromJson(Map<String, dynamic> json, DocumentKind kind) {
  final dolares = _double(json['total_dolares']);
  final esDolares = dolares > 0;

  final ejecutivo = json['ejecutivo_de_la_venta'];
  final seller = ejecutivo is Map
      ? ejecutivo
      : (json['vendedor'] is Map ? json['vendedor'] : json['user']);
  final products = json['products'];
  final payments = json['payment_methods'];
  final isQuote = kind == DocumentKind.cotizacion;
  final items = products is List
      ? products.whereType<Map<String, dynamic>>().map(_item).toList()
      : <DocumentItemEntity>[];

  return DocumentEntity(
    id: _int(json['id']) ?? 0,
    kind: kind,
    numero: documentNumber(json, kind),
    comprobante: _comprobante(json, kind),
    activo: _bool(json['estado'], defaultValue: true),
    cliente: _cliente(json['client']),
    clienteDocumento: json['client'] is Map ? _text((json['client'] as Map)['dni_ruc']) : null,
    clienteDireccion: _direccionCliente(json['client']),
    // El vendedor que figura es el ejecutivo del cliente; si no tiene, el elegido o quien registró.
    vendedor: _name(ejecutivo) ?? _name(json['vendedor']) ?? _name(json['user']) ?? '-',
    vendedorTelefono: seller is Map ? _text(seller['telefono']) : null,
    vendedorEmail: seller is Map ? _text(seller['email']) : null,
    usuario: _name(json['user']),
    almacen: _name(json['warehouse']) ?? '-',
    datosAlmacen: _warehouse(json['warehouse']),
    monto: esDolares ? dolares : _double(json['total_soles']),
    esDolares: esDolares,
    tipoCambio: esDolares ? _double(json['tipo_de_cambio']) : null,
    descuento: items.fold<double>(0, (sum, i) => sum + i.descuento),
    // En cotizaciones la fecha que se muestra es la de emisión.
    creado: _date(isQuote ? (json['fecha_emision'] ?? json['created_at']) : json['created_at']),
    observaciones: json['observaciones'] as String?,
    anuladoPor: _name(json['anulado_por']),
    anuladoAt: _date(json['anulado_at']),
    reservado: isQuote ? _bool(json['reservar_stock']) : null,
    vencimientoStock: isQuote ? _date(json['vencimiento_stock']) : null,
    boleta: isQuote ? null : _boleta(json['boleta']),
    items: items,
    pagos: payments is List
        ? [
            for (final m in payments.whereType<Map>())
              DocumentPaymentEntity(
                metodo: (m['name'] as String?) ?? '-',
                monto: _double((m['pivot'] is Map ? m['pivot'] as Map : const {})['monto']),
              ),
          ]
        : const [],
  );
}

class DocumentPageModel extends DocumentPageEntity {
  const DocumentPageModel({
    required super.items,
    required super.currentPage,
    required super.lastPage,
    required super.total,
    super.totalSoles,
    super.totalDolares,
  });

  factory DocumentPageModel.fromJson(Map<String, dynamic> json, DocumentKind kind) {
    final data = json['data'];
    return DocumentPageModel(
      items: data is List
          ? data
              .whereType<Map<String, dynamic>>()
              .map((e) => documentFromJson(e, kind))
              .toList()
          : const [],
      currentPage: _int(json['current_page']) ?? 1,
      lastPage: _int(json['last_page']) ?? 1,
      total: _int(json['total']) ?? 0,
      totalSoles: _double(json['total_soles']),
      totalDolares: _double(json['total_dolares']),
    );
  }
}

/// Opciones de un filtro: `[{id, name}]` (sucursales, usuarios) o clientes con `display_label`.
List<({int id, String name})> filterOptionsFromJson(dynamic json) {
  final list = json is List ? json : (json is Map && json['data'] is List ? json['data'] as List : const []);
  final result = <({int id, String name})>[];
  for (final e in list) {
    if (e is! Map) continue;
    final id = _int(e['id']);
    if (id == null) continue;
    final name = _text(e['display_label']) ??
        _text(e['display_name']) ??
        _text(e['name']) ??
        '${e['first_name'] ?? ''} ${e['last_name'] ?? ''}'.trim();
    result.add((id: id, name: name.isEmpty ? '#$id' : name));
  }
  return result;
}
