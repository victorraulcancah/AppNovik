import '../../domain/entities/seller_payment_entity.dart';

double? _doubleOrNull(dynamic v) {
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v.trim());
  return null;
}

int? _int(dynamic v) {
  if (v is int) return v;
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v.trim());
  return null;
}

String? _text(dynamic v) {
  if (v is! String) return null;
  final t = v.trim();
  return t.isEmpty ? null : t;
}

bool _bool(dynamic v) => v == true || v == 1 || v == '1' || v == 'true';

DateTime? _date(dynamic v) => v is String ? DateTime.tryParse(v)?.toLocal() : null;

Map<String, dynamic>? _map(dynamic v) => v is Map ? v.cast<String, dynamic>() : null;

/// El nombre del cliente que ve la tabla de la web: la razón social o, si no tiene, nombre y apellido.
String _clientName(Map<String, dynamic>? client) {
  if (client == null) return '';
  final razon = _text(client['razon_social']);
  if (razon != null) return razon;
  return [_text(client['name']), _text(client['last_name'])].whereType<String>().join(' ');
}

SellerPaymentAllocation sellerPaymentAllocationFromJson(Map<String, dynamic> j) => SellerPaymentAllocation(
      id: _int(j['id']) ?? 0,
      paymentMethodId: _int(j['payment_method_id']) ?? _int(_map(j['payment_method'])?['id']),
      paymentMethodName: _text(_map(j['payment_method'])?['name']),
      monto: _doubleOrNull(j['monto']) ?? 0,
      descripcionAdicional: _text(j['descripcion_adicional']),
      confirmed: _bool(j['estado']),
      paymentTotal: _doubleOrNull(_map(j['payment_seller'])?['monto_total']),
    );

/// Una fila de `GET /pagos-vendedores-new` (un `PaymentSeller` con su cliente, ejecutivo, método de pago y
/// las partes aplicadas a cuotas).
SellerPaymentEntity sellerPaymentFromJson(Map<String, dynamic> j) {
  final parts = j['fee_payments_sellers'] ?? j['feePaymentsSellers'];
  final allocations = parts is List
      ? [for (final p in parts) if (p is Map) sellerPaymentAllocationFromJson(p.cast<String, dynamic>())]
      : <SellerPaymentAllocation>[];
  final method = _map(j['payment_method'] ?? j['paymentMethod']);
  String? descripcion;
  for (final a in allocations) {
    if (a.descripcionAdicional != null) {
      descripcion = a.descripcionAdicional;
      break;
    }
  }
  final client = _map(j['client']);
  return SellerPaymentEntity(
    id: _int(j['id']) ?? 0,
    clientId: _int(j['client_id']) ?? _int(client?['id']),
    cliente: _clientName(client),
    ejecutivo: _text(_map(j['user'])?['name']),
    descripcion: descripcion ?? _text(j['descripcion']),
    creado: _date(j['created_at']),
    montoTotal: _doubleOrNull(j['monto_total']) ?? 0,
    moneda: _text(j['moneda']) == 'dolares' ? 'dolares' : 'soles',
    estado: _int(j['estado']) ?? 2,
    deleted: j['deleted_at'] != null,
    esSaldoAFavor: _bool(j['es_saldo_a_favor']),
    paymentMethodId: _int(j['payment_method_id']) ?? _int(method?['id']),
    paymentMethodName: _text(method?['name']),
    allocations: allocations,
  );
}

/// Opciones `{id, name}` (métodos de pago, ejecutivos de `/usuarios/list`).
List<SellerPaymentOption> sellerPaymentOptionsFromJson(dynamic json) {
  if (json is! List) return const [];
  final result = <SellerPaymentOption>[];
  for (final e in json) {
    if (e is! Map) continue;
    final id = _int(e['id']);
    final name = _text(e['name']);
    if (id != null && name != null) result.add(SellerPaymentOption(id: id, name: name));
  }
  return result;
}

/// `GET /pagos-vendedores-new`: `{data, current_page, last_page, total, total_soles, total_dolares,
/// metodos_disponibles}`.
SellerPaymentPageEntity sellerPaymentPageFromJson(Map<String, dynamic> j) {
  final data = j['data'];
  return SellerPaymentPageEntity(
    items: data is List
        ? [for (final p in data) if (p is Map) sellerPaymentFromJson(p.cast<String, dynamic>())]
        : const [],
    currentPage: _int(j['current_page']) ?? 1,
    lastPage: _int(j['last_page']) ?? 1,
    total: _int(j['total']) ?? 0,
    totalSoles: _doubleOrNull(j['total_soles']) ?? 0,
    totalDolares: _doubleOrNull(j['total_dolares']) ?? 0,
    methods: sellerPaymentOptionsFromJson(j['metodos_disponibles']),
  );
}

/// Clientes de `GET /clientes/list` y `/clientes/search`: el nombre que ve la web (`display_label`,
/// `display_name`, razón social o nombre y apellido).
List<SellerPaymentOption> sellerPaymentClientOptionsFromJson(dynamic json) {
  if (json is! List) return const [];
  final result = <SellerPaymentOption>[];
  for (final e in json) {
    if (e is! Map) continue;
    final id = _int(e['id']);
    final name = _text(e['display_label']) ??
        _text(e['display_name']) ??
        _text(e['razon_social']) ??
        [_text(e['name']), _text(e['last_name'])].whereType<String>().join(' ');
    if (id != null && name.isNotEmpty) result.add(SellerPaymentOption(id: id, name: name));
  }
  return result;
}

/// `GET /clientes/{id}?include_deudas=true`: la deuda calculada por el servidor.
SellerClientDebt sellerClientDebtFromJson(Map<String, dynamic> j) => SellerClientDebt(
      soles: _doubleOrNull(j['deuda_pendiente_soles']) ?? 0,
      dolares: _doubleOrNull(j['deuda_pendiente_dolares']) ?? 0,
    );
