import 'package:app_novik/core/utils/either.dart';
import 'package:app_novik/presentation/components/app_search_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _open(WidgetTester tester) async {
  tester.view.physicalSize = const Size(800, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(
    home: Builder(
      builder: (context) => TextButton(
        onPressed: () => showAppSearchSheet<String>(
          context,
          title: 'Producto',
          hint: 'Nombre…',
          search: (q) async => Either.right(['$q uno', '$q dos']),
          itemOf: (s) => AppSearchItem(title: s),
          onSelect: (_) => null,
        ),
        child: const Text('abrir'),
      ),
    ),
  ));
  await tester.tap(find.text('abrir'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('la ventana no se mueve ni cambia de alto al buscar, y el teclado sigue ahí', (tester) async {
    await _open(tester);
    final topAntes = tester.getTopLeft(find.text('Producto')).dy;
    final cerrarAntes = tester.getTopLeft(find.text('Cerrar')).dy;

    await tester.enterText(find.byType(TextField), 'evo');
    await tester.pump(const Duration(milliseconds: 100));
    // Mientras carga (esqueleto) y con los resultados a la vista, sigue en el mismo lugar.
    expect(tester.getTopLeft(find.text('Producto')).dy, topAntes);
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();

    expect(find.text('evo uno'), findsOneWidget);
    expect(tester.getTopLeft(find.text('Producto')).dy, topAntes);
    expect(tester.getTopLeft(find.text('Cerrar')).dy, cerrarAntes);
    // El teclado no baja solo al llegar los resultados.
    final field = tester.widget<EditableText>(find.byType(EditableText));
    expect(field.focusNode.hasFocus, isTrue);
  });

  testWidgets('con muchos o pocos resultados la ventana mide lo mismo', (tester) async {
    await _open(tester);
    final alto = tester.getSize(find.byType(Material).last);

    await tester.enterText(find.byType(TextField), 'a');
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();

    expect(tester.getSize(find.byType(Material).last), alto);
  });

  testWidgets('un resultado puede llevar un widget a la izquierda y no corta el nombre', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    const largo = 'AMPLIFICADOR DIGITAL MONORAL 1CH * 1500 RMS 4500WATTS PROFESIONAL';
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => TextButton(
          onPressed: () => showAppSearchSheet<String>(
            context,
            title: 'Producto',
            hint: 'Nombre…',
            search: (q) async => Either.right([largo]),
            itemOf: (s) => AppSearchItem(
              title: s,
              trailing: 'S/ 1,000.00',
              leading: const Icon(Icons.image, key: Key('foto')),
            ),
            onSelect: (_) => null,
          ),
          child: const Text('abrir'),
        ),
      ),
    ));
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'evo');
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('foto')), findsOneWidget);
    final title = tester.widget<Text>(find.text(largo));
    expect(title.overflow, isNot(TextOverflow.ellipsis));
    expect(tester.takeException(), isNull);
  });
}
