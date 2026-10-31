import 'package:flutter/material.dart';

/// Una serie de [AppAreaChart]: su nombre, su color y un valor por cada rótulo del eje X.
class AreaSeries {
  final String name;
  final Color color;
  final List<double> values;

  const AreaSeries({required this.name, required this.color, required this.values});
}

/// Gráfica de área con una o varias series sobre los mismos rótulos (por ejemplo, las ventas de
/// cada día). Al tocar o arrastrar sobre ella se marca un punto y se ve el valor de cada serie.
class AppAreaChart extends StatefulWidget {
  final List<String> labels;
  final List<AreaSeries> series;

  /// Cómo se escribe un valor en el detalle del punto (por ejemplo, `S/. 1,234.50`).
  final String Function(double value) format;
  final double height;

  const AppAreaChart({
    super.key,
    required this.labels,
    required this.series,
    required this.format,
    this.height = 210,
  });

  @override
  State<AppAreaChart> createState() => _AppAreaChartState();
}

class _AppAreaChartState extends State<AppAreaChart> {
  static const _left = 44.0;
  static const _right = 8.0;
  static const _top = 8.0;
  static const _bottom = 22.0;

  int? _selected;

  /// Abrevia un valor del eje Y: 1.2k, 3.4M.
  static String compact(double v) {
    final a = v.abs();
    if (a >= 1000000) return '${(v / 1000000).toStringAsFixed(a >= 10000000 ? 0 : 1)}M';
    if (a >= 1000) return '${(v / 1000).toStringAsFixed(a >= 10000 ? 0 : 1)}k';
    return v.toStringAsFixed(v == v.roundToDouble() ? 0 : 1);
  }

  double get _max {
    var max = 0.0;
    for (final s in widget.series) {
      for (final v in s.values) {
        if (v > max) max = v;
      }
    }
    return max <= 0 ? 1 : max;
  }

  void _select(Offset local, double width) {
    final n = widget.labels.length;
    if (n == 0) return;
    final inner = width - _left - _right;
    final t = n == 1 ? 0.0 : ((local.dx - _left) / inner).clamp(0.0, 1.0);
    setState(() => _selected = (t * (n - 1)).round());
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final n = widget.labels.length;

    return SizedBox(
      height: widget.height,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final inner = width - _left - _right;
          final selected = _selected != null && _selected! < n ? _selected : null;

          Widget? tooltip;
          if (selected != null) {
            final x = _left + (n == 1 ? 0 : selected / (n - 1) * inner);
            const boxWidth = 150.0;
            final left = (x - boxWidth / 2).clamp(0.0, width - boxWidth);
            tooltip = Positioned(
              left: left,
              top: 0,
              width: boxWidth,
              child: IgnorePointer(
                child: Material(
                  elevation: 3,
                  color: scheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.labels[selected],
                          style: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        for (final s in widget.series)
                          Row(
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(color: s.color, shape: BoxShape.circle),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  '${s.name}: ${selected < s.values.length ? widget.format(s.values[selected]) : '-'}',
                                  style: theme.textTheme.labelSmall,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }

          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: (d) => _select(d.localPosition, width),
            onHorizontalDragStart: (d) => _select(d.localPosition, width),
            onHorizontalDragUpdate: (d) => _select(d.localPosition, width),
            child: Stack(
              children: [
                CustomPaint(
                  size: Size(width, widget.height),
                  painter: _AreaPainter(
                    labels: widget.labels,
                    series: widget.series,
                    max: _max,
                    selected: selected,
                    gridColor: scheme.outlineVariant,
                    textColor: scheme.onSurfaceVariant,
                    markerColor: scheme.onSurface,
                  ),
                ),
                ?tooltip,
              ],
            ),
          );
        },
      ),
    );
  }
}

class _AreaPainter extends CustomPainter {
  final List<String> labels;
  final List<AreaSeries> series;
  final double max;
  final int? selected;
  final Color gridColor;
  final Color textColor;
  final Color markerColor;

  _AreaPainter({
    required this.labels,
    required this.series,
    required this.max,
    required this.selected,
    required this.gridColor,
    required this.textColor,
    required this.markerColor,
  });

  void _text(Canvas canvas, String text, Offset at, {TextAlign align = TextAlign.left}) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: TextStyle(color: textColor, fontSize: 10)),
      textDirection: TextDirection.ltr,
      textAlign: align,
    )..layout();
    final dx = switch (align) {
      TextAlign.right => at.dx - painter.width,
      TextAlign.center => at.dx - painter.width / 2,
      _ => at.dx,
    };
    painter.paint(canvas, Offset(dx, at.dy - painter.height / 2));
  }

  @override
  void paint(Canvas canvas, Size size) {
    const left = _AppAreaChartState._left;
    const right = _AppAreaChartState._right;
    const top = _AppAreaChartState._top;
    const bottom = _AppAreaChartState._bottom;
    final plot = Rect.fromLTRB(left, top, size.width - right, size.height - bottom);
    final n = labels.length;

    // Líneas de guía con su valor.
    final grid = Paint()
      ..color = gridColor
      ..strokeWidth = 0.6;
    for (var i = 0; i <= 4; i++) {
      final y = plot.bottom - plot.height * i / 4;
      canvas.drawLine(Offset(plot.left, y), Offset(plot.right, y), grid);
      _text(canvas, _AppAreaChartState.compact(max * i / 4), Offset(plot.left - 6, y), align: TextAlign.right);
    }

    if (n == 0) return;
    double xOf(int i) => n == 1 ? plot.center.dx : plot.left + plot.width * i / (n - 1);
    double yOf(double v) => plot.bottom - plot.height * (v / max).clamp(0.0, 1.0);

    // Rótulos del eje X: unos cinco, repartidos.
    final step = (n / 5).ceil().clamp(1, n);
    for (var i = 0; i < n; i += step) {
      _text(canvas, labels[i], Offset(xOf(i), size.height - bottom / 2 + 2), align: TextAlign.center);
    }

    for (final s in series) {
      if (s.values.isEmpty) continue;
      final line = Path();
      for (var i = 0; i < n && i < s.values.length; i++) {
        final p = Offset(xOf(i), yOf(s.values[i]));
        i == 0 ? line.moveTo(p.dx, p.dy) : line.lineTo(p.dx, p.dy);
      }
      final lastX = xOf((n < s.values.length ? n : s.values.length) - 1);
      final area = Path.from(line)
        ..lineTo(lastX, plot.bottom)
        ..lineTo(xOf(0), plot.bottom)
        ..close();

      canvas.drawPath(
        area,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [s.color.withValues(alpha: 0.35), s.color.withValues(alpha: 0.02)],
          ).createShader(plot),
      );
      canvas.drawPath(
        line,
        Paint()
          ..color = s.color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..strokeJoin = StrokeJoin.round,
      );
    }

    final sel = selected;
    if (sel != null) {
      final x = xOf(sel);
      canvas.drawLine(
        Offset(x, plot.top),
        Offset(x, plot.bottom),
        Paint()
          ..color = markerColor.withValues(alpha: 0.4)
          ..strokeWidth = 1,
      );
      for (final s in series) {
        if (sel < s.values.length) {
          canvas.drawCircle(Offset(x, yOf(s.values[sel])), 4, Paint()..color = s.color);
          canvas.drawCircle(
            Offset(x, yOf(s.values[sel])),
            4,
            Paint()
              ..color = Colors.white
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1.5,
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(_AreaPainter old) =>
      old.labels != labels ||
      old.series != series ||
      old.max != max ||
      old.selected != selected ||
      old.gridColor != gridColor;
}
