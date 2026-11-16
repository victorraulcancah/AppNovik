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
}
