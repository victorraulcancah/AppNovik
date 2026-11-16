import '../../domain/entities/account_statement_entity.dart';
import '../../domain/entities/document_entity.dart';
import 'document_model.dart' show documentFromJson;

double _double(dynamic v) => v is num ? v.toDouble() : (v is String ? double.tryParse(v) ?? 0 : 0);

int? _int(dynamic v) => v is num ? v.toInt() : (v is String ? int.tryParse(v) : null);

bool _bool(dynamic v) => v == true || v == 1 || v == '1';

String? _text(dynamic v) {
  if (v is! String) return null;
  final t = v.trim();
  return t.isEmpty ? null : t;
}

DateTime? _date(dynamic v) => v is String ? DateTime.tryParse(v)?.toLocal() : null;

Map<String, dynamic>? _map(dynamic v) => v is Map ? Map<String, dynamic>.from(v) : null;

String _pad(dynamic value, int width) => '${value ?? ''}'.padLeft(width, '0');

/// Las cifras de menos de medio centavo se muestran como cero (como la web).
double _clean(double v) => v.abs() < 0.005 ? 0 : v;

/// Número del documento tal como lo arma la web en el estado de cuenta: con boleta, `B001-0123`
/// (tipo en mayúscula, serie de 3 y número de 4 dígitos); sin ella, `V001-0045` (o `C001-…` si es
/// una cotización).
String statementDocumentNumber(Map<String, dynamic>? sale, {Map<String, dynamic>? boleta, bool agrupado = false}) {
  final b = boleta ?? _map(sale?['boleta']);
  if (b != null) {
    final tipo = (_text(b['tipo']) ?? 'BOL').toUpperCase();
    final serie = b['serie'] == null ? '001' : '${b['serie']}';
    final numero = b['numero'] == null ? '0' : '${b['numero']}';
    return '$tipo${serie.padLeft(3, '0')}-${numero.padLeft(4, '0')}';
  }
  final cotizacion = !agrupado && sale != null && sale.containsKey('reservar_stock');
  return '${cotizacion ? 'C' : 'V'}001-${_pad(sale?['nro_documento'], 4)}';
}

String? _methodName(dynamic method) => method is Map ? _text(method['name']) : null;

/// `código · marca` del producto (la web lo muestra como `código | nombre | marca`).
String? _productDetail(Map<String, dynamic> product) {
  final codigo = _text(product['codigo']);
  final marca = _text(_map(product['brand'])?['name']) ?? '-';
  return [?codigo, marca].join(' · ');
}

/// El comprobante de la venta de esta fila, para abrirlo al tocar el documento. Sin venta real
/// (un pago de vendedor agrupado) o si no se puede leer, `null`.
DocumentEntity? _document(Map<String, dynamic>? source) {
  if (source == null) return null;
  final id = _int(source['id']);
  if (id == null || id <= 0) return null;
  try {
    return documentFromJson(source, DocumentKind.venta);
  } catch (_) {
    return null;
  }
}

/// La cabecera de `GET /ventas/estado-de-cuenta`: usa los totales que ya calcula el servidor.
StatementSummaryEntity statementSummaryFromJson(Map<String, dynamic> json) {
  final client = _map(json['client']);
  final credito = _double(client?['credito']);
  final disponible = _double(client?['credito_disponible']);
  final utilizada = client?['linea_utilizada'] == null
      ? (credito - disponible < 0 ? 0.0 : credito - disponible)
      : _double(client!['linea_utilizada']);
  return StatementSummaryEntity(
    credito: credito,
    creditoDisponible: disponible,
    lineaUtilizada: utilizada,
    deudaTotalSoles: _clean(_double(json['deudaTotalSoles'])),
    deudaTotalDolares: _clean(_double(json['deudaTotalDolares'])),
    deudaAnteriorSoles: _clean(_double(json['deuda_anterior_soles'])),
    deudaAnteriorDolares: _clean(_double(json['deuda_anterior_dolares'])),
  );
}

/// Una fila de la pestaña principal. Sigue las columnas de la web (detalle por producto o
/// agrupado por venta).
StatementRowEntity statementRowFromJson(Map<String, dynamic> json, {required bool agrupado}) {
  final id = '${json['id'] ?? ''}';
  final sale = _map(json['sale']);
  final isAggregated = json['type'] == 'payment_seller_aggregated';
  final isSaleRow = id.startsWith('s-');
  final method = _methodName(json['payment_method']) ?? _methodName(json['paymentMethod']);
  // Un pago: en la vista agrupada, toda fila que no sea una venta; en la de detalle, la que trae método de pago.
  final esPago = agrupado ? !isSaleRow : (isAggregated || json['payment_method'] != null);

  final saleDollars = _double(sale?['total_dolares']) > 0;
  final monto = _double(json['monto']);
  final moneda = json['moneda'];

  double soles;
  double dolares;
  if (isAggregated) {
    final total = _double(json['total_sumado']);
    soles = moneda != 'dolares' ? total : 0;
    dolares = moneda == 'dolares' ? total : 0;
  } else if (agrupado && isSaleRow) {
    soles = _double(json['total_soles']);
    dolares = _double(json['total_dolares']);
  } else if (esPago) {
    soles = saleDollars ? 0 : monto;
    dolares = saleDollars ? monto : 0;
  } else {
    final enDolares = _bool(json['dolares']);
    final subtotal = _double(json['subtotal_con_dto']);
    soles = enDolares ? 0 : subtotal;
    dolares = enDolares ? subtotal : 0;
  }

  String titulo;
  String? detalle;
  final product = _map(json['product']);
  if (agrupado) {
    if (isSaleRow) {
      titulo = 'Venta ${json['nro_documento'] ?? id.replaceFirst('s-', '')}';
    } else if (isAggregated || id.startsWith('f') || id.startsWith('o-') || id.startsWith('ps-')) {
      titulo = 'Pagó con ${method ?? '-'}';
    } else {
      final methods = json['payment_methods'];
      final names = methods is List
          ? {for (final m in methods) if (_methodName(m) != null) _methodName(m)!}.join(', ')
          : '';
      titulo = 'Pagó con ${names.isEmpty ? '-' : names}';
    }
  } else if (product != null) {
    titulo = _text(product['name']) ?? '-';
    detalle = _productDetail(product);
  } else {
    titulo = 'Pagó con ${method ?? 'N/A'}';
  }

  final boleta = isAggregated ? null : _map(json['boleta']) ?? _map(sale?['boleta']);
  final documento = isAggregated
      ? '-'
      : agrupado && isSaleRow
          ? statementDocumentNumber(json, boleta: _map(json['boleta']), agrupado: true)
          : statementDocumentNumber(sale ?? json, boleta: boleta, agrupado: agrupado);

  // La fila de venta agrupada es la propia venta (`id` = `s-12`): se le pone su número de verdad.
  final receiptSource = isAggregated
      ? null
      : agrupado && isSaleRow
          ? {...json, 'id': int.tryParse(id.replaceFirst('s-', ''))}
          : sale;

  return StatementRowEntity(
    id: id,
    fecha: _date(json['created_at']),
    documento: documento,
    cantidad: json['cantidad'] == null ? null : _double(json['cantidad']),
    titulo: titulo,
    detalle: detalle,
    soles: soles,
    dolares: dolares,
    registradoPor: _text(json['registrado_por']),
    origen: _text(json['origen']),
    esPago: esPago,
    anulado: agrupado ? json['estado'] == false : sale?['estado'] == false,
    document: _document(receiptSource),
  );
}

/// `GET /ventas/estado-de-cuenta`: filas + cabecera + total para paginar.
StatementPageEntity statementPageFromJson(Map<String, dynamic> json, {required bool agrupado}) {
  final data = json['data'];
  final rows = data is List
      ? [for (final r in data.whereType<Map>()) statementRowFromJson(Map<String, dynamic>.from(r), agrupado: agrupado)]
      : <StatementRowEntity>[];
  return StatementPageEntity(
    rows: rows,
    total: _int(json['total']) ?? rows.length,
    summary: statementSummaryFromJson(json),
  );
}

/// `GET /ventas/estado-de-cuenta/pedidos`: un producto vendido por fila (paginación de Laravel).
StatementPageEntity statementOrdersFromJson(Map<String, dynamic> json) {
  final data = json['data'];
  final rows = <StatementRowEntity>[];
  if (data is List) {
    for (final raw in data.whereType<Map>()) {
      final r = Map<String, dynamic>.from(raw);
      final sale = _map(r['sale']);
      final product = _map(r['product']);
      final enDolares = _bool(r['dolares']);
      final subtotal = _double(r['subtotal_con_dto']);
      rows.add(
        StatementRowEntity(
          id: 'p-${r['id']}',
          fecha: _date(sale?['created_at']),
          documento: statementDocumentNumber(sale),
          cantidad: _double(r['cantidad']),
          titulo: _text(product?['name']) ?? '-',
          detalle: product == null ? null : _productDetail(product),
          soles: enDolares ? 0 : subtotal,
          dolares: enDolares ? subtotal : 0,
          anulado: !_bool(sale?['estado']),
        ),
      );
    }
  }
  return StatementPageEntity(rows: rows, total: _int(json['total']) ?? rows.length);
}

/// `GET /ventas/estado-de-cuenta/pagos`: pagos de cuotas, cobros en la venta y pagos de vendedor.
StatementPageEntity statementPaymentsFromJson(Map<String, dynamic> json) {
  final data = json['data'];
  final rows = <StatementRowEntity>[];
  if (data is List) {
    for (final raw in data.whereType<Map>()) {
      final r = Map<String, dynamic>.from(raw);
      final id = '${r['id'] ?? ''}';
      final sale = _map(r['sale']);
      final method = _methodName(r['payment_method']) ?? _methodName(r['paymentMethod']);
      final monto = _double(r['monto']);
      // Un pago agrupado de vendedor trae su propia moneda; el resto, la de la venta.
      final enDolares = r['moneda'] != null ? r['moneda'] == 'dolares' : _double(sale?['total_dolares']) > 0;
      final agrupado = id.startsWith('ps-');
      rows.add(
        StatementRowEntity(
          id: id,
          fecha: _date(r['created_at']),
          documento: agrupado ? '-' : statementDocumentNumber(sale),
          titulo: method ?? '-',
          soles: enDolares ? 0 : monto,
          dolares: enDolares ? monto : 0,
          registradoPor: _text(r['registrado_por']),
          origen: _text(r['origen']),
          esPago: true,
          anulado: sale != null && !_bool(sale['estado']),
        ),
      );
    }
  }
  return StatementPageEntity(rows: rows, total: _int(json['total']) ?? rows.length);
}
