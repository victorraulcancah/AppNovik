import 'package:app_novik/presentation/components/components.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Las líneas marcadas (el correo y las sucursales de Usuarios) van siempre en una sola línea, achicadas
/// si hace falta, y su texto sigue completo.
void main() {
  Future<void> pump(WidgetTester tester, {double textScale = 1}) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = textScale;
    addTearDown(() {
      tester.view.reset();
      tester.platformDispatcher.clearTextScaleFactorTestValue();
    });
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: AppListCard(
            title: 'GRUPO 7POWER SAC',
            lines: [
              'Roles: Ceo Empresa',
              'Correo: gustavo.grupogm.con.un.correo.muy.largo@gmail.com',
              'Sucursales: Todos los Almacenes de la empresa y sus sucursales',
            ],
            oneLinePrefixes: ['Correo:', 'Sucursales:'],
            actions: [Icon(Icons.edit)],
          ),
        ),
      ),
    );
  }

  testWidgets('el correo y las sucursales ocupan una sola línea y no se cortan', (tester) async {
    await pump(tester);

    final roles = tester.getSize(find.text('Roles: Ceo Empresa')).height;
    final correo = tester.getSize(find.textContaining('Correo:')).height;
    final sucursales = tester.getSize(find.textContaining('Sucursales:')).height;

    // Una línea de texto mide lo mismo que la de Roles (que cabe de sobra).
    expect(correo, roles);
    expect(sucursales, roles);
    // Y el texto está completo.
    expect(find.text('Correo: gustavo.grupogm.con.un.correo.muy.largo@gmail.com'), findsOneWidget);
  });

  testWidgets('con letra grande también sigue en una línea', (tester) async {
    await pump(tester, textScale: 1.5);

    final correo = tester.getSize(find.textContaining('Correo:')).height;
    final roles = tester.getSize(find.text('Roles: Ceo Empresa')).height;
    // Con letra grande el texto se achica: sigue siendo una línea (no más alta que una).
    expect(correo, lessThanOrEqualTo(roles));
    expect(tester.takeException(), isNull);
  });

  testWidgets('sin marcar, las líneas largas se parten como siempre', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: AppListCard(
            title: 'X',
            lines: ['Roles: Ceo Empresa', 'Correo: gustavo.grupogm.con.un.correo.muy.largo.de.verdad@gmail.com'],
            actions: [Icon(Icons.edit)],
          ),
        ),
      ),
    );
    expect(
      tester.getSize(find.textContaining('Correo:')).height,
      greaterThan(tester.getSize(find.text('Roles: Ceo Empresa')).height),
    );
  });
}
