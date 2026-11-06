import 'package:app_novik/core/network/connection_monitor.dart';
import 'package:app_novik/presentation/components/components.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _app(
  Widget child, {
  ThemeMode mode = ThemeMode.light,
  double textScale = 1,
  bool disableAnimations = false,
}) => MaterialApp(
  themeMode: mode,
  theme: ThemeData(colorSchemeSeed: Colors.orange),
  darkTheme: ThemeData(colorSchemeSeed: Colors.orange, brightness: Brightness.dark),
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(
      textScaler: TextScaler.linear(textScale),
      disableAnimations: disableAnimations,
    ),
    child: child!,
  ),
  home: Scaffold(body: child),
);

double _scaleOf(WidgetTester tester, Finder of) =>
    tester.widget<AnimatedScale>(find.ancestor(of: of, matching: find.byType(AnimatedScale)).first).scale;

void main() {
  group('respuesta al tocar', () {
    testWidgets('el botón se hunde al presionar y vuelve al soltar', (tester) async {
      var taps = 0;
      await tester.pumpWidget(_app(AppButton(label: 'Guardar', onPressed: () => taps++)));
      expect(_scaleOf(tester, find.text('Guardar')), 1);

      final gesture = await tester.startGesture(tester.getCenter(find.text('Guardar')));
      await tester.pump(const Duration(milliseconds: 200));
      expect(_scaleOf(tester, find.text('Guardar')), lessThan(1));

      await gesture.up();
      await tester.pumpAndSettle();
      expect(_scaleOf(tester, find.text('Guardar')), 1);
      expect(taps, 1, reason: 'el efecto no debe quitar el toque');
    });

    testWidgets('si el dedo se arrastra (scroll) deja de hundirse', (tester) async {
      await tester.pumpWidget(_app(AppButton(label: 'Guardar', onPressed: () {})));
      final gesture = await tester.startGesture(tester.getCenter(find.text('Guardar')));
      await tester.pump(const Duration(milliseconds: 200));
      await gesture.moveBy(const Offset(0, 40));
      await tester.pump(const Duration(milliseconds: 200));
      expect(_scaleOf(tester, find.text('Guardar')), 1);
      await gesture.up();
    });

    testWidgets('un botón deshabilitado no se hunde', (tester) async {
      await tester.pumpWidget(_app(const AppButton(label: 'Guardar', onPressed: null)));
      expect(find.byType(AnimatedScale), findsNothing);
    });

    testWidgets('la tarjeta con toque se hunde y la que no, no', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        _app(
          Column(
            children: [
              AppListCard(title: 'Con toque', onTap: () => taps++),
              const AppListCard(title: 'Sin toque'),
            ],
          ),
        ),
      );
      final gesture = await tester.startGesture(tester.getCenter(find.text('Con toque')));
      await tester.pump(const Duration(milliseconds: 200));
      expect(_scaleOf(tester, find.text('Con toque')), lessThan(1));
      await gesture.up();
      await tester.pumpAndSettle();
      expect(taps, 1);
      expect(
        find.ancestor(of: find.text('Sin toque'), matching: find.byType(AnimatedScale)),
        findsNothing,
      );
    });

    testWidgets('con "quitar animaciones" no hay efecto', (tester) async {
      await tester.pumpWidget(
        _app(AppButton(label: 'Guardar', onPressed: () {}), disableAnimations: true),
      );
      expect(find.byType(AnimatedScale), findsNothing);
    });
  });

  group('éxito', () {
    testWidgets('el check se dibuja y termina completo', (tester) async {
      await tester.pumpWidget(_app(const Center(child: AppSuccessCheck())));
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.bySemanticsLabel('Listo'), findsOneWidget);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });

  group('estados vacíos y de error', () {
    testWidgets('un error usa los colores de error y uno vacío los de la marca', (tester) async {
      await tester.pumpWidget(
        _app(
          const Column(
            children: [
              Expanded(
                child: AppEmptyState(icon: Icons.cloud_off_outlined, title: 'No se pudo cargar'),
              ),
              Expanded(child: AppEmptyState(icon: Icons.inbox_outlined, title: 'Sin resultados')),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();
      final scheme = Theme.of(tester.element(find.text('Sin resultados'))).colorScheme;
      Color iconColor(IconData icon) => tester.widget<Icon>(find.byIcon(icon)).color!;
      expect(iconColor(Icons.cloud_off_outlined), scheme.error);
      expect(iconColor(Icons.inbox_outlined), scheme.primary);
    });

    testWidgets('se ve bien en modo oscuro y con letra grande, sin desbordes', (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        _app(
          AppEmptyState(
            icon: Icons.cloud_off_outlined,
            title: 'No se pudo cargar el reporte',
            message: 'Revisa tu conexión a internet e inténtalo de nuevo en unos segundos.',
            action: AppButton(label: 'Reintentar', icon: Icons.refresh, onPressed: () {}),
          ),
          mode: ThemeMode.dark,
          textScale: 1.6,
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Reintentar'), findsOneWidget);
    });
  });

  group('modo oscuro y letra grande', () {
    testWidgets('las tarjetas de lista con textos largos no se desbordan', (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        _app(
          SingleChildScrollView(
            child: Column(
              children: [
                for (var i = 1; i <= 3; i++)
                  Padding(
                    padding: const EdgeInsets.all(8),
                    child: AppListCard(
                      number: i,
                      title: 'Distribuidora Comercial del Sur Sociedad Anónima Cerrada',
                      lines: const ['RUC 20123456789 · Código CL-000123', 'Ejecutivo: María Fernanda Quispe'],
                      trailingTitle: 'S/ 12,345.67',
                      trailingCaption: 'Activo',
                      actions: [
                        AppActionButton(type: AppActionType.view, onPressed: () {}),
                        AppActionButton(type: AppActionType.edit, onPressed: () {}),
                      ],
                      onTap: () {},
                    ),
                  ),
              ],
            ),
          ),
          mode: ThemeMode.dark,
          textScale: 1.3,
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('los botones de acción conservan un área táctil de al menos 48 px', (tester) async {
      await tester.pumpWidget(
        _app(Center(child: AppActionButton(type: AppActionType.view, onPressed: () {}))),
      );
      final size = tester.getSize(find.byType(IconButton));
      expect(size.width, greaterThanOrEqualTo(48));
      expect(size.height, greaterThanOrEqualTo(48));
    });
  });

  group('aviso de sin conexión', () {
    late ValueNotifier<bool> offline;
    setUp(() => offline = ValueNotifier(false));
    tearDown(() => offline.dispose());

    Widget banner() => MaterialApp(
      home: Scaffold(
        body: AppConnectionBanner(offline: offline, child: const Center(child: Text('contenido'))),
      ),
    );

    testWidgets('aparece cuando se pierde la conexión y se va al volver', (tester) async {
      await tester.pumpWidget(banner());
      expect(find.textContaining('Sin conexión'), findsNothing);

      offline.value = true;
      await tester.pumpAndSettle();
      expect(find.textContaining('Sin conexión'), findsOneWidget);
      expect(find.text('contenido'), findsOneWidget);

      offline.value = false;
      await tester.pumpAndSettle();
      expect(find.textContaining('Sin conexión'), findsNothing);
    });

    test('el monitor global se enciende al perder la conexión y se apaga al alcanzar el servidor', () {
      ConnectionMonitor.offline.value = false;
      ConnectionMonitor.lostConnection();
      expect(ConnectionMonitor.offline.value, isTrue);
      ConnectionMonitor.reachedServer();
      expect(ConnectionMonitor.offline.value, isFalse);
    });
  });
}
