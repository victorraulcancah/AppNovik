import 'package:intl/intl.dart';

/// Cantidad sin decimales si es entera ("24") o con dos ("24.50").
String formatQuantity(double value) =>
    value == value.roundToDouble() ? value.toInt().toString() : value.toStringAsFixed(2);

/// Monto con miles y dos decimales: `S/ 1,234.50`.
String formatMoney(double value, {String symbol = 'S/'}) =>
    '$symbol ${NumberFormat('#,##0.00', 'en_US').format(value)}';

/// Monto corto para ejes de gráficos: `S/ 1.5M`, `S/ 500K`, `S/ 80`.
String formatCompactMoney(double value, {String symbol = 'S/'}) {
  if (value >= 1000000) return '$symbol ${(value / 1000000).toStringAsFixed(1)}M';
  if (value >= 1000) return '$symbol ${(value / 1000).round()}K';
  return '$symbol ${value.round()}';
}

/// Nombre de un cliente (persona o empresa) recortado para tablas angostas: sin el artículo del inicio, sin
/// la forma legal del final y con la última palabra solo en inicial. `Yoselin Rosa Miranda` → `Yoselin Rosa M.`,
/// `La Casa del Auto` → `Casa del A.`, `AUTO MARKET PERU E.I.R.L.` → `AUTO MARKET P.`. Una sola palabra queda igual.
String shortClientName(String? fullName) {
  final parts = (fullName ?? '').trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
  if (parts.length > 1 && const {'la', 'el', 'los', 'las'}.contains(parts.first.toLowerCase())) parts.removeAt(0);
  // La forma legal (S.A.C., EIRL, SRL...) no dice quién es el cliente.
  final legal = RegExp(r'^(s\.?a\.?c?\.?|e\.?i\.?r\.?l\.?|s\.?r\.?l\.?|s\.?a\.?s\.?|e\.?i\.?r\.?l?|ltda\.?)$', caseSensitive: false);
  while (parts.length > 2 && legal.hasMatch(parts.last)) {
    parts.removeLast();
  }
  if (parts.length <= 1) return parts.isEmpty ? '' : parts.first;
  // Con cuatro palabras o más (nombres + apellido paterno + materno) el apellido que se abrevia es el tercero:
  // `YOSELIN ROSA MIRANDA SALAZAR` → `YOSELIN ROSA M.`; así nunca pasa de dos palabras y una inicial.
  final last = parts.length >= 4 ? parts[2] : parts.last;
  final head = parts.length >= 4 ? parts.sublist(0, 2) : parts.sublist(0, parts.length - 1);
  return '${head.join(' ')} ${last.substring(0, 1).toUpperCase()}.';
}

/// Nombre y la inicial del apellido: `FRANCIS BULNES GONZALES` → `FRANCIS B.`.
///
/// Los nombres peruanos van como nombres + apellido paterno + apellido materno, así que según
/// cuántas palabras tenga: 1 → igual; 2 o 3 → primera + inicial de la segunda; 4 o más (dos
/// nombres) → primera + inicial de la tercera (el apellido paterno). Vacío sigue vacío.
String shortPersonName(String? fullName) {
  final parts = (fullName ?? '').trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
  if (parts.length <= 1) return parts.isEmpty ? '' : parts.first;
  final surname = parts.length >= 4 ? parts[2] : parts[1];
  return '${parts.first} ${surname.substring(0, 1).toUpperCase()}.';
}
