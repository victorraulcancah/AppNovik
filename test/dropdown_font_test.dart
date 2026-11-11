import 'package:app_novik/presentation/components/components.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget app({ThemeMode mode = ThemeMode.light, double textScale = 1}) => MaterialApp(
    themeMode: mode,
    theme: ThemeData(colorSchemeSeed: Colors.orange),
    darkTheme: ThemeData(colorSchemeSeed: Colors.orange, brightness: Brightness.dark),
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale)),
      child: child!,
    ),
    home: Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: AppDropdownField<int>(
                label: 'Almacén',
                value: 1,
                items: const [
                  DropdownMenuItem(value: 1, child: Text('PRINCIPAL')),
                  DropdownMenuItem(value: 2, child: Text('SOLES MAYORISTA LIMA')),
                ],
                onChanged: (_) {},
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: AppDropdownField<int>(
                label: 'Lista de precios',
                value: 2,
                items: const [
                  DropdownMenuItem(value: 1, child: Text('PRINCIPAL')),
                  DropdownMenuItem(value: 2, child: Text('SOLES MAYORISTA LIMA')),
                ],
                onChanged: (_) {},
              ),
            ),
          ],
        ),
      ),
    ),
  );

  testWidgets('el valor elegido sale en letra de 14', (tester) async {
    await tester.pumpWidget(app());
    final style = DefaultTextStyle.of(tester.element(find.text('PRINCIPAL').first)).style;
    expect(style.fontSize, AppDropdownField.fontSize);
    expect(AppDropdownField.fontSize, 14);
  });

  testWidgets('las opciones del menú usan la misma letra', (tester) async {
    await tester.pumpWidget(app());
    await tester.tap(find.byType(DropdownButtonFormField<int>).first);
    await tester.pumpAndSettle();
    final option = find.text('SOLES MAYORISTA LIMA').last;
    final style = DefaultTextStyle.of(tester.element(option)).style;
    expect(style.fontSize, AppDropdownField.fontSize);
  });

  testWidgets('en modo oscuro y con letra grande no se desborda', (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(app(mode: ThemeMode.dark, textScale: 1.3));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
