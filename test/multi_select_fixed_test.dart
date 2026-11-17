import 'package:app_novik/presentation/components/components.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Los selectores de varias opciones (filtros de vendedores, clientes, sucursales...) miden siempre lo
/// mismo, haya pocas o muchas opciones, y no se mueven al buscar.
void main() {
  List<({int id, String name})> options(int n) => [
        for (var i = 0; i < n; i++) (id: i, name: i == 0 ? 'CARRO ROJO' : 'OPCION $i'),
      ];

  Future<void> open(WidgetTester tester, List<({int id, String name})> list) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => TextButton(
          onPressed: () => showAppMultiSelect(context, title: 'Vendedores', options: list, selected: const []),
          child: const Text('abrir'),
        ),
      ),
    ));
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();
  }

  Size sheetSize(WidgetTester tester) => tester.getSize(find.byType(BottomSheet));

  testWidgets('con 2 opciones o con 60, la ventana mide lo mismo', (tester) async {
    await open(tester, options(2));
    final pocas = sheetSize(tester);
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();

    await open(tester, options(60));
    final muchas = sheetSize(tester);

    expect(pocas.height, muchas.height);
    // El 85 % de la pantalla.
    expect(pocas.height, closeTo(800 * 0.85, 1));
  });

  testWidgets('al buscar, la ventana no cambia de alto ni se mueve la lista', (tester) async {
    await open(tester, options(60));
    final antes = sheetSize(tester);
    final topLista = tester.getTopLeft(find.byType(CheckboxListTile).first).dy;

    await tester.enterText(find.widgetWithText(TextField, 'Buscar'), 'carro');
    await tester.pumpAndSettle();

    // Solo queda uno, pero la ventana y el comienzo de la lista siguen donde estaban.
    expect(find.byType(CheckboxListTile), findsOneWidget);
    expect(sheetSize(tester), antes);
    expect(tester.getTopLeft(find.byType(CheckboxListTile).first).dy, topLista);
  });

  testWidgets('con resultados y sin seguir escribiendo, el teclado baja', (tester) async {
    await open(tester, options(60));

    await tester.enterText(find.widgetWithText(TextField, 'Buscar'), 'carro');
    await tester.pump();
    expect(FocusManager.instance.primaryFocus?.hasPrimaryFocus, isTrue);
    await tester.pump(const Duration(milliseconds: 800));

    final field = tester.widget<EditableText>(find.byType(EditableText).first);
    expect(field.focusNode.hasFocus, isFalse);
  });

  testWidgets('si no hay resultados, el teclado se queda para seguir escribiendo', (tester) async {
    await open(tester, options(5));

    await tester.enterText(find.widgetWithText(TextField, 'Buscar'), 'zzz');
    await tester.pump(const Duration(milliseconds: 800));

    expect(find.text('Sin resultados'), findsOneWidget);
    final field = tester.widget<EditableText>(find.byType(EditableText).first);
    expect(field.focusNode.hasFocus, isTrue);
  });
}
