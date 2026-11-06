import 'dart:ui' show PathMetric;

import 'package:flutter/material.dart';

/// Check de éxito animado: el círculo verde aparece con un pequeño rebote y la marca se dibuja.
class AppSuccessCheck extends StatelessWidget {
  final double size;
  final Color color;

  const AppSuccessCheck({
    super.key,
    this.size = 72,
    this.color = const Color(0xFF16A34A),
  });

  @override
  Widget build(BuildContext context) {
    final still = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    return Semantics(
      label: 'Listo',
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: still ? 1 : 0, end: 1),
        duration: const Duration(milliseconds: 700),
        builder: (context, t, _) => CustomPaint(
          size: Size.square(size),
          painter: _CheckPainter(t, color),
        ),
      ),
    );
  }
}

class _CheckPainter extends CustomPainter {
  final double t;
  final Color color;

  _CheckPainter(this.t, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    // Primer 55 %: el círculo crece con rebote. Resto: se dibuja la marca.
    final circleT = (t / 0.55).clamp(0.0, 1.0);
    final scale = Curves.easeOutBack.transform(circleT);
    canvas.drawCircle(center, size.width / 2 * scale, Paint()..color = color);

    final checkT = ((t - 0.45) / 0.55).clamp(0.0, 1.0);
    if (checkT <= 0) return;
    final w = size.width;
    final path = Path()
      ..moveTo(w * 0.28, w * 0.52)
      ..lineTo(w * 0.44, w * 0.67)
      ..lineTo(w * 0.73, w * 0.36);
    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.09
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final eased = Curves.easeOutCubic.transform(checkT);
    for (final PathMetric m in path.computeMetrics()) {
      canvas.drawPath(m.extractPath(0, m.length * eased), paint);
    }
  }

  @override
  bool shouldRepaint(_CheckPainter old) => old.t != t || old.color != color;
}
