import 'package:app_novik/presentation/components/components.dart';
import 'package:app_novik/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _app(
  Widget child, {
  ThemeMode mode = ThemeMode.light,
  double textScale = 1,
  bool disableAnimations = false,
}) => MaterialApp(
  themeMode: mode,
  theme: AppTheme.light,
  darkTheme: AppTheme.dark,
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(
      textScaler: TextScaler.linear(textScale),
      disableAnimations: disableAnimations,
    ),
    child: child!,
  ),
  home: Scaffold(body: child),
);

/// Desplazamiento horizontal y opacidad con que se está dibujando el contenido de una pestaña.
({double dx, double opacity}) _tabPose(WidgetTester tester, Finder content) {
  // Cada pestaña va en un Visibility; lo primero que hay debajo es su Opacity con un Transform.
  final tab = find.ancestor(of: content, matching: find.byType(Visibility)).first;
  final wrapper = find.descendant(of: tab, matching: find.byType(Opacity)).first;
  final opacity = tester.widget<Opacity>(wrapper);
  final translate = tester.widget<Transform>(
    find.descendant(of: wrapper, matching: find.byType(Transform)).first,
  );
  return (dx: translate.transform.getTranslation().x, opacity: opacity.opacity);
}

void main() {
  group('pestañas: deslizamiento horizontal', () {
    late AppTabsController controller;
    late GlobalKey<FormState> form0;
    late GlobalKey<FormState> form1;
    late TextEditingController text0;
    late TextEditingController text1;

    setUp(() {
      controller = AppTabsController();
      form0 = GlobalKey<FormState>();
      form1 = GlobalKey<FormState>();
      text0 = TextEditingController();
      text1 = TextEditingController();
    });

    tearDown(() {
      controller.dispose();
      text0.dispose();
      text1.dispose();
    });

    Widget tabs({bool disableAnimations = false}) {
      final items = [
        AppTabItem(
          label: 'Uno',
          child: Form(
            key: form0,
            child: TextFormField(controller: text0, decoration: const InputDecoration(labelText: 'Campo uno')),
          ),
        ),
        AppTabItem(
          label: 'Dos',
          child: Form(
            key: form1,
            child: TextFormField(
              controller: text1,
              decoration: const InputDecoration(labelText: 'Campo dos'),
              validator: (v) => (v == null || v.isEmpty) ? 'Requerido' : null,
            ),
          ),
        ),
        const AppTabItem(label: 'Tres', child: Text('contenido tres')),
      ];
      return _app(
        Column(
          children: [
            AppTabBar(tabs: items, controller: controller),
            AppTabsView(tabs: items, controller: controller),
          ],
        ),
        disableAnimations: disableAnimations,
      );
    }

    testWidgets('la pestaña inicial se ve de entrada, sin animación', (tester) async {
      await tester.pumpWidget(tabs());
      final pose = _tabPose(tester, find.widgetWithText(TextFormField, 'Campo uno'));
      expect(pose.opacity, 1);
      expect(pose.dx, 0);
    });

    testWidgets('al avanzar la nueva pestaña llega desde la derecha y con fundido', (tester) async {
      await tester.pumpWidget(tabs());
      controller.select(1);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 80));

      final mid = _tabPose(tester, find.widgetWithText(TextFormField, 'Campo dos'));
      expect(mid.dx, greaterThan(0), reason: 'entra desde la derecha');
      expect(mid.opacity, inExclusiveRange(0, 1));

      await tester.pumpAndSettle();
      final end = _tabPose(tester, find.widgetWithText(TextFormField, 'Campo dos'));
      expect(end.dx, 0);
      expect(end.opacity, 1);
    });

    testWidgets('al retroceder llega desde la izquierda', (tester) async {
      await tester.pumpWidget(tabs());
      controller.select(2);
      await tester.pumpAndSettle();
      controller.select(0);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 80));
      expect(_tabPose(tester, find.widgetWithText(TextFormField, 'Campo uno')).dx, lessThan(0));
      await tester.pumpAndSettle();
    });

    testWidgets('los campos conservan lo escrito y el estado al cambiar de pestaña', (tester) async {
      await tester.pumpWidget(tabs());
      await tester.enterText(find.widgetWithText(TextFormField, 'Campo uno'), 'hola');

      await tester.tap(find.text('Dos'));
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextFormField, 'Campo dos'), 'mundo');
      await tester.tap(find.text('Tres'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Uno'));
      await tester.pumpAndSettle();

      expect(text0.text, 'hola');
      expect(text1.text, 'mundo');
      expect(find.text('hola'), findsOneWidget);
    });

    testWidgets('validar con una pestaña oculta marca el error y salta a ella con la animación', (tester) async {
      await tester.pumpWidget(tabs());
      // La pestaña 2 está vacía y es obligatoria; estamos en la 1.
      final ok = controller.validate([form0, form1]);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 80));

      expect(ok, isFalse);
      expect(controller.index, 1);
      expect(controller.errors, {1});
      expect(_tabPose(tester, find.widgetWithText(TextFormField, 'Campo dos')).dx, greaterThan(0));
      await tester.pumpAndSettle();
      expect(find.text('Requerido'), findsOneWidget);
    });

    testWidgets('con "quitar animaciones" el cambio es directo', (tester) async {
      await tester.pumpWidget(tabs(disableAnimations: true));
      controller.select(1);
      await tester.pump();
      final pose = _tabPose(tester, find.widgetWithText(TextFormField, 'Campo dos'));
      expect(pose.opacity, 1);
      expect(pose.dx, 0);
    });

    testWidgets('no deja ninguna animación corriendo al terminar', (tester) async {
      await tester.pumpWidget(tabs());
      controller.select(2);
      await tester.pumpAndSettle();
      expect(tester.hasRunningAnimations, isFalse);
    });
  });

  group('ilustraciones', () {
    test('el ícono decide la ilustración', () {
      AppIllustrationKind k(IconData i, {bool error = false}) => AppEmptyState.kindFor(i, error: error);
      expect(k(Icons.cloud_off_outlined), AppIllustrationKind.error);
      expect(k(Icons.inbox_outlined, error: true), AppIllustrationKind.error);
      expect(k(Icons.lock_outline), AppIllustrationKind.locked);
      expect(k(Icons.inbox_outlined), AppIllustrationKind.empty);
      expect(k(Icons.search_off), AppIllustrationKind.empty);
      expect(k(Icons.warehouse_outlined), AppIllustrationKind.generic);
      expect(k(Icons.settings_outlined), AppIllustrationKind.generic);
    });

    for (final kind in AppIllustrationKind.values) {
      for (final mode in ThemeMode.values.where((m) => m != ThemeMode.system)) {
        testWidgets('${kind.name} se dibuja en ${mode.name} y termina de animarse', (tester) async {
          await tester.pumpWidget(_app(Center(child: AppIllustration(kind: kind)), mode: mode));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          final paint = find.descendant(of: find.byType(AppIllustration), matching: find.byType(CustomPaint));
          expect(paint, findsWidgets);
          expect(tester.hasRunningAnimations, isFalse);
        });
      }
    }

    testWidgets('sin "quitar animaciones" no hay escala; con ella sale directa', (tester) async {
      await tester.pumpWidget(
        _app(const Center(child: AppIllustration(kind: AppIllustrationKind.empty)), disableAnimations: true),
      );
      expect(find.byType(TweenAnimationBuilder<double>), findsNothing);
    });

    AppEmptyState state(IconData icon, {bool error = false}) => AppEmptyState(
      icon: icon,
      title: 'Título',
      message: 'Mensaje',
      error: error,
      action: AppButton(label: 'Reintentar', onPressed: () {}),
    );

    testWidgets('AppEmptyState dibuja la ilustración del ícono y, en el genérico, el ícono como insignia', (
      tester,
    ) async {
      for (final (icon, kind, badge) in [
        (Icons.cloud_off_outlined, AppIllustrationKind.error, false),
        (Icons.lock_outline, AppIllustrationKind.locked, false),
        (Icons.inbox_outlined, AppIllustrationKind.empty, false),
        (Icons.warehouse_outlined, AppIllustrationKind.generic, true),
      ]) {
        await tester.pumpWidget(_app(state(icon)));
        await tester.pumpAndSettle();
        expect(tester.widget<AppIllustration>(find.byType(AppIllustration)).kind, kind);
        expect(find.byIcon(icon), badge ? findsOneWidget : findsNothing);
        expect(find.text('Título'), findsOneWidget);
        expect(find.text('Reintentar'), findsOneWidget);
      }
    });

    testWidgets('el parámetro illustration manda sobre el ícono', (tester) async {
      await tester.pumpWidget(
        _app(
          const AppEmptyState(
            icon: Icons.cloud_off_outlined,
            title: 'Sin acceso',
            illustration: AppIllustrationKind.locked,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.widget<AppIllustration>(find.byType(AppIllustration)).kind, AppIllustrationKind.locked);
    });

    for (final dark in [false, true]) {
      testWidgets('el estado vacío cabe a 320 px con letra 1.3x (${dark ? 'oscuro' : 'claro'})', (tester) async {
        tester.view.physicalSize = const Size(320, 568);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        for (final icon in [Icons.cloud_off_outlined, Icons.lock_outline, Icons.inbox_outlined, Icons.warehouse_outlined]) {
          await tester.pumpWidget(
            _app(state(icon), mode: dark ? ThemeMode.dark : ThemeMode.light, textScale: 1.3),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull, reason: '$icon');
        }
      });
    }
  });
}
