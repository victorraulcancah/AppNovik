import 'package:app_novik/presentation/components/app_modal.dart';
import 'package:app_novik/presentation/components/app_tabs.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('validate salta a la primera pestaña con errores y la marca', (tester) async {
    final controller = AppTabsController();
    final forms = [GlobalKey<FormState>(), GlobalKey<FormState>()];
    final tabs = [
      AppTabItem(
        label: 'Uno',
        child: Form(key: forms[0], child: TextFormField(key: const Key('a'))),
      ),
      AppTabItem(
        label: 'Dos',
        child: Form(
          key: forms[1],
          child: TextFormField(
            key: const Key('b'),
            validator: (v) => (v == null || v.isEmpty) ? 'Requerido' : null,
          ),
        ),
      ),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              AppTabBar(tabs: tabs, controller: controller),
              AppTabsView(tabs: tabs, controller: controller),
            ],
          ),
        ),
      ),
    );

    // Solo se ve (y recibe toques) la pestaña activa, pero la oculta sigue montada.
    expect(find.byKey(const Key('a')).hitTestable(), findsOneWidget);
    expect(find.byKey(const Key('b')).hitTestable(), findsNothing);
    expect(forms[1].currentState, isNotNull);

    // La pestaña oculta se valida igual y el controlador salta a ella.
    expect(controller.validate(forms), isFalse);
    expect(controller.index, 1);
    expect(controller.errors, {1});

    await tester.pump();
    expect(find.byKey(const Key('b')).hitTestable(), findsOneWidget);
    expect(find.byKey(const Key('a')).hitTestable(), findsNothing);
    expect(find.text('Requerido'), findsOneWidget);
  });

  testWidgets('lo escrito en una pestaña se conserva al cambiar de pestaña', (tester) async {
    final controller = AppTabsController();
    final tabs = [
      AppTabItem(label: 'Uno', child: TextFormField(key: const Key('a'))),
      AppTabItem(label: 'Dos', child: const Text('contenido dos')),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: AppTabsView(tabs: tabs, controller: controller)),
      ),
    );

    await tester.enterText(find.byKey(const Key('a')), 'hola');
    controller.select(1);
    await tester.pump();
    expect(find.text('contenido dos'), findsOneWidget);

    controller.select(0);
    await tester.pump();
    expect(find.text('hola'), findsOneWidget);
  });

  group('misma altura en todas las pestañas', () {
    Future<(AppTabsController, List<AppTabItem>)> pumpTabs(WidgetTester tester, {List<double> heights = const [80, 240, 140]}) async {
      final controller = AppTabsController();
      final tabs = [
        for (var i = 0; i < heights.length; i++)
          AppTabItem(
            label: 'Pestaña $i',
            child: SizedBox(height: heights[i], child: Text('contenido $i')),
          ),
      ];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: Column(
                children: [
                  AppTabBar(tabs: tabs, controller: controller),
                  AppTabsView(key: const Key('view'), tabs: tabs, controller: controller),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      return (controller, tabs);
    }

    testWidgets('el alto es el de la pestaña más alta desde que se abre y no cambia al cambiar de pestaña', (tester) async {
      final (controller, _) = await pumpTabs(tester);
      double height() => tester.getSize(find.byKey(const Key('view'))).height;

      // Abre en la más baja (80) y ya ocupa lo de la más alta (240).
      expect(height(), 240);

      for (final i in [1, 2, 0, 2, 1]) {
        controller.select(i);
        await tester.pumpAndSettle();
        expect(height(), 240, reason: 'pestaña $i');
        expect(find.text('contenido $i').hitTestable(), findsOneWidget);
      }
    });

    testWidgets('el contenido de la pestaña activa arranca arriba y ocupa todo el ancho', (tester) async {
      final (controller, _) = await pumpTabs(tester);
      controller.select(0);
      await tester.pumpAndSettle();
      final view = tester.getRect(find.byKey(const Key('view')));
      final text = tester.getTopLeft(find.text('contenido 0'));
      expect(text.dy, view.top);
      expect(view.width, tester.view.physicalSize.width / tester.view.devicePixelRatio);
    });

    testWidgets('las pestañas ocultas no reciben toques ni salen en la lectura de pantalla', (tester) async {
      var taps = 0;
      final controller = AppTabsController();
      final tabs = [
        AppTabItem(label: 'Uno', child: const SizedBox(height: 50, child: Text('uno'))),
        AppTabItem(
          label: 'Dos',
          child: SizedBox(height: 50, child: TextButton(onPressed: () => taps++, child: const Text('botón dos'))),
        ),
      ];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: AppTabsView(tabs: tabs, controller: controller)),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('botón dos').hitTestable(), findsNothing);
      await tester.tap(find.text('botón dos'), warnIfMissed: false);
      expect(taps, 0);

      controller.select(1);
      await tester.pumpAndSettle();
      await tester.tap(find.text('botón dos'));
      expect(taps, 1);
    });
  });

  testWidgets('al pasar de una pestaña larga (desplazada) a una corta, la corta se ve y no la ventana vacía', (tester) async {
    tester.view.physicalSize = const Size(400, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => showAppModal(
              context,
              title: 'Editar',
              primaryLabel: 'Guardar',
              tabs: [
                AppTabItem(
                  label: 'Larga',
                  child: Column(children: [for (var i = 0; i < 30; i++) SizedBox(height: 60, child: Text('fila $i'))]),
                ),
                AppTabItem(label: 'Corta', child: const Text('contenido corto')),
              ],
            ),
            child: const Text('abrir'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();

    // Se baja bien abajo en la larga y se pasa a la corta.
    await tester.drag(find.text('fila 1'), const Offset(0, -1200));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Corta'));
    await tester.pumpAndSettle();

    expect(find.text('contenido corto').hitTestable(), findsOneWidget);
    final scroll = tester.state<ScrollableState>(find.byType(Scrollable).last);
    expect(scroll.position.pixels, 0);
  });
}
