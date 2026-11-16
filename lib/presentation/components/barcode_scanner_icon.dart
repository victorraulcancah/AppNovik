import 'package:flutter/material.dart';

/// El ícono del escáner de código de barras: cuatro esquinas y, en el medio, las barras del código.
/// (Flutter trae solo el del lector y el de QR, no este.)
class BarcodeScannerIcon extends StatelessWidget {
  final double size;
  final Color? color;

  const BarcodeScannerIcon({super.key, this.size = 24, this.color});

  @override
  Widget build(BuildContext context) {
    final resolved = color ?? IconTheme.of(context).color ?? Theme.of(context).colorScheme.onSurface;
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _BarcodeScannerPainter(resolved)),
    );
  }
}

class _BarcodeScannerPainter extends CustomPainter {
  final Color color;
  const _BarcodeScannerPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final u = size.width / 24;
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2 * u
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    // Las cuatro esquinas.
    final corners = Path()
      ..moveTo(3 * u, 8 * u)
      ..lineTo(3 * u, 4 * u)
      ..lineTo(7 * u, 4 * u)
      ..moveTo(17 * u, 4 * u)
      ..lineTo(21 * u, 4 * u)
      ..lineTo(21 * u, 8 * u)
      ..moveTo(21 * u, 16 * u)
      ..lineTo(21 * u, 20 * u)
      ..lineTo(17 * u, 20 * u)
      ..moveTo(7 * u, 20 * u)
      ..lineTo(3 * u, 20 * u)
      ..lineTo(3 * u, 16 * u);
    canvas.drawPath(corners, stroke);

    // Las barras: de distinto grosor, como un código de barras.
    final fill = Paint()..color = color;
    void bar(double x, double w) => canvas.drawRect(Rect.fromLTWH(x * u, 8 * u, w * u, 8 * u), fill);
    bar(7, 1.5);
    bar(10, 1);
    bar(12, 2);
    bar(15.5, 1);
    bar(17.5, 0.8);
  }

  @override
  bool shouldRepaint(_BarcodeScannerPainter old) => old.color != color;
}
