import 'package:flutter/material.dart';
import '../../core/utils/format.dart';
import '../../theme/app_theme.dart';

/// Variación contra el año pasado: "+31.0 % ↑" en verde, "-5.0 % ↓" en rojo.
/// Sin base de comparación (`null`) muestra "—".
class AppVariationBadge extends StatelessWidget {
  final double? value;

  const AppVariationBadge({super.key, required this.value});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final pct = value;

    final Color base;
    final String text;
    if (pct == null) {
      base = theme.colorScheme.onSurfaceVariant;
      text = '—';
    } else {
      final up = pct >= 0;
      base = up ? const Color(0xFF16A34A) : const Color(0xFFDC2626);
      text = '${up ? '+' : ''}${pct.toStringAsFixed(1)} % ${up ? '↑' : '↓'}';
    }
    final color = HSLColor.fromColor(base).withLightness(dark ? 0.72 : 0.28).toColor();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: base.withValues(alpha: dark ? 0.22 : 0.14),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: theme.textTheme.labelMedium?.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    );
  }
}

/// Dato destacado: etiqueta pequeña, valor grande y, opcionalmente, su variación.
class AppMetric extends StatelessWidget {
  final String label;
  final String value;
  final double? variation;
  final bool showVariation;

  const AppMetric({
    super.key,
    required this.label,
    required this.value,
    this.variation,
    this.showVariation = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w800,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
        if (showVariation) ...[
          const SizedBox(height: 4),
          AppVariationBadge(value: variation),
        ],
      ],
    );
  }
}

/// Ranking en barras horizontales: nombre, barra proporcional al mayor y monto.
class AppBarList extends StatelessWidget {
  final List<({String label, double value})> items;
  final String emptyText;
  final String symbol;

  const AppBarList({
    super.key,
    required this.items,
    this.emptyText = 'Sin datos en el rango',
    this.symbol = 'S/',
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    if (items.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Center(
          child: Text(
            emptyText,
            style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ),
      );
    }

    final maximum = items.fold<double>(1, (m, i) => i.value > m ? i.value : m);
    final fill = AppTheme.strongFill(theme.brightness);

    return Column(
      children: [
        for (final item in items)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        item.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      formatMoney(item.value, symbol: symbol),
                      style: theme.textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: (item.value / maximum).clamp(0.02, 1.0),
                    minHeight: 8,
                    color: fill,
                    backgroundColor: scheme.surfaceContainer,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Barras agrupadas por categoría con dos series (por ejemplo, ventas de cada
/// mes este año y el anterior).
class AppGroupedBarChart extends StatelessWidget {
  final List<String> labels;

  /// Serie de fondo (el año anterior), una por etiqueta.
  final List<double> previous;

  /// Serie principal (este año), una por etiqueta.
  final List<double> current;
  final double height;

  const AppGroupedBarChart({
    super.key,
    required this.labels,
    required this.previous,
    required this.current,
    this.height = 200,
  });

  @override
  Widget build(BuildContext context) {
    assert(
      labels.length == previous.length && labels.length == current.length,
      'labels, previous y current deben tener la misma cantidad de elementos',
    );
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return SizedBox(
      height: height,
      width: double.infinity,
      child: CustomPaint(
        painter: _GroupedBarPainter(
          labels: labels,
          previous: previous,
          current: current,
          previousColor: scheme.outlineVariant,
          currentColor: AppTheme.strongFill(theme.brightness),
          gridColor: scheme.outlineVariant.withValues(alpha: 0.5),
          textStyle: (theme.textTheme.labelSmall ?? const TextStyle(fontSize: 10))
              .copyWith(color: scheme.onSurfaceVariant),
        ),
      ),
    );
  }
}

class _GroupedBarPainter extends CustomPainter {
  final List<String> labels;
  final List<double> previous;
  final List<double> current;
  final Color previousColor;
  final Color currentColor;
  final Color gridColor;
  final TextStyle textStyle;

  _GroupedBarPainter({
    required this.labels,
    required this.previous,
    required this.current,
    required this.previousColor,
    required this.currentColor,
    required this.gridColor,
    required this.textStyle,
  });

  TextPainter _text(String text) => TextPainter(
        text: TextSpan(text: text, style: textStyle),
        textDirection: TextDirection.ltr,
        maxLines: 1,
      )..layout();

  @override
  void paint(Canvas canvas, Size size) {
    if (labels.isEmpty) return;

    var top = 0.0;
    for (final v in [...previous, ...current]) {
      if (v > top) top = v;
    }
    if (top <= 0) top = 1;

    const axisWidth = 44.0;
    const bottomMargin = 20.0;
    final plot = Rect.fromLTWH(axisWidth, 4, size.width - axisWidth, size.height - bottomMargin - 4);

    // Líneas de guía con su monto (0, mitad y máximo).
    final grid = Paint()
      ..color = gridColor
      ..strokeWidth = 1;
    for (final fraction in [0.0, 0.5, 1.0]) {
      final y = plot.bottom - plot.height * fraction;
      canvas.drawLine(Offset(plot.left, y), Offset(plot.right, y), grid);
      final label = _text(formatCompactMoney(top * fraction));
      label.paint(canvas, Offset(axisWidth - label.width - 6, y - label.height / 2));
    }

    final slot = plot.width / labels.length;
    final barWidth = (slot * 0.34).clamp(2.0, 14.0);
    const gap = 1.5;

    void bar(double x, double value, Color color) {
      if (value <= 0) return;
      final h = plot.height * (value / top);
      canvas.drawRRect(
        RRect.fromRectAndCorners(
          Rect.fromLTWH(x, plot.bottom - h, barWidth, h),
          topLeft: const Radius.circular(3),
          topRight: const Radius.circular(3),
        ),
        Paint()..color = color,
      );
    }

    for (var i = 0; i < labels.length; i++) {
      final center = plot.left + slot * i + slot / 2;
      bar(center - barWidth - gap / 2, previous[i], previousColor);
      bar(center + gap / 2, current[i], currentColor);

      final label = _text(labels[i]);
      label.paint(canvas, Offset(center - label.width / 2, plot.bottom + 4));
    }
  }

  @override
  bool shouldRepaint(_GroupedBarPainter old) =>
      old.labels != labels ||
      old.previous != previous ||
      old.current != current ||
      old.currentColor != currentColor ||
      old.previousColor != previousColor;
}
