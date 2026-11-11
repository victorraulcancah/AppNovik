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
  testWidgets('al llegar los resultados el teclado baja para dar más alto', (tester) async {
    await _open(tester);

    await tester.enterText(find.byType(TextField), 'evo');
    // Mientras escribe, el campo sigue enfocado (el teclado arriba).
    expect(FocusManager.instance.primaryFocus?.hasPrimaryFocus, isTrue);

    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();

    expect(find.text('evo uno'), findsOneWidget);
    final field = tester.widget<EditableText>(find.byType(EditableText));
    expect(field.focusNode.hasFocus, isFalse);
  });

  testWidgets('si se siguió escribiendo, no le quita el teclado', (tester) async {
    await _open(tester);

    await tester.enterText(find.byType(TextField), 'ev');
    await tester.pump(const Duration(milliseconds: 500));
    // Antes de que termine la respuesta anterior, escribe otra letra.
    await tester.enterText(find.byType(TextField), 'evo');
    await tester.pump();

    final field = tester.widget<EditableText>(find.byType(EditableText));
    expect(field.focusNode.hasFocus, isTrue);
    await tester.pumpAndSettle();
  });
}
