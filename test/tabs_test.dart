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

    // Solo se ve la pestaña activa, pero la oculta sigue montada.
    expect(find.byKey(const Key('a')), findsOneWidget);
    expect(find.byKey(const Key('b')), findsNothing);
    expect(forms[1].currentState, isNotNull);

    // La pestaña oculta se valida igual y el controlador salta a ella.
    expect(controller.validate(forms), isFalse);
    expect(controller.index, 1);
    expect(controller.errors, {1});

    await tester.pump();
    expect(find.byKey(const Key('b')), findsOneWidget);
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
}
