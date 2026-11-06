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

/// El progreso (0→1) con el que se está dibujando la gráfica que contiene `of`.
double _progress(WidgetTester tester, Type chart) {
  final paint = tester.widget<CustomPaint>(
    find.descendant(of: find.byType(chart), matching: find.byType(CustomPaint)).first,
  );
  return ((paint.painter as dynamic).progress as Animation<double>).value;
}

const _labels = ['1', '2', '3', '4'];
AppAreaChart _area(List<double> values) => AppAreaChart(
  labels: _labels,
  series: [AreaSeries(name: 'Soles', color: Colors.green, values: values)],
  format: (v) => 'S/ ${v.round()}',
);

AppGroupedBarChart _bars(List<double> current) => AppGroupedBarChart(
  labels: _labels,
  previous: const [10, 20, 30, 40],
  current: current,
);

double _contrast(Color a, Color b) {
  final l1 = a.computeLuminance();
  final l2 = b.computeLuminance();
  final hi = l1 > l2 ? l1 : l2;
  final lo = l1 > l2 ? l2 : l1;
  return (hi + 0.05) / (lo + 0.05);
}

void main() {
  group('gráfica de área', () {
    testWidgets('se dibuja de izquierda a derecha y termina completa', (tester) async {
      await tester.pumpWidget(_app(_area(const [1, 5, 3, 8])));
      expect(_progress(tester, AppAreaChart), 0);

      await tester.pump(const Duration(milliseconds: 400));
      final mid = _progress(tester, AppAreaChart);
      expect(mid, greaterThan(0));
      expect(mid, lessThan(1));

      await tester.pumpAndSettle();
      expect(_progress(tester, AppAreaChart), 1);
      expect(tester.takeException(), isNull);
    });

    testWidgets('con los mismos datos no se vuelve a dibujar', (tester) async {
      await tester.pumpWidget(_app(_area(const [1, 5, 3, 8])));
      await tester.pumpAndSettle();
      await tester.pumpWidget(_app(_area(const [1, 5, 3, 8])));
      await tester.pump();
      expect(_progress(tester, AppAreaChart), 1);
    });

    testWidgets('cuando cambian los datos arranca de nuevo', (tester) async {
      await tester.pumpWidget(_app(_area(const [1, 5, 3, 8])));
      await tester.pumpAndSettle();

      await tester.pumpWidget(_app(_area(const [2, 2, 9, 1])));
      await tester.pump();
      expect(_progress(tester, AppAreaChart), lessThan(1));
      await tester.pumpAndSettle();
      expect(_progress(tester, AppAreaChart), 1);
    });

    testWidgets('con "quitar animaciones" sale completa de entrada', (tester) async {
      await tester.pumpWidget(_app(_area(const [1, 5, 3, 8]), disableAnimations: true));
      expect(_progress(tester, AppAreaChart), 1);
    });

    testWidgets('tocar la gráfica marca un punto sin romper el dibujo', (tester) async {
      await tester.pumpWidget(_app(_area(const [1, 5, 3, 8])));
      await tester.pumpAndSettle();
      await tester.tapAt(tester.getCenter(find.byType(AppAreaChart)));
      await tester.pumpAndSettle();
      expect(find.textContaining('Soles:'), findsOneWidget);
    });
  });

  group('barras', () {
    testWidgets('las barras agrupadas crecen y terminan completas', (tester) async {
      await tester.pumpWidget(_app(_bars(const [5, 15, 35, 25])));
      expect(_progress(tester, AppGroupedBarChart), 0);
      await tester.pump(const Duration(milliseconds: 300));
      expect(_progress(tester, AppGroupedBarChart), inExclusiveRange(0, 1));
      await tester.pumpAndSettle();
      expect(_progress(tester, AppGroupedBarChart), 1);
    });

    testWidgets('al cambiar los datos vuelven a crecer', (tester) async {
      await tester.pumpWidget(_app(_bars(const [5, 15, 35, 25])));
      await tester.pumpAndSettle();
      await tester.pumpWidget(_app(_bars(const [9, 9, 9, 9])));
      await tester.pump();
      expect(_progress(tester, AppGroupedBarChart), lessThan(1));
      await tester.pumpAndSettle();
    });

    testWidgets('la lista de barras se llena hasta su proporción', (tester) async {
      await tester.pumpWidget(
        _app(
          const AppBarList(
            items: [(label: 'Mayor', value: 100), (label: 'Mitad', value: 50)],
          ),
        ),
      );
      double bar(int i) => tester.widget<LinearProgressIndicator>(find.byType(LinearProgressIndicator).at(i)).value!;
      expect(bar(0), 0);
      await tester.pumpAndSettle();
      expect(bar(0), closeTo(1, 0.001));
      expect(bar(1), closeTo(0.5, 0.001));
    });

    testWidgets('la lista de barras sin animaciones sale llena', (tester) async {
      await tester.pumpWidget(
        _app(
          const AppBarList(items: [(label: 'Único', value: 80)]),
          disableAnimations: true,
        ),
      );
      await tester.pump();
      expect(
        tester.widget<LinearProgressIndicator>(find.byType(LinearProgressIndicator)).value,
        closeTo(1, 0.001),
      );
    });
  });

  group('esqueletos de detalle y modal', () {
    Future<void> checkNoOverflow(WidgetTester tester, Widget skeleton) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(_app(skeleton));
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.bySemanticsLabel('Cargando'), findsOneWidget);
      expect(tester.takeException(), isNull);
    }

    testWidgets('AppSkeletonDetail dentro de una columna sin altura fija', (tester) async {
      await checkNoOverflow(tester, const SingleChildScrollView(child: AppSkeletonDetail()));
    });

    testWidgets('AppSkeletonForm dentro de un modal', (tester) async {
      await checkNoOverflow(tester, const Padding(padding: EdgeInsets.all(16), child: AppSkeletonForm(fields: 5)));
    });

    testWidgets('AppSkeletonResults', (tester) async {
      await checkNoOverflow(tester, const Padding(padding: EdgeInsets.all(16), child: AppSkeletonResults()));
    });

    testWidgets('AppSkeletonReport llena la pantalla de Reportes', (tester) async {
      await checkNoOverflow(tester, const AppSkeletonReport());
    });

    testWidgets('los esqueletos aguantan modo oscuro y letra grande', (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        _app(
          const SingleChildScrollView(
            child: Column(children: [AppSkeletonDetail(), AppSkeletonForm(), AppSkeletonResults()]),
          ),
          mode: ThemeMode.dark,
          textScale: 1.3,
        ),
      );
      await tester.pump(const Duration(milliseconds: 500));
      expect(tester.takeException(), isNull);
    });

    testWidgets('sin animaciones el esqueleto no se mueve (no hay brillo)', (tester) async {
      await tester.pumpWidget(_app(const AppSkeletonForm(), disableAnimations: true));
      expect(find.byType(ShaderMask), findsNothing);
    });
  });

  group('modo oscuro y letra grande', () {
    testWidgets('gráficas, métricas e insignias no se desbordan', (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        _app(
          SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _area(const [1, 5, 3, 8]),
                const SizedBox(height: 12),
                _bars(const [5, 15, 35, 25]),
                const SizedBox(height: 12),
                const AppBarList(
                  items: [
                    (label: 'Un producto con un nombre bastante largo para ver cómo corta', value: 123456.78),
                    (label: 'Otro', value: 9876),
                  ],
                ),
                const SizedBox(height: 12),
                const Row(
                  children: [
                    Expanded(child: AppMetricCard(label: 'Total Soles', value: 'S/. 1,234,567.89', color: Color(0xFF16A34A))),
                    SizedBox(width: 8),
                    Expanded(child: AppMetricCard(label: 'Total Dólares', value: r'$ 98,765.43', color: Color(0xFFD97706))),
                  ],
                ),
                const SizedBox(height: 12),
                const Wrap(
                  spacing: 8,
                  children: [
                    AppStatusBadge(label: 'Activo', tone: AppBadgeTone.success),
                    AppStatusBadge(label: 'Pendiente', tone: AppBadgeTone.warning),
                    AppStatusBadge(label: 'Anulado', tone: AppBadgeTone.danger),
                    AppVariationBadge(value: 31.5),
                    AppVariationBadge(value: -5),
                  ],
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

    for (final brightness in Brightness.values) {
      testWidgets('el título de una métrica de color se lee en modo ${brightness.name} (contraste AA)', (tester) async {
        for (final accent in const [Color(0xFF16A34A), Color(0xFFD97706), Color(0xFFE11D48), Color(0xFF0D9488)]) {
          await tester.pumpWidget(
            _app(
              Center(child: AppMetricCard(label: 'Total', value: '1', color: accent)),
              mode: brightness == Brightness.dark ? ThemeMode.dark : ThemeMode.light,
            ),
          );
          final text = tester.widget<Text>(find.text('Total'));
          final background = Theme.of(tester.element(find.text('Total'))).colorScheme.surfaceContainerLowest;
          expect(
            _contrast(text.style!.color!, background),
            greaterThanOrEqualTo(4.5),
            reason: 'color ${accent.toARGB32().toRadixString(16)} en ${brightness.name}',
          );
        }
      });
    }

    testWidgets('el aro de los puntos marcados sigue el fondo, no es blanco fijo', (tester) async {
      await tester.pumpWidget(_app(_area(const [1, 5, 3, 8]), mode: ThemeMode.dark));
      await tester.pumpAndSettle();
      final scheme = Theme.of(tester.element(find.byType(AppAreaChart))).colorScheme;
      final paint = tester.widget<CustomPaint>(
        find.descendant(of: find.byType(AppAreaChart), matching: find.byType(CustomPaint)).first,
      );
      expect((paint.painter as dynamic).dotRing, scheme.surface);
    });
  });
}
