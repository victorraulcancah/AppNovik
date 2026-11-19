import 'package:app_novik/presentation/components/components.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Las líneas marcadas (el correo y las sucursales de Usuarios) van siempre en una sola línea y con la misma
/// letra que las demás: si no caben terminan en "…", no se achican.
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

  double? fontSize(WidgetTester tester, Finder finder) => tester.widget<Text>(finder).style?.fontSize;

  testWidgets('el correo y las sucursales ocupan una sola línea con la misma letra que las demás', (tester) async {
    await pump(tester);

    final roles = find.text('Roles: Ceo Empresa');
    final correo = find.textContaining('Correo:');
    final sucursales = find.textContaining('Sucursales:');

    // Una línea de texto mide lo mismo que la de Roles (que cabe de sobra).
    expect(tester.getSize(correo).height, tester.getSize(roles).height);
    expect(tester.getSize(sucursales).height, tester.getSize(roles).height);
    // Y la misma letra: no se achican.
    expect(fontSize(tester, correo), fontSize(tester, roles));
    expect(fontSize(tester, sucursales), fontSize(tester, roles));
    // Lo que no cabe termina en "…" y el texto completo sigue ahí.
    expect(tester.widget<Text>(correo).overflow, TextOverflow.ellipsis);
    expect(tester.widget<Text>(correo).data, 'Correo: gustavo.grupogm.con.un.correo.muy.largo@gmail.com');
  });

  testWidgets('con letra grande también sigue en una línea', (tester) async {
    await pump(tester, textScale: 1.5);

    // Las dos marcadas siguen en una línea (misma altura); "Roles", sin marcar, puede partirse.
    final correo = tester.getSize(find.textContaining('Correo:')).height;
    final sucursales = tester.getSize(find.textContaining('Sucursales:')).height;
    final roles = tester.getSize(find.text('Roles: Ceo Empresa')).height;
    expect(correo, sucursales);
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
