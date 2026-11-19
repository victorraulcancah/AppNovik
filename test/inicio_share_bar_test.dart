import 'package:app_novik/presentation/widgets/inicio_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Las barras de participación (Ventas por departamento, Ingresos por método) quedan alineadas en
/// todas las filas, aunque el porcentaje sea "2.0%" o "68.6%".
void main() {
  testWidgets('la barra empieza en el mismo lugar con porcentajes de distinto largo', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: const [
              InicioShareBar(key: ValueKey('a'), percent: 68.6, color: Colors.blue),
              InicioShareBar(key: ValueKey('b'), percent: 2.0, color: Colors.blue),
              InicioShareBar(key: ValueKey('c'), percent: 100, color: Colors.blue),
            ],
          ),
        ),
      ),
    );

    double barLeft(String key) =>
        tester.getTopLeft(find.descendant(of: find.byKey(ValueKey(key)), matching: find.byType(InicioProgressBar))).dx;

    expect(barLeft('a'), barLeft('b'));
    expect(barLeft('b'), barLeft('c'));
    expect(find.text('2.0%'), findsOneWidget);
    expect(find.text('100.0%'), findsOneWidget);
  });
}
