import 'package:app_novik/presentation/components/components.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child, {bool disableAnimations = false}) => MaterialApp(
  home: MediaQuery(
    data: MediaQueryData(disableAnimations: disableAnimations),
    child: Scaffold(body: child),
  ),
);

double _opacity(WidgetTester tester, Finder of) => tester
    .widget<Opacity>(
      find.ancestor(of: of, matching: find.byType(Opacity)).first,
    )
    .opacity;

void main() {
  testWidgets('AppEntrance aparece con fundido y termina visible', (tester) async {
    await tester.pumpWidget(_wrap(const AppEntrance(child: Text('hola'))));
    expect(_opacity(tester, find.text('hola')), 0);

    await tester.pump(const Duration(milliseconds: 150));
    final mid = _opacity(tester, find.text('hola'));
    expect(mid, greaterThan(0));
    expect(mid, lessThan(1));

    await tester.pumpAndSettle();
    expect(_opacity(tester, find.text('hola')), 1);
  });

  testWidgets('AppEntrance respeta el retraso', (tester) async {
    await tester.pumpWidget(
      _wrap(
        const AppEntrance(delay: Duration(milliseconds: 300), child: Text('tarde')),
      ),
    );
    await tester.pump(const Duration(milliseconds: 200));
    expect(_opacity(tester, find.text('tarde')), 0);
    await tester.pumpAndSettle();
    expect(_opacity(tester, find.text('tarde')), 1);
  });

  testWidgets('con "quitar animaciones" el contenido sale directo', (tester) async {
    await tester.pumpWidget(
      _wrap(const AppEntrance(child: Text('directo')), disableAnimations: true),
    );
    expect(find.byType(Opacity), findsNothing);
    expect(find.text('directo'), findsOneWidget);
  });

  testWidgets('AppFadeSwitcher cambia de contenido con fundido', (tester) async {
    Widget build(String key) => _wrap(
      AppFadeSwitcher(child: Text(key, key: ValueKey(key))),
    );
    await tester.pumpWidget(build('uno'));
    await tester.pumpWidget(build('dos'));
    await tester.pump(const Duration(milliseconds: 100));
    // A mitad del cambio conviven ambos.
    expect(find.text('uno'), findsOneWidget);
    expect(find.text('dos'), findsOneWidget);
    await tester.pumpAndSettle();
    expect(find.text('uno'), findsNothing);
    expect(find.text('dos'), findsOneWidget);
  });

  testWidgets('AppCardList: las tarjetas entran escalonadas y no repiten al reconstruir', (
    tester,
  ) async {
    final items = [for (var i = 0; i < 3; i++) 'Item $i'];
    Widget list() => _wrap(
      AppCardList<String>(
        items: items,
        itemBuilder: (_, item, n) => Text(item),
      ),
    );

    await tester.pumpWidget(list());
    expect(_opacity(tester, find.text('Item 0')), 0);
    await tester.pump(const Duration(milliseconds: 120));
    // La segunda empieza después que la primera.
    expect(
      _opacity(tester, find.text('Item 0')),
      greaterThan(_opacity(tester, find.text('Item 2'))),
    );
    await tester.pumpAndSettle();
    expect(_opacity(tester, find.text('Item 2')), 1);

    // Reconstruir con la misma lista no vuelve a animar.
    await tester.pumpWidget(list());
    await tester.pump();
    expect(_opacity(tester, find.text('Item 0')), 1);
  });

  testWidgets('AppCardList: una lista nueva vuelve a entrar con animación', (tester) async {
    Widget list(List<String> items) => _wrap(
      AppCardList<String>(items: items, itemBuilder: (_, item, n) => Text(item)),
    );
    await tester.pumpWidget(list(['A', 'B']));
    await tester.pumpAndSettle();
    await tester.pumpWidget(list(['C', 'D']));
    await tester.pump();
    expect(_opacity(tester, find.text('C')), 0);
    await tester.pumpAndSettle();
    expect(_opacity(tester, find.text('C')), 1);
  });

  testWidgets('AppLoadingScreen muestra el logo y no rompe sin animaciones', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: AppLoadingScreen()));
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('N'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    await tester.pumpWidget(
      const MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(disableAnimations: true),
          child: AppLoadingScreen(),
        ),
      ),
    );
    expect(find.text('N'), findsOneWidget);
  });

  testWidgets('AppCountUp corre hasta el valor final', (tester) async {
    await tester.pumpWidget(
      _wrap(AppCountUp(value: 1000, format: (v) => 'S/ ${v.round()}')),
    );
    expect(find.text('S/ 0'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 300));
    final mid = int.parse(
      (tester.widget<Text>(find.byType(Text)).data!).replaceAll('S/ ', ''),
    );
    expect(mid, greaterThan(0));
    expect(mid, lessThan(1000));
    await tester.pumpAndSettle();
    expect(find.text('S/ 1000'), findsOneWidget);
  });

  testWidgets('AppCountUp sin animaciones muestra el valor directo', (tester) async {
    await tester.pumpWidget(
      _wrap(
        AppCountUp(value: 42, format: (v) => 'n=${v.round()}'),
        disableAnimations: true,
      ),
    );
    expect(find.text('n=42'), findsOneWidget);
  });

  testWidgets('AppSkeletonList dibuja tarjetas de carga y se anima', (tester) async {
    await tester.pumpWidget(_wrap(const AppSkeletonList(count: 3)));
    expect(find.byType(AppSkeletonBox), findsWidgets);
    expect(find.bySemanticsLabel('Cargando'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(ShaderMask), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}
