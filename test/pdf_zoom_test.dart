import 'dart:convert';
import 'dart:typed_data';

import 'package:app_novik/presentation/pages/pdf_zoom_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// PNG de 1x1 píxel (blanco).
final _png = Uint8List.fromList(
  base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==',
  ),
);

Widget _app({
  required PdfPageRasterizer rasterizer,
  bool disableAnimations = false,
}) => MaterialApp(
  home: MediaQuery(
    data: MediaQueryData(disableAnimations: disableAnimations),
    child: PdfZoomPage(
      pdf: Uint8List(0),
      title: 'C001-3458',
      subtitle: 'Cotización · VICTOR MEDRANO',
      rasterizer: rasterizer,
    ),
  ),
);

Future<List<Uint8List>> _onePage(Uint8List _) async => [_png];

double _scale(WidgetTester tester) {
  final viewer = tester.widget<InteractiveViewer>(find.byType(InteractiveViewer));
  return viewer.transformationController!.value.getMaxScaleOnAxis();
}

void main() {
  testWidgets('muestra el título, el subtítulo y la hoja', (tester) async {
    await tester.pumpWidget(_app(rasterizer: _onePage));
    await tester.pumpAndSettle();

    expect(find.text('C001-3458'), findsOneWidget);
    expect(find.text('Cotización · VICTOR MEDRANO'), findsOneWidget);
    expect(find.byType(Image), findsOneWidget);
    expect(find.byType(InteractiveViewer), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('con varias páginas las muestra una debajo de otra', (tester) async {
    await tester.pumpWidget(_app(rasterizer: (_) async => [_png, _png, _png]));
    await tester.pumpAndSettle();
    expect(find.byType(Image), findsNWidgets(3));
  });

  testWidgets('mientras prepara la hoja muestra un esqueleto', (tester) async {
    final done = Future<List<Uint8List>>.delayed(const Duration(seconds: 1), () => [_png]);
    await tester.pumpWidget(_app(rasterizer: (_) => done));
    await tester.pump();
    expect(find.byType(Image), findsNothing);
    expect(find.bySemanticsLabel('Cargando'), findsOneWidget);
    await tester.pumpAndSettle();
    expect(find.byType(Image), findsOneWidget);
  });

  testWidgets('dos toques acercan y otros dos vuelven al tamaño normal', (tester) async {
    await tester.pumpWidget(_app(rasterizer: _onePage));
    await tester.pumpAndSettle();
    expect(_scale(tester), 1);

    final center = tester.getCenter(find.byType(InteractiveViewer));
    await tester.tapAt(center);
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tapAt(center);
    await tester.pumpAndSettle();
    expect(_scale(tester), closeTo(3, 0.01));

    await tester.tapAt(center);
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tapAt(center);
    await tester.pumpAndSettle();
    expect(_scale(tester), closeTo(1, 0.01));
  });

  testWidgets('acercado, el botón "Tamaño normal" aparece y devuelve al inicio', (tester) async {
    await tester.pumpWidget(_app(rasterizer: _onePage));
    await tester.pumpAndSettle();

    double fabScale() => tester.widget<AnimatedScale>(find.byType(AnimatedScale)).scale;
    expect(fabScale(), 0);

    final center = tester.getCenter(find.byType(InteractiveViewer));
    await tester.tapAt(center);
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tapAt(center);
    await tester.pumpAndSettle();
    expect(fabScale(), 1);

    await tester.tap(find.byTooltip('Tamaño normal'));
    await tester.pumpAndSettle();
    expect(_scale(tester), closeTo(1, 0.01));
    expect(fabScale(), 0);
  });

  testWidgets('si no se puede preparar la hoja, avisa y permite reintentar', (tester) async {
    var calls = 0;
    await tester.pumpWidget(
      _app(
        rasterizer: (_) async {
          calls++;
          if (calls == 1) throw Exception('sin motor');
          return [_png];
        },
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('No se pudo acercar el documento'), findsOneWidget);

    await tester.tap(find.text('Reintentar'));
    await tester.pumpAndSettle();
    expect(find.byType(Image), findsOneWidget);
    expect(calls, 2);
  });

  testWidgets('cerrar vuelve a la pantalla anterior', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => openPdfZoom(
                context,
                pdf: Uint8List(0),
                title: 'C001-1',
                rasterizer: _onePage,
              ),
              child: const Text('abrir'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();
    expect(find.text('C001-1'), findsOneWidget);

    await tester.tap(find.byTooltip('Cerrar'));
    await tester.pumpAndSettle();
    expect(find.text('C001-1'), findsNothing);
    expect(find.text('abrir'), findsOneWidget);
  });
}
