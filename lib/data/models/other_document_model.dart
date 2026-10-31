import '../../domain/entities/document_entity.dart';
import '../../domain/entities/other_document_entity.dart';
import 'document_model.dart';

double _double(dynamic v) =>
    v is num ? v.toDouble() : (v is String ? double.tryParse(v) ?? 0 : 0);

int? _int(dynamic v) => v is num ? v.toInt() : (v is String ? int.tryParse(v) : null);

bool _bool(dynamic v, {bool defaultValue = false}) =>
    v == null ? defaultValue : (v == true || v == 1 || v == '1');

String? _text(dynamic v) {
  if (v is! String) return null;
  final t = v.trim();
  return t.isEmpty ? null : t;
}

String? _name(dynamic relation) => relation is Map ? _text(relation['name']) : null;

DateTime? _date(dynamic v) =>
    v is String ? DateTime.tryParse(v)?.toLocal() : null;

String _pad(dynamic v, int width) => '${_int(v) ?? 0}'.padLeft(width, '0');

/// `T001-0001`: traslado de stock.
String transferNumber(Map<String, dynamic> json) => 'T001-${_pad(json['nro_documento'], 4)}';

/// `S001-0001`: entrada de stock.
String stockEntryNumber(Map<String, dynamic> json) => 'S001-${_pad(json['nro_documento'], 4)}';

/// `TG01-0001`: guía de remisión (sin serie, `TGV1-0001`, como la web).
String guideNumber(Map<String, dynamic> json) {
  final serie = _int(json['serie']);
  final prefix = serie != null && serie != 0 ? _pad(serie, 2) : 'V1';
  return 'TG$prefix-${_pad(json['numero'], 4)}';
}

/// `BC01-0001` o `FC01-0001`: nota de crédito de una boleta o una factura.
String creditNoteNumber(Map<String, dynamic> json) {
  final boleta = json['boleta'];
  final tipo = boleta is Map && boleta['tipo'] == 'f' ? 'F' : 'B';
  return '${tipo}C${_pad(json['serie'], 2)}-${_pad(json['numero'], 4)}';
}

/// `B001-0001` / `F001-0001`: el comprobante electrónico de una guía o una nota de crédito.
String _boletaNumber(Map boleta) =>
    '${('${boleta['tipo'] ?? 'b'}').toUpperCase()}${_pad(boleta['serie'], 3)}-${_pad(boleta['numero'], 4)}';

/// La venta de una guía o nota de crédito como documento, con su boleta (si tiene), para abrir
/// su comprobante en PDF. La API anida la venta dentro de la boleta.
DocumentEntity? _comprobante(Map? boleta, Map? sale) {
  Map<String, dynamic>? venta;
  if (boleta != null && boleta['sale'] is Map) {
    final b = Map<String, dynamic>.from(boleta)..remove('sale');
    venta = {...Map<String, dynamic>.from(boleta['sale'] as Map), 'boleta': b};
  } else if (sale != null) {
    venta = Map<String, dynamic>.from(sale);
  }
  return venta == null ? null : documentFromJson(venta, DocumentKind.venta);
}

/// Costo promedio de un producto en el almacén [warehouseId] (lo que la web llama "Valor U." en
/// el documento del traslado).
double _costoPromedio(Map product, int? warehouseId) {
  final warehouses = product['warehouses'];
  if (warehouses is! List || warehouseId == null) return 0;
  for (final w in warehouses.whereType<Map>()) {
    if (_int(w['id']) == warehouseId && w['pivot'] is Map) {
      return _double((w['pivot'] as Map)['costo_promedio']);
    }
  }
  return 0;
}

List<OtherDocumentLine> _lines(dynamic products, {required bool traslado, int? fromId}) {
  if (products is! List) return const [];
  return [
    for (final p in products.whereType<Map>())
      OtherDocumentLine(
        cantidad: _double(
          (p['pivot'] is Map)
              ? (traslado ? (p['pivot'] as Map)['cantidad'] : (p['pivot'] as Map)['stock'])
              : 0,
        ),
        codigo: _text(p['codigo']),
        name: _text(p['name']) ?? '-',
        marca: _name(p['brand']),
        costo: traslado
            ? _costoPromedio(p, fromId)
            : (p['pivot'] is Map ? _double((p['pivot'] as Map)['costo']) : 0),
        aceptado: p['pivot'] is Map && _bool((p['pivot'] as Map)['aceptado']),
      ),
  ];
}

String? _ubigeo(dynamic u) {
  if (u is! Map) return null;
  final parts = [_name(u), _name(u['province']), _name(u['department'])].whereType<String>();
  return parts.isEmpty ? null : parts.join(', ');
}

OtherDocumentEntity otherDocumentFromJson(Map<String, dynamic> json, OtherDocumentKind kind) {
  switch (kind) {
    case OtherDocumentKind.traslado:
      return OtherDocumentEntity(
        kind: kind,
        id: _int(json['id']) ?? 0,
        numero: transferNumber(json),
        creado: _date(json['created_at']),
        activo: _bool(json['estado'], defaultValue: true),
        usuario: _name(json['user']),
        desde: _name(json['from_warehouse']) ?? _name(json['fromWarehouse']),
        hacia: _name(json['to_warehouse']) ?? _name(json['toWarehouse']),
        lines: _lines(json['products'], traslado: true, fromId: _int(json['from'])),
      );
    case OtherDocumentKind.entradaStock:
      return OtherDocumentEntity(
        kind: kind,
        id: _int(json['id']) ?? 0,
        numero: stockEntryNumber(json),
        creado: _date(json['created_at']),
        usuario: _name(json['user']),
        almacen: _name(json['warehouse']),
        lines: _lines(json['products'], traslado: false),
      );
    case OtherDocumentKind.guia:
      final boleta = json['boleta'] is Map ? json['boleta'] as Map : null;
      final sale = json['sale'] is Map ? json['sale'] as Map : null;
      return OtherDocumentEntity(
        kind: kind,
        id: _int(json['id']) ?? 0,
        numero: guideNumber(json),
        creado: _date(json['created_at']),
        comprobanteNumero: boleta != null
            ? _boletaNumber(boleta)
            : (sale != null ? 'V001-${_pad(sale['nro_documento'], 4)}' : null),
        comprobante: _comprobante(boleta, sale),
        guia: GuideInfo(
          pesoTotal: _double(json['peso_total']),
          direccionSalida: _text(json['direccion_salida']),
          direccionLlegada: _text(json['direccion_llegada']),
          ubigeoSalida: _ubigeo(json['ubigeo_salida']),
          ubigeoLlegada: _ubigeo(json['ubigeo_llegada']),
          fechaEmision: _date(json['fecha_emision']),
          fechaTraslado: _date(json['fecha_traslado']),
          tipoGuia: _text(json['tipo_guia']),
          documentoTransportista: _text(json['doc_transportista']),
          transportista: _text(json['rzn_social_transportista']),
          matricula: _text(json['matricula_transportista']),
          dniChofer: _text(json['dni_chofer']),
          placaChofer: _text(json['placa_chofer']),
          observaciones: _text(json['observaciones']),
        ),
      );
    case OtherDocumentKind.notaCredito:
      final boleta = json['boleta'] is Map ? json['boleta'] as Map : null;
      return OtherDocumentEntity(
        kind: kind,
        id: _int(json['id']) ?? 0,
        numero: creditNoteNumber(json),
        creado: _date(json['created_at']),
        comprobanteNumero: boleta != null ? _boletaNumber(boleta) : null,
        comprobante: _comprobante(boleta, null),
        nota: CreditNoteInfo(
          fechaEmision: _date(json['fecha_emision']),
          descripcion: _text(json['descripcion']),
        ),
      );
  }
}

OtherDocumentPageEntity otherDocumentPageFromJson(
  Map<String, dynamic> json,
  OtherDocumentKind kind,
) {
  final data = json['data'];
  return OtherDocumentPageEntity(
    items: data is List
        ? [for (final e in data.whereType<Map<String, dynamic>>()) otherDocumentFromJson(e, kind)]
        : const [],
    currentPage: _int(json['current_page']) ?? 1,
    lastPage: _int(json['last_page']) ?? 1,
    total: _int(json['total']) ?? 0,
  );
}
