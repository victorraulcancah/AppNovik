import '../../domain/entities/document_entity.dart';

double _double(dynamic v) =>
    v is num ? v.toDouble() : (v is String ? double.tryParse(v) ?? 0 : 0);

int? _int(dynamic v) =>
    v is num ? v.toInt() : (v is String ? int.tryParse(v) : null);

bool _bool(dynamic v, {bool defaultValue = false}) {
  if (v == null) return defaultValue;
  return v == true || v == 1 || v == '1';
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
    dolares: _bool(pivot['dolares']),
  );
}

DocumentEntity documentFromJson(Map<String, dynamic> json, DocumentKind kind) {
  final dolares = _double(json['total_dolares']);
  final esDolares = dolares > 0;

  final ejecutivo = _name(json['ejecutivo_de_la_venta']);
  final products = json['products'];
  final payments = json['payment_methods'];
  final isQuote = kind == DocumentKind.cotizacion;

  return DocumentEntity(
    id: _int(json['id']) ?? 0,
    kind: kind,
    numero: documentNumber(json, kind),
    comprobante: _comprobante(json, kind),
    activo: _bool(json['estado'], defaultValue: true),
    cliente: _cliente(json['client']),
    // El vendedor que figura es el ejecutivo del cliente; si no tiene, el elegido o quien registró.
    vendedor: ejecutivo ?? _name(json['vendedor']) ?? _name(json['user']) ?? '-',
    usuario: _name(json['user']),
    almacen: _name(json['warehouse']) ?? '-',
    monto: esDolares ? dolares : _double(json['total_soles']),
    esDolares: esDolares,
    // En cotizaciones la fecha que se muestra es la de emisión.
    creado: _date(isQuote ? (json['fecha_emision'] ?? json['created_at']) : json['created_at']),
    observaciones: json['observaciones'] as String?,
    anuladoPor: _name(json['anulado_por']),
    anuladoAt: _date(json['anulado_at']),
    reservado: isQuote ? _bool(json['reservar_stock']) : null,
    items: products is List
        ? products.whereType<Map<String, dynamic>>().map(_item).toList()
        : const [],
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
    );
  }
}
