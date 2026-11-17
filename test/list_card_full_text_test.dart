import 'package:app_novik/presentation/components/components.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('la tarjeta muestra el nombre y las líneas completos, sin cortarlos con "…"', (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    const nombre = 'AMPLIFICADOR DIGITAL 4CH * 150 + 1CH * 400 RMS 4500WATTS PROFESIONAL';
    const linea = 'ANTHONY KENER GUSTAVO MIRANDA PUN · PRINCIPAL ALMACEN CENTRAL';

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AppListCard(
            title: nombre,
            lines: const [linea],
            trailingTitle: 'S/ 3,699.00',
            actions: const [Icon(Icons.edit), Icon(Icons.delete), Icon(Icons.picture_as_pdf)],
          ),
        ),
      ),
    );

    for (final t in tester.widgetList<Text>(find.byType(Text))) {
      expect(t.maxLines, isNull);
      expect(t.overflow, isNot(TextOverflow.ellipsis));
    }
    expect(find.text(nombre), findsOneWidget);
    expect(find.text(linea), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('la imagen de la izquierda queda centrada a lo alto de la tarjeta', (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AppListCard(
            leading: const SizedBox(key: Key('foto'), width: 48, height: 48),
            title: 'CABLE DE ALIMENTACIÓN CCA CALIBRE 0GA 15 METROS',
            lines: const ['Código · 0GA', '7POWER · ROLLO CABLE'],
            trailingTitle: 'UNIDAD (4 c/u)',
            actions: const [Icon(Icons.edit), Icon(Icons.delete)],
          ),
        ),
      ),
    );

    final card = tester.getRect(find.byType(AppListCard));
    final foto = tester.getRect(find.byKey(const Key('foto')));
    // El centro de la foto cae en el centro (a lo alto) del contenido de la tarjeta, no arriba.
    expect((foto.center.dy - card.center.dy).abs(), lessThan(14));
    expect(tester.takeException(), isNull);
  });
}
