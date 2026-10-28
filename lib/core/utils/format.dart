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
