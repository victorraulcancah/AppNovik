import 'package:app_novik/presentation/components/components.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _app(Widget child, {bool disableAnimations = false}) => MaterialApp(
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(disableAnimations: disableAnimations),
    child: child!,
  ),
  home: Scaffold(body: Column(children: [child, const Text('debajo')])),
);

void main() {
  group('AppActiveFilters', () {
    testWidgets('sin filtros no ocupa lugar', (tester) async {
      await tester.pumpWidget(_app(const AppActiveFilters(filters: [])));
      await tester.pumpAndSettle();
      expect(find.byType(InputChip), findsNothing);
      expect(tester.getSize(find.byType(AppActiveFilters)).height, 0);
    });

    testWidgets('muestra un chip por filtro y cada "x" lo quita', (tester) async {
      final removed = <String>[];
      await tester.pumpWidget(
        _app(
          AppActiveFilters(
            filters: [
              AppActiveFilter(id: 'a', label: 'Estado: Activo', onRemove: () => removed.add('a')),
              AppActiveFilter(id: 'b', label: 'Categoría: Mayorista', onRemove: () => removed.add('b')),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Estado: Activo'), findsOneWidget);
      expect(find.text('Categoría: Mayorista'), findsOneWidget);

      await tester.tap(find.byTooltip('Quitar Estado: Activo'));
      await tester.pump();
      expect(removed, ['a']);
    });

    testWidgets('"Limpiar" sale solo con dos o más filtros y solo si se da onClear', (tester) async {
      var cleared = 0;
      AppActiveFilter f(String id) => AppActiveFilter(id: id, label: 'Filtro $id', onRemove: () {});

      await tester.pumpWidget(_app(AppActiveFilters(filters: [f('a')], onClear: () => cleared++)));
      await tester.pumpAndSettle();
      expect(find.text('Limpiar'), findsNothing);

      await tester.pumpWidget(_app(AppActiveFilters(filters: [f('a'), f('b')], onClear: () => cleared++)));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Limpiar'));
      expect(cleared, 1);

      await tester.pumpWidget(_app(AppActiveFilters(filters: [f('a'), f('b')])));
      await tester.pumpAndSettle();
      expect(find.text('Limpiar'), findsNothing);
    });

    testWidgets('la fila crece y se encoge con animación, y no deja animaciones pendientes', (tester) async {
      AppActiveFilter f(String id) => AppActiveFilter(id: id, label: 'Filtro $id', onRemove: () {});

      await tester.pumpWidget(_app(const AppActiveFilters(filters: [])));
      await tester.pumpWidget(_app(AppActiveFilters(filters: [f('a')])));
      await tester.pump(const Duration(milliseconds: 80));
      final mid = tester.getSize(find.byType(AppActiveFilters)).height;
      expect(mid, greaterThan(0));
      expect(mid, lessThan(44));

      // Termina sola (pumpAndSettle no se queda esperando una animación continua).
      await tester.pumpAndSettle();
      expect(tester.getSize(find.byType(AppActiveFilters)).height, 44);

      await tester.pumpWidget(_app(const AppActiveFilters(filters: [])));
      await tester.pumpAndSettle();
      expect(tester.getSize(find.byType(AppActiveFilters)).height, 0);
    });

    testWidgets('cada chip entra con un fundido', (tester) async {
      await tester.pumpWidget(
        _app(AppActiveFilters(filters: [AppActiveFilter(id: 'a', label: 'Filtro a', onRemove: () {})])),
      );
      await tester.pump(const Duration(milliseconds: 60));
      final opacity = tester
          .widget<Opacity>(find.ancestor(of: find.byType(InputChip), matching: find.byType(Opacity)).first)
          .opacity;
      expect(opacity, greaterThan(0));
      expect(opacity, lessThan(1));
      await tester.pumpAndSettle();
    });

    testWidgets('con "quitar animaciones" aparece directo', (tester) async {
      await tester.pumpWidget(
        _app(
          AppActiveFilters(filters: [AppActiveFilter(id: 'a', label: 'Filtro a', onRemove: () {})]),
          disableAnimations: true,
        ),
      );
      expect(find.byType(AnimatedSize), findsNothing);
      expect(find.byType(Opacity), findsNothing);
      expect(find.text('Filtro a'), findsOneWidget);
    });

    testWidgets('con muchos filtros la fila se desplaza hacia el lado sin desbordar', (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        _app(
          AppActiveFilters(
            filters: [
              for (var i = 0; i < 8; i++)
                AppActiveFilter(id: '$i', label: 'Un filtro con nombre largo $i', onRemove: () {}),
            ],
            onClear: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Limpiar'), findsOneWidget);
    });
  });

  group('AppSearchBar: contador de filtros', () {
    Widget bar({int count = 0, bool active = false}) => _app(
      AppSearchBar(onFilter: () {}, filterCount: count, filterActive: active),
    );

    testWidgets('sin filtros no hay insignia', (tester) async {
      await tester.pumpWidget(bar());
      expect(tester.widget<Badge>(find.byType(Badge)).isLabelVisible, isFalse);
    });

    testWidgets('muestra cuántos filtros hay puestos', (tester) async {
      await tester.pumpWidget(bar(count: 3));
      expect(tester.widget<Badge>(find.byType(Badge)).isLabelVisible, isTrue);
      expect(find.descendant(of: find.byType(Badge), matching: find.text('3')), findsOneWidget);
    });

    testWidgets('sin contador, filterActive sigue marcando el botón con un punto', (tester) async {
      await tester.pumpWidget(bar(active: true));
      final badge = tester.widget<Badge>(find.byType(Badge));
      expect(badge.isLabelVisible, isTrue);
      expect(badge.label, isNull);
    });
  });
}
