import 'package:app_novik/presentation/widgets/inicio_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _app(Widget child, {bool disableAnimations = false, ThemeMode mode = ThemeMode.light, double scale = 1}) {
  return MaterialApp(
    themeMode: mode,
    theme: ThemeData(colorSchemeSeed: Colors.orange),
    darkTheme: ThemeData(colorSchemeSeed: Colors.orange, brightness: Brightness.dark),
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(disableAnimations: disableAnimations, textScaler: TextScaler.linear(scale)),
      child: child!,
    ),
    home: Scaffold(body: SingleChildScrollView(padding: const EdgeInsets.all(16), child: child)),
  );
}

List<List<Widget>> _rows(int n) => [
  for (var i = 1; i <= n; i++) [InicioCell('Fila $i'), InicioCell('S/ $i')],
];

void main() {
  group('InicioTable con "Ver más"', () {
    testWidgets('con pocas filas las muestra todas y no ofrece "Ver más"', (tester) async {
      await tester.pumpWidget(
        _app(InicioTable(columns: const ['Cliente', 'Monto'], rows: _rows(4), emptyText: 'Vacío')),
      );
      expect(find.text('Fila 4'), findsOneWidget);
      expect(find.textContaining('Ver más'), findsNothing);
    });

    testWidgets('con muchas muestra las primeras y "Ver más (N)" despliega el resto y vuelve a plegar', (tester) async {
      await tester.pumpWidget(
        _app(InicioTable(columns: const ['Cliente', 'Monto'], rows: _rows(9), emptyText: 'Vacío', collapsedRows: 5)),
      );
      expect(find.text('Fila 5'), findsOneWidget);
      expect(find.text('Fila 6'), findsNothing);
      expect(find.text('Ver más (4)'), findsOneWidget);

      await tester.tap(find.text('Ver más (4)'));
      await tester.pumpAndSettle();
      expect(find.text('Fila 9'), findsOneWidget);
      expect(find.text('Ver menos'), findsOneWidget);

      await tester.tap(find.text('Ver menos'));
      await tester.pumpAndSettle();
      expect(find.text('Fila 6'), findsNothing);
    });

    testWidgets('al tocar una fila avisa su posición en la lista completa', (tester) async {
      final tapped = <int>[];
      await tester.pumpWidget(
        _app(
          InicioTable(
            columns: const ['Cliente', 'Monto'],
            rows: _rows(8),
            emptyText: 'Vacío',
            collapsedRows: 3,
            onTap: tapped.add,
          ),
        ),
      );
      await tester.tap(find.text('Fila 2'));
      await tester.tap(find.text('Ver más (5)'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Fila 8'));
      expect(tapped, [1, 7]);
    });

    testWidgets('sin filas muestra el texto de vacío', (tester) async {
      await tester.pumpWidget(_app(const InicioTable(columns: ['A'], rows: [], emptyText: 'Nada por aquí')));
      expect(find.text('Nada por aquí'), findsOneWidget);
    });
  });

  group('anillo de la meta', () {
    testWidgets('muestra el porcentaje y el arco se dibuja hasta terminar', (tester) async {
      await tester.pumpWidget(_app(const InicioGoalRing(percent: 62.5, color: Colors.amber)));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('62.5%'), findsOneWidget);
      await tester.pumpAndSettle(); // no queda ninguna animación continua
      expect(find.text('62.5%'), findsOneWidget);
    });

    testWidgets('con "quitar animaciones" sale completo de entrada y no se desborda con una meta pasada', (tester) async {
      await tester.pumpWidget(_app(const InicioGoalRing(percent: 134.2, color: Colors.green), disableAnimations: true));
      expect(find.text('134.2%'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('secciones y segmentos', () {
    testWidgets('InicioSection muestra su título, la ayuda a la derecha y el contenido', (tester) async {
      await tester.pumpWidget(
        _app(
          const InicioSection(
            title: 'Ventas por cliente',
            icon: Icons.group_outlined,
            trailing: Icon(Icons.help_outline),
            child: Text('contenido'),
          ),
        ),
      );
      expect(find.text('Ventas por cliente'), findsOneWidget);
      expect(find.byIcon(Icons.help_outline), findsOneWidget);
      expect(find.text('contenido'), findsOneWidget);
    });

    for (final dark in [false, true]) {
      testWidgets('el segmento elegido se marca con fondo oscuro y texto blanco (${dark ? 'modo oscuro' : 'modo claro'})', (
        tester,
      ) async {
        await tester.pumpWidget(
          _app(
            Builder(
              builder: (context) => SegmentedButton<int>(
                showSelectedIcon: false,
                style: inicioSegmentedStyle(context),
                segments: const [ButtonSegment(value: 1, label: Text('Hoy')), ButtonSegment(value: 2, label: Text('Mes'))],
                selected: const {1},
                onSelectionChanged: (_) {},
              ),
            ),
            mode: dark ? ThemeMode.dark : ThemeMode.light,
          ),
        );
        await tester.pumpAndSettle();
        final selectedLabel = tester.widget<DefaultTextStyle>(
          find.ancestor(of: find.text('Hoy'), matching: find.byType(DefaultTextStyle)).first,
        );
        expect(selectedLabel.style.color, Colors.white);
        final other = tester.widget<DefaultTextStyle>(
          find.ancestor(of: find.text('Mes'), matching: find.byType(DefaultTextStyle)).first,
        );
        expect(other.style.color, isNot(Colors.white));
      });
    }
  });

  group('cabecera y tarjetas', () {
    testWidgets('el saludo muestra título, texto y el aviso de carga', (tester) async {
      await tester.pumpWidget(
        _app(
          const InicioGreeting(
            greeting: (icon: '☀️', title: '¡Buenos días, Ana!', text: 'Comienza el día'),
            subtitle: 'Panorama general',
            loading: true,
          ),
        ),
      );
      expect(find.text('¡Buenos días, Ana!'), findsOneWidget);
      expect(find.text('Comienza el día · Panorama general'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('las fichas de cifras no se desbordan con letra grande en modo oscuro', (tester) async {
      tester.view.physicalSize = const Size(320, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        _app(
          const InicioKpiRow(
            children: [
              InicioKpi(label: 'N.º de ventas', value: '1,234', variation: 12.5, caption: 'Año pasado: 1,000'),
              InicioKpi(label: 'Ticket promedio', value: 'S/ 1,520.88', variation: -4.2, caption: 'Año pasado: S/ 1,500.00'),
            ],
          ),
          mode: ThemeMode.dark,
          scale: 1.3,
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Ticket promedio'), findsOneWidget);
    });
  });
}
