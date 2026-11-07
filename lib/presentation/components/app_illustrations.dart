import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

/// Qué ilustración dibujar.
enum AppIllustrationKind {
  /// Una hoja con una lupa: sin resultados o lista vacía.
  empty,

  /// Una nube tachada: no se pudo cargar o no hay conexión.
  error,

  /// Un candado: sin acceso o sin permiso.
  locked,

  /// Una caja abierta: cualquier otro estado vacío.
  generic,
}

/// Ilustración sencilla dibujada con formas (sin imágenes ni paquetes), en los colores de la
/// marca: azul marino para los trazos y naranja para el acento. Se adapta al modo claro y al
/// oscuro. Aparece con un pequeño rebote; con "quitar animaciones" sale directa.
class AppIllustration extends StatelessWidget {
  final AppIllustrationKind kind;

  /// Ancho en píxeles lógicos (el alto es el 79 % del ancho).
  final double width;

  const AppIllustration({super.key, required this.kind, this.width = 140});

  static const _w = 140.0;
  static const _h = 110.0;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final isError = kind == AppIllustrationKind.error;

    final painter = _IllustrationPainter(
      kind: kind,
      ink: dark ? const Color(0xFFCBD5E1) : AppTheme.brandDark,
      surface: scheme.surfaceContainerLowest,
      page: scheme.surface,
      accent: isError ? scheme.error : AppTheme.primary,
      line: scheme.outlineVariant,
      blob: isError
          ? scheme.errorContainer.withValues(alpha: dark ? 0.35 : 0.6)
          : AppTheme.primary.withValues(alpha: dark ? 0.14 : 0.10),
    );

    final art = ExcludeSemantics(
      child: CustomPaint(
        size: Size(width, width * _h / _w),
        painter: painter,
      ),
    );

    if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) return art;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.9, end: 1),
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeOutBack,
      builder: (context, scale, child) => Transform.scale(scale: scale, child: child),
      child: art,
    );
  }
}

class _IllustrationPainter extends CustomPainter {
  final AppIllustrationKind kind;
  final Color ink;
  final Color surface;
  final Color page;
  final Color accent;
  final Color line;
  final Color blob;

  _IllustrationPainter({
    required this.kind,
    required this.ink,
    required this.surface,
    required this.page,
    required this.accent,
    required this.line,
    required this.blob,
  });

  Paint _fill(Color c) => Paint()..color = c;

  Paint _stroke(Color c, double w) => Paint()
    ..color = c
    ..style = PaintingStyle.stroke
    ..strokeWidth = w
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;

  /// Dibuja el contorno de una forma y luego su relleno, para que varios trazos superpuestos
  /// se vean como una sola silueta.
  void _solid(Canvas canvas, Path path, {double stroke = 2.5, Color? fill}) {
    canvas.drawPath(path, _stroke(ink, stroke * 2));
    canvas.drawPath(path, _fill(fill ?? surface));
  }

  void _sparkle(Canvas canvas, Offset c, double r) {
    final p = _stroke(accent, 2.2);
    canvas.drawLine(c.translate(-r, 0), c.translate(r, 0), p);
    canvas.drawLine(c.translate(0, -r), c.translate(0, r), p);
  }

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / AppIllustration._w);

    // Fondo suave y sombra en el suelo.
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(70, 56), width: 124, height: 88),
      _fill(blob),
    );
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(70, 100), width: 70, height: 9),
      _fill(ink.withValues(alpha: 0.10)),
    );

    switch (kind) {
      case AppIllustrationKind.empty:
        _paintEmpty(canvas);
      case AppIllustrationKind.error:
        _paintError(canvas);
      case AppIllustrationKind.locked:
        _paintLocked(canvas);
      case AppIllustrationKind.generic:
        _paintGeneric(canvas);
    }
  }

  void _paintEmpty(Canvas canvas) {
    final sheet = RRect.fromLTRBR(36, 14, 92, 88, const Radius.circular(8));
    canvas.drawRRect(sheet, _fill(surface));
    canvas.drawRRect(sheet, _stroke(ink, 2.5));
    for (final (y, x2) in [(32.0, 80.0), (46.0, 80.0), (60.0, 66.0)]) {
      canvas.drawLine(Offset(47, y), Offset(x2, y), _stroke(line, 3.5));
    }
    // Lupa.
    canvas.drawCircle(const Offset(92, 68), 16, _fill(surface.withValues(alpha: 0.9)));
    canvas.drawCircle(const Offset(92, 68), 16, _stroke(accent, 4.5));
    canvas.drawLine(const Offset(104, 80), const Offset(118, 94), _stroke(accent, 6));
    canvas.drawArc(
      Rect.fromCircle(center: const Offset(92, 68), radius: 9),
      math.pi * 1.1,
      math.pi * 0.5,
      false,
      _stroke(accent.withValues(alpha: 0.45), 2.2),
    );
    _sparkle(canvas, const Offset(26, 30), 4);
    canvas.drawCircle(const Offset(112, 24), 2.5, _fill(accent));
  }

  void _paintError(Canvas canvas) {
    final cloud = Path()
      ..addRRect(RRect.fromLTRBR(32, 52, 108, 82, const Radius.circular(15)))
      ..addOval(Rect.fromCircle(center: const Offset(56, 52), radius: 17))
      ..addOval(Rect.fromCircle(center: const Offset(82, 44), radius: 21))
      ..addOval(Rect.fromCircle(center: const Offset(98, 58), radius: 13));
    _solid(canvas, cloud, stroke: 2.5);
    // Tachado: primero un trazo del color de la pantalla (deja un hueco) y encima el acento.
    canvas.drawLine(const Offset(42, 24), const Offset(102, 92), _stroke(page, 11));
    canvas.drawLine(const Offset(42, 24), const Offset(102, 92), _stroke(accent, 5));
    _sparkle(canvas, const Offset(24, 36), 4);
    canvas.drawCircle(const Offset(116, 32), 2.5, _fill(accent));
  }

  void _paintLocked(Canvas canvas) {
    // Arco del candado.
    final shackle = _stroke(ink, 6);
    canvas.drawArc(
      Rect.fromCircle(center: const Offset(70, 46), radius: 17),
      math.pi,
      math.pi,
      false,
      shackle,
    );
    canvas.drawLine(const Offset(53, 46), const Offset(53, 58), shackle);
    canvas.drawLine(const Offset(87, 46), const Offset(87, 58), shackle);
    // Cuerpo.
    final body = RRect.fromLTRBR(42, 56, 98, 94, const Radius.circular(10));
    canvas.drawRRect(body, _fill(accent));
    canvas.drawRRect(body, _stroke(ink, 2.5));
    // Ojo de la cerradura.
    canvas.drawCircle(const Offset(70, 71), 5.5, _fill(Colors.white));
    canvas.drawRRect(
      RRect.fromLTRBR(67.5, 73, 72.5, 84, const Radius.circular(2.5)),
      _fill(Colors.white),
    );
    _sparkle(canvas, const Offset(28, 34), 4);
    canvas.drawCircle(const Offset(114, 40), 2.5, _fill(accent));
  }

  void _paintGeneric(Canvas canvas) {
    // Caja abierta: frente, aletas y una ranura.
    final front = RRect.fromLTRBR(34, 48, 106, 90, const Radius.circular(8));
    canvas.drawRRect(front, _fill(surface));
    canvas.drawRRect(front, _stroke(ink, 2.5));
    canvas.drawLine(const Offset(54, 64), const Offset(86, 64), _stroke(line, 3.5));
    final flaps = Path()
      ..moveTo(34, 48)
      ..lineTo(46, 28)
      ..lineTo(94, 28)
      ..lineTo(106, 48)
      ..close();
    canvas.drawPath(flaps, _fill(accent.withValues(alpha: 0.28)));
    canvas.drawPath(flaps, _stroke(ink, 2.5));
    _sparkle(canvas, const Offset(24, 32), 4);
    canvas.drawCircle(const Offset(116, 28), 2.5, _fill(accent));
    canvas.drawCircle(const Offset(110, 66), 1.8, _fill(accent.withValues(alpha: 0.6)));
  }

  @override
  bool shouldRepaint(_IllustrationPainter old) =>
      old.kind != kind ||
      old.ink != ink ||
      old.surface != surface ||
      old.page != page ||
      old.accent != accent ||
      old.line != line ||
      old.blob != blob;
}
