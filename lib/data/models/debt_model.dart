import '../../domain/entities/debt_entity.dart';

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

DebtClientEntity debtClientFromJson(Map<String, dynamic> j) => DebtClientEntity(
      id: _int(j['id']) ?? 0,
      cliente: _text(j['cliente']) ?? '—',
      deudaSoles: _doubleOrNull(j['deuda_soles']) ?? 0,
      deudaDolares: _doubleOrNull(j['deuda_dolares']) ?? 0,
      lineaUtilizada: _doubleOrNull(j['linea_utilizada']) ?? 0,
      credito: _doubleOrNull(j['credito']) ?? 0,
    );

/// `GET /deudas/clientes/resumen`: `{data, current_page, last_page, total, total_soles,
/// total_dolares}`.
DebtPageEntity debtPageFromJson(Map<String, dynamic> j) {
  final data = j['data'];
  return DebtPageEntity(
    items: data is List
        ? [for (final c in data) if (c is Map) debtClientFromJson(c.cast<String, dynamic>())]
        : const [],
    currentPage: _int(j['current_page']) ?? 1,
    lastPage: _int(j['last_page']) ?? 1,
    total: _int(j['total']) ?? 0,
    totalSoles: _doubleOrNull(j['total_soles']) ?? 0,
    totalDolares: _doubleOrNull(j['total_dolares']) ?? 0,
  );
}

/// Clientes de `GET /clientes/search`: el nombre que ve la web (`display_label`, `display_name`,
/// razón social o nombre y apellido).
List<DebtOption> debtClientOptionsFromJson(dynamic json) {
  if (json is! List) return const [];
  final result = <DebtOption>[];
  for (final e in json) {
    if (e is! Map) continue;
    final id = _int(e['id']);
    final name = _text(e['display_label']) ??
        _text(e['display_name']) ??
        _text(e['razon_social']) ??
        [_text(e['name']), _text(e['last_name'])].whereType<String>().join(' ');
    if (id != null && name.isNotEmpty) result.add(DebtOption(id: id, name: name));
  }
  return result;
}

/// Ejecutivos de `GET /usuarios/list` (`[{id, name, ...}]`).
List<DebtOption> debtSellerOptionsFromJson(dynamic json) {
  if (json is! List) return const [];
  final result = <DebtOption>[];
  for (final e in json) {
    if (e is! Map) continue;
    final id = _int(e['id']);
    final name = _text(e['name']);
    if (id != null && name != null) result.add(DebtOption(id: id, name: name));
  }
  return result;
}
