import 'package:app_novik/presentation/components/components.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Una pantalla de prueba: una lista de tres elementos; al tocar uno se pide su detalle con
/// `showAppModal(pane: ...)` y lo que se decide en él se anota en [results].
class _Harness extends StatefulWidget {
  final List<bool?> results;

  const _Harness({required this.results});

  @override
  State<_Harness> createState() => _HarnessState();
}

class _HarnessState extends State<_Harness> {
  final pane = AppPaneController();

  @override
  void dispose() {
    pane.dispose();
    super.dispose();
  }

  Future<void> _open(int id) async {
    final result = await showAppModal(
      context,
      pane: pane,
      paneId: id,
      title: 'Detalle $id',
      subtitle: 'Sub $id',
      primaryLabel: 'Hacer $id',
      secondaryLabel: 'Cerrar',
      child: Text('Contenido $id'),
    );
    widget.results.add(result);
  }

  @override
  Widget build(BuildContext context) {
    return AppMasterDetail(
      controller: pane,
      emptyTitle: 'Selecciona un elemento',
      listBuilder: (context) => ListView(
        children: [
          for (final id in [1, 2, 3])
            AppListCard(
              title: 'Elemento $id',
              selected: pane.selectedId == id,
              onTap: () => _open(id),
            ),
        ],
      ),
    );
  }
}

Future<List<bool?>> _pump(
  WidgetTester tester, {
  Size size = const Size(1100, 800),
  bool disableAnimations = false,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final results = <bool?>[];
  await tester.pumpWidget(
    MaterialApp(
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: disableAnimations),
        child: child!,
      ),
      home: Scaffold(body: _Harness(results: results)),
    ),
  );
  await tester.pumpAndSettle();
  return results;
}

void main() {
  group('AppMasterDetail en tablet (dos paneles)', () {
    testWidgets('sin selección el panel derecho muestra el estado vacío', (tester) async {
      await _pump(tester);
      expect(find.text('Selecciona un elemento'), findsOneWidget);
      expect(find.text('Elemento 1'), findsOneWidget);
    });

    testWidgets('tocar un elemento muestra su detalle a la derecha, sin abrir un modal', (tester) async {
      await _pump(tester);

      await tester.tap(find.text('Elemento 2'));
      await tester.pumpAndSettle();

      expect(find.text('Contenido 2'), findsOneWidget);
      expect(find.text('Detalle 2'), findsOneWidget);
      expect(find.text('Selecciona un elemento'), findsNothing);
      // No hay diálogo ni hoja encima: el detalle es parte de la pantalla.
      expect(find.byType(Dialog), findsNothing);
      expect(find.byType(BottomSheet), findsNothing);
      // Y queda a la derecha de la lista.
      final list = tester.getTopLeft(find.text('Elemento 2'));
      final detail = tester.getTopLeft(find.text('Contenido 2'));
      expect(detail.dx, greaterThan(list.dx + 300));
    });

    testWidgets('el elemento elegido se resalta en la lista', (tester) async {
      await _pump(tester);
      await tester.tap(find.text('Elemento 1'));
      await tester.pumpAndSettle();

      Color border(String title) {
        final material = tester.widget<Material>(
          find
              .ancestor(of: find.text(title), matching: find.byType(Material))
              .first,
        );
        return (material.shape as RoundedRectangleBorder).side.color;
      }

      final scheme = Theme.of(tester.element(find.text('Elemento 1'))).colorScheme;
      expect(border('Elemento 1'), scheme.primary);
      expect(border('Elemento 2'), isNot(scheme.primary));
    });

    testWidgets('elegir otro elemento reemplaza el detalle', (tester) async {
      final results = await _pump(tester);
      await tester.tap(find.text('Elemento 1'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Elemento 3'));
      await tester.pumpAndSettle();

      expect(find.text('Contenido 1'), findsNothing);
      expect(find.text('Contenido 3'), findsOneWidget);
      // El primero quedó sin respuesta (null) al elegir otro.
      expect(results, [null]);
    });

    testWidgets('la acción principal del panel devuelve true y vacía el panel', (tester) async {
      final results = await _pump(tester);
      await tester.tap(find.text('Elemento 2'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Hacer 2'));
      await tester.pumpAndSettle();

      expect(results, [true]);
      expect(find.text('Contenido 2'), findsNothing);
      expect(find.text('Selecciona un elemento'), findsOneWidget);
    });

    testWidgets('"Cerrar" vacía el panel y responde null', (tester) async {
      final results = await _pump(tester);
      await tester.tap(find.text('Elemento 1'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Cerrar'));
      await tester.pumpAndSettle();

      expect(results, [null]);
      expect(find.text('Selecciona un elemento'), findsOneWidget);
    });

    testWidgets('el pie de acciones queda abajo del panel', (tester) async {
      await _pump(tester);
      await tester.tap(find.text('Elemento 1'));
      await tester.pumpAndSettle();

      final button = tester.getBottomLeft(find.text('Hacer 1'));
      expect(button.dy, greaterThan(700), reason: 'pegado al borde inferior de una pantalla de 800');
    });

    testWidgets('con "quitar animaciones" el detalle aparece directo', (tester) async {
      await _pump(tester, disableAnimations: true);
      await tester.tap(find.text('Elemento 1'));
      await tester.pumpAndSettle();
      expect(find.text('Contenido 1'), findsOneWidget);
    });

    testWidgets('al pasar a un solo panel (girar el equipo) el detalle abierto se descarta', (tester) async {
      final results = await _pump(tester);
      await tester.tap(find.text('Elemento 1'));
      await tester.pumpAndSettle();

      tester.view.physicalSize = const Size(400, 800);
      await tester.pumpAndSettle();

      expect(results, [null]);
      expect(find.text('Contenido 1'), findsNothing);
      expect(find.text('Elemento 1'), findsOneWidget);
    });
  });

  group('AppMasterDetail en celular (un panel)', () {
    testWidgets('solo se ve la lista y el detalle abre el modal de siempre', (tester) async {
      await _pump(tester, size: const Size(400, 800));
      expect(find.text('Selecciona un elemento'), findsNothing);

      await tester.tap(find.text('Elemento 2'));
      await tester.pumpAndSettle();

      expect(find.text('Contenido 2'), findsOneWidget);
      expect(find.byType(BottomSheet), findsOneWidget);
    });

    testWidgets('el modal devuelve la respuesta como siempre', (tester) async {
      final results = await _pump(tester, size: const Size(400, 800));
      await tester.tap(find.text('Elemento 2'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Hacer 2'));
      await tester.pumpAndSettle();

      expect(results, [true]);
      expect(find.byType(BottomSheet), findsNothing);
    });

    testWidgets('una tablet en vertical (menos de 840 de ancho) también queda con un solo panel', (tester) async {
      await _pump(tester, size: const Size(800, 1200));
      expect(find.text('Selecciona un elemento'), findsNothing);
    });
  });

  group('AppPaneController', () {
    test('present devuelve la respuesta de close y limpia la selección', () async {
      final pane = AppPaneController();
      late void Function([bool? result]) close;
      final future = pane.present(
        id: 7,
        builder: (c) {
          close = c;
          return const SizedBox();
        },
      );
      expect(pane.selectedId, 7);
      expect(pane.hasContent, isTrue);

      close(true);

      expect(await future, isTrue);
      expect(pane.selectedId, isNull);
      expect(pane.hasContent, isFalse);
      pane.dispose();
    });

    test('close() sin contenido no falla', () {
      final pane = AppPaneController()..close();
      expect(pane.hasContent, isFalse);
      pane.dispose();
    });
  });
}
