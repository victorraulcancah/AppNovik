import 'package:app_novik/core/errors/failures.dart';
import 'package:app_novik/data/datasources/theme_local_datasource.dart';
import 'package:app_novik/data/models/document_model.dart';
import 'package:app_novik/domain/entities/account_statement_entity.dart';
import 'package:app_novik/domain/entities/document_entity.dart';
import 'package:app_novik/presentation/pages/account_statement_page.dart';
import 'package:app_novik/presentation/providers/account_statement_provider.dart';
import 'package:app_novik/presentation/providers/auth_provider.dart';
import 'package:app_novik/presentation/providers/theme_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'support/account_statement_fakes.dart';
import 'support/screen_look.dart';

class _FakeThemeStorage implements ThemeLocalDataSource {
  @override
  Future<ThemeMode?> read() async => null;

  @override
  Future<void> write(ThemeMode mode) async {}
}

Future<AccountStatementProvider> _pump(
  WidgetTester tester,
  FakeStatementRepository repo, {
  Set<String> permissions = const {'estado-de-cuenta.index'},
  ScreenLook? look,
  Size size = const Size(400, 900),
  bool withClient = false,
}) async {
  if (look != null) {
    await prepareLook(tester, look);
  } else {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }
  final provider = statementProvider(repo)..syncSession(statementSession(permissions: permissions));
  if (withClient) await provider.selectClient(acme);
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthProvider>.value(value: statementAuth(permissions: permissions)),
        ChangeNotifierProvider<AccountStatementProvider>.value(value: provider),
        ChangeNotifierProvider<ThemeProvider>(create: (_) => ThemeProvider(storage: _FakeThemeStorage())),
      ],
      child: lookApp(look, home: const Scaffold(body: AccountStatementPage())),
    ),
  );
  await tester.pumpAndSettle();
  return provider;
}

/// Elige a ACME desde el buscador de la pantalla.
Future<void> _chooseAcme(WidgetTester tester) async {
  await tester.tap(find.text('Lista de clientes'));
  await tester.pumpAndSettle();
  await tester.enterText(find.byType(TextField).last, 'acme');
  await tester.pump(const Duration(milliseconds: 600));
  await tester.pumpAndSettle();
  await tester.tap(find.text('ACME SAC').last);
  await tester.pumpAndSettle();
}

void main() {
  late FakeStatementRepository repo;

  setUp(() => repo = FakeStatementRepository());

  testWidgets('sin el permiso muestra "Sin acceso" y no pide nada', (tester) async {
    await _pump(tester, repo, permissions: const {});

    expect(find.text('Sin acceso'), findsOneWidget);
    expect(find.text('Lista de clientes'), findsNothing);
    expect(repo.calls, isEmpty);
  });

  testWidgets('sin cliente pide elegir uno: sin pestañas ni totales ni exportar', (tester) async {
    await _pump(tester, repo);

    expect(find.text('Estado de cuenta'), findsOneWidget);
    expect(find.text('Elige un cliente'), findsOneWidget);
    expect(find.text('Lista de clientes'), findsOneWidget);
    expect(find.text('Pedidos'), findsNothing);
    expect(find.text('Deuda total soles'), findsNothing);
    expect(find.text('Acciones'), findsNothing);
    expect(repo.calls, isEmpty);
  });

  testWidgets('elegir un cliente muestra la cabecera y los movimientos', (tester) async {
    await _pump(tester, repo);

    await _chooseAcme(tester);

    expect(repo.calls, contains('search:acme'));
    expect(repo.lastQuery!.clientId, 7);
    // La cabecera: deuda total a la vista.
    expect(find.text('Deuda total soles'), findsOneWidget);
    expect(find.text('S/. 1,500.50'), findsOneWidget);
    expect(find.text(r'$. 20.00'), findsOneWidget);
    // Filas: una venta y un pago.
    expect(find.text('SUBWOOFER 1'), findsOneWidget);
    expect(find.text('Pagó con YAPE'), findsOneWidget);
    expect(find.text('03/11/2026 · B001-0001'), findsOneWidget);
    expect(find.text('SUB-1 · 7POWER'), findsOneWidget);
    expect(find.text('Cant. 2'), findsOneWidget);
  });

  testWidgets('un pago lleva su origen y quién lo registró, abreviado', (tester) async {
    await _pump(tester, repo, withClient: true);

    expect(find.text('Pago de cuota'), findsOneWidget);
    expect(find.text('Registrado por FRANCIS B.'), findsOneWidget);
  });

  testWidgets('tocar la cabecera muestra crédito, línea utilizada y deuda anterior', (tester) async {
    await _pump(tester, repo, withClient: true);
    expect(find.text('Línea de crédito'), findsNothing);

    await tester.tap(find.text('Deuda total soles'));
    await tester.pumpAndSettle();

    expect(find.text('Línea de crédito'), findsOneWidget);
    expect(find.text('Crédito disponible'), findsOneWidget);
    expect(find.text('Línea utilizada'), findsOneWidget);
    expect(find.text('S/. 5,000.00'), findsOneWidget);
    expect(find.text('Deuda anterior (S/.)'), findsOneWidget);
    expect(find.text('S/. 200.00'), findsOneWidget);
  });

  testWidgets('sin deuda anterior no sale esa línea', (tester) async {
    repo.mainSummary = const StatementSummaryEntity(deudaTotalSoles: 10);
    await _pump(tester, repo, withClient: true);

    await tester.tap(find.text('Deuda total soles'));
    await tester.pumpAndSettle();

    expect(find.text('Deuda anterior (S/.)'), findsNothing);
  });

  testWidgets('las pestañas Pedidos y Pagos se piden al abrirlas', (tester) async {
    await _pump(tester, repo, withClient: true);
    expect(repo.calls, ['main:1']);

    await tester.tap(find.text('Pedidos'));
    await tester.pumpAndSettle();
    expect(find.text('PEDIDO 2'), findsOneWidget);
    expect(find.text('SUBWOOFER 1'), findsNothing);

    await tester.tap(find.text('Pagos'));
    await tester.pumpAndSettle();
    expect(repo.calls, ['main:1', 'orders:1', 'payments:1']);
    expect(find.text('Pagó con YAPE'), findsOneWidget);

    await tester.tap(find.text('Estado de Cuenta'));
    await tester.pumpAndSettle();
    expect(find.text('SUBWOOFER 1'), findsOneWidget);
    expect(repo.calls.length, 3, reason: 'volver a la principal no la pide otra vez');
  });

  testWidgets('el rango de fechas se cambia con los chips', (tester) async {
    await _pump(tester, repo, withClient: true);

    await tester.tap(find.text('Último mes'));
    await tester.pumpAndSettle();

    expect(repo.lastQuery!.from, DateTime(DateTime.now().year, DateTime.now().month - 1));
    expect(repo.calls.where((c) => c == 'main:1'), hasLength(2));
  });

  testWidgets('el buscador de producto filtra la pestaña principal', (tester) async {
    await _pump(tester, repo, withClient: true);

    await tester.enterText(find.widgetWithText(SearchBar, ''), 'sub');
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pumpAndSettle();

    expect(repo.lastQuery!.search, 'sub');
  });

  testWidgets('agrupar por venta cambia la vista y quita el buscador', (tester) async {
    await _pump(tester, repo, withClient: true);
    expect(find.byType(SearchBar), findsOneWidget);

    await tester.tap(find.byTooltip('Agrupar por venta'));
    await tester.pumpAndSettle();

    expect(repo.lastQuery!.agrupado, isTrue);
    expect(find.text('Una fila por venta'), findsOneWidget);
    expect(find.byType(SearchBar), findsNothing);

    await tester.tap(find.byTooltip('Ver por producto'));
    await tester.pumpAndSettle();
    expect(repo.lastQuery!.agrupado, isFalse);
    expect(find.byType(SearchBar), findsOneWidget);
  });

  testWidgets('sin movimientos dice "Sin movimientos"', (tester) async {
    repo.main = [];
    await _pump(tester, repo, withClient: true);

    expect(find.text('Sin movimientos'), findsOneWidget);
  });

  testWidgets('un error muestra Reintentar y se recupera', (tester) async {
    repo.mainFailure = const ServerFailure('Error del servidor');
    await _pump(tester, repo, withClient: true);

    expect(find.text('No se pudo cargar el estado de cuenta'), findsOneWidget);
    expect(find.text('Error del servidor'), findsOneWidget);

    repo.mainFailure = null;
    await tester.tap(find.text('Reintentar'));
    await tester.pumpAndSettle();

    expect(find.text('SUBWOOFER 1'), findsOneWidget);
  });

  testWidgets('quitar el cliente vuelve a pedir elegir uno', (tester) async {
    await _pump(tester, repo, withClient: true);

    await tester.tap(find.byTooltip('Quitar'));
    await tester.pumpAndSettle();

    expect(find.text('Elige un cliente'), findsOneWidget);
    expect(find.text('Deuda total soles'), findsNothing);
  });

  testWidgets('con cliente hay botón de exportar con Excel y PDF', (tester) async {
    await _pump(tester, repo, withClient: true);

    await tester.tap(find.text('Acciones'));
    await tester.pumpAndSettle();

    expect(find.text('Exportar Excel'), findsOneWidget);
    expect(find.text('Exportar PDF'), findsOneWidget);
  });

  testWidgets('solo las filas con comprobante traen "Ver comprobante"', (tester) async {
    final document = documentFromJson({
      'id': 12,
      'nro_documento': 45,
      'total_soles': 100,
      'created_at': '2026-11-03T10:00:00.000000Z',
      'client': {'id': 3, 'name': 'ACME'},
      'products': <dynamic>[],
    }, DocumentKind.venta);
    repo.main = [
      StatementRowEntity(
        id: 's-1',
        fecha: DateTime(2026, 11, 3),
        documento: 'V001-0045',
        titulo: 'CON COMPROBANTE',
        soles: 100,
        document: document,
      ),
      saleRow(2),
    ];
    await _pump(tester, repo, withClient: true);

    expect(find.byTooltip('Ver comprobante'), findsOneWidget);
  });

  testWidgets('en tablet se ve igual, sin desbordes', (tester) async {
    await _pump(tester, repo, size: const Size(1100, 800), withClient: true);

    expect(find.text('SUBWOOFER 1'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  group('modo claro y oscuro, letra grande', () {
    for (final look in screenLooks) {
      testWidgets(look.label, (tester) async {
        repo.main = [saleRow(1), paymentRow(1), saleRow(3, titulo: 'AMPLIFICADOR DIGITAL MONORAL 1CH * 1500 RMS 4500WATTS')];
        await _pump(tester, repo, look: look, withClient: true);

        // Con la cabecera abierta, que es lo más ancho.
        await tester.tap(find.text('Deuda total soles'));
        await tester.pumpAndSettle();

        await expectLooksRight(tester, look);
      });
    }

    testWidgets('sin cliente, oscuro y con letra grande', (tester) async {
      const look = ScreenLook(dark: true);
      await _pump(tester, repo, look: look);

      await expectLooksRight(tester, look);
    });
  });
}
