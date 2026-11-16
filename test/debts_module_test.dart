import 'dart:typed_data';

import 'package:app_novik/core/constants/api_constants.dart';
import 'package:app_novik/core/errors/failures.dart';
import 'package:app_novik/core/utils/either.dart';
import 'package:app_novik/data/datasources/debt_remote_datasource.dart';
import 'package:app_novik/data/datasources/theme_local_datasource.dart';
import 'package:app_novik/data/models/debt_model.dart';
import 'package:app_novik/domain/entities/company_entity.dart';
import 'package:app_novik/domain/entities/debt_entity.dart';
import 'package:app_novik/domain/entities/saved_credentials_entity.dart';
import 'package:app_novik/domain/entities/session_context_entity.dart';
import 'package:app_novik/domain/entities/user_entity.dart';
import 'package:app_novik/domain/repositories/auth_repository.dart';
import 'package:app_novik/domain/repositories/debt_repository.dart';
import 'package:app_novik/domain/usecases/auth_usecases.dart';
import 'package:app_novik/domain/usecases/debt_usecases.dart';
import 'package:app_novik/presentation/components/app_summary.dart';
import 'package:app_novik/presentation/components/app_list_card.dart' show AppListCard;
import 'package:app_novik/presentation/components/app_pickers.dart' show AppPickerField;
import 'package:app_novik/presentation/pages/debts_page.dart';
import 'package:app_novik/presentation/providers/auth_provider.dart';
import 'package:app_novik/presentation/providers/debts_provider.dart';
import 'package:app_novik/presentation/providers/theme_provider.dart';
import 'package:app_novik/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';

Map<String, dynamic> _debtJson({int id = 1, String cliente = 'ACME SAC', num soles = 1500.5, num dolares = 0}) => {
      'id': id,
      'cliente': cliente,
      'client': {'id': id, 'name': cliente},
      'deuda_soles': soles,
      'deuda_dolares': dolares,
      'linea_utilizada': '1500.50',
      'credito': 5000,
      'credito_disponible': 3499.5,
    };

Map<String, dynamic> _pageJson({List<Map<String, dynamic>>? data, int page = 1, int last = 1}) => {
      'data': data ?? [_debtJson()],
      'current_page': page,
      'per_page': 30,
      'total': 42,
      'last_page': last,
      'total_soles': 9000.25,
      'total_dolares': 120,
    };

/// Ruta base de la API según la URL con la que se compile (en producción lleva `/7power/public`).
final _apiPath = Uri.parse(ApiConstants.baseUrl).path;

DebtClientEntity _debt({int id = 1, String cliente = 'ACME SAC', double soles = 1500.5, double dolares = 0}) =>
    DebtClientEntity(
      id: id,
      cliente: cliente,
      deudaSoles: soles,
      deudaDolares: dolares,
      lineaUtilizada: 1500.5,
      credito: 5000,
    );

class _FakeDebtRepository implements DebtRepository {
  List<DebtClientEntity> items = [_debt()];
  int lastPage = 1;
  Failure? failure;
  final calls = <({int page, DebtFiltersEntity filters})>[];
  final searches = <({String search, bool onlyMine})>[];
  int sellerCalls = 0;
  DebtFiltersEntity? exported;

  List<DebtOption> clients = const [
    DebtOption(id: 7, name: 'DISTRIBUIDORA SUR'),
    DebtOption(id: 8, name: 'ALMACENES NORTE'),
  ];
  List<DebtOption> sellers = const [
    DebtOption(id: 4, name: 'FRANCIS BULNES GONZALES'),
    DebtOption(id: 5, name: 'LUIS VENDEDOR'),
  ];

  @override
  Future<Either<Failure, DebtPageEntity>> getDebts({
    required int page,
    required int pageSize,
    required DebtFiltersEntity filters,
  }) async {
    calls.add((page: page, filters: filters));
    if (failure != null) return Either.left(failure!);
    return Either.right(
      DebtPageEntity(
        items: items,
        currentPage: page,
        lastPage: lastPage,
        total: items.isEmpty ? 0 : 42,
        totalSoles: items.isEmpty ? 0 : 9000.25,
        totalDolares: items.isEmpty ? 0 : 120,
      ),
    );
  }

  @override
  Future<Either<Failure, List<DebtOption>>> searchClients({
    required int companyId,
    required String search,
    required bool onlyMine,
  }) async {
    searches.add((search: search, onlyMine: onlyMine));
    return Either.right(clients);
  }

  @override
  Future<Either<Failure, List<DebtOption>>> getSellers({required int companyId}) async {
    sellerCalls++;
    return Either.right(sellers);
  }

  @override
  Future<Either<Failure, Uint8List>> exportDebts({required DebtFiltersEntity filters}) async {
    exported = filters;
    return Either.right(Uint8List.fromList([1, 2, 3]));
  }
}

class _FakeThemeStorage implements ThemeLocalDataSource {
  @override
  Future<ThemeMode?> read() async => null;

  @override
  Future<void> write(ThemeMode mode) async {}
}

class _FakeAuthRepository implements AuthRepository {
  @override
  Future<Either<Failure, UserEntity>> login(String usuario, String password) async =>
      Either.right(const UserEntity(id: 9, name: 'Ana', usuario: 'ana'));

  @override
  Future<Either<Failure, void>> logout() async => Either.rightVoid();

  @override
  Future<Either<Failure, SessionContextEntity?>> getSessionContext() async => Either.right(null);

  @override
  Future<String?> getToken() async => null;

  @override
  Future<Either<Failure, SavedCredentialsEntity?>> getSavedCredentials() async => Either.right(null);

  @override
  Future<Either<Failure, void>> saveCredentials(String usuario, String password) async => Either.rightVoid();

  @override
  Future<Either<Failure, void>> clearSavedCredentials() async => Either.rightVoid();
}

SessionContextEntity _session({int companyId = 1, Set<String> permissions = const {'pagos.index'}}) =>
    SessionContextEntity(
      user: const UserEntity(id: 9, name: 'Ana', usuario: 'ana'),
      company: CompanyEntity(id: companyId, razonSocial: 'ACME'),
      modules: const [],
      permissions: permissions,
      roles: const [],
      warehouses: const [],
    );

AuthProvider _auth(SessionContextEntity session) {
  final repo = _FakeAuthRepository();
  return AuthProvider(
    loginUseCase: LoginUseCase(repository: repo),
    logoutUseCase: LogoutUseCase(repository: repo),
    getSessionContextUseCase: GetSessionContextUseCase(repository: repo),
    getSavedCredentialsUseCase: GetSavedCredentialsUseCase(repository: repo),
    saveCredentialsUseCase: SaveCredentialsUseCase(repository: repo),
    clearSavedCredentialsUseCase: ClearSavedCredentialsUseCase(repository: repo),
  )..session = session;
}

DebtsProvider _provider(_FakeDebtRepository repo, {SessionContextEntity? session}) => DebtsProvider(
      getDebtsUseCase: GetDebtsUseCase(repository: repo),
      searchClientsUseCase: SearchDebtClientsUseCase(repository: repo),
      getSellersUseCase: GetDebtSellersUseCase(repository: repo),
      exportDebtsUseCase: ExportDebtsUseCase(repository: repo),
    )..syncSession(session ?? _session());

Future<({_FakeDebtRepository repo, DebtsProvider provider})> _pump(
  WidgetTester tester, {
  Set<String> permissions = const {'pagos.index'},
  Size size = const Size(400, 900),
  ThemeMode mode = ThemeMode.light,
  double textScale = 1,
  void Function(_FakeDebtRepository repo)? setUp,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final repo = _FakeDebtRepository();
  setUp?.call(repo);
  final session = _session(permissions: permissions);
  final provider = _provider(repo, session: session);

  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<ThemeProvider>(create: (_) => ThemeProvider(storage: _FakeThemeStorage())),
        ChangeNotifierProvider<AuthProvider>.value(value: _auth(session)),
        ChangeNotifierProvider<DebtsProvider>.value(value: provider),
      ],
      child: MaterialApp(
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        themeMode: mode,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: const Scaffold(body: DebtsPage()),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return (repo: repo, provider: provider);
}

void main() {
  group('Modelo de deudas', () {
    test('lee una página con los totales y números como texto', () {
      final page = debtPageFromJson(_pageJson(page: 1, last: 3));

      expect(page.items.single.cliente, 'ACME SAC');
      expect(page.items.single.deudaSoles, 1500.5);
      expect(page.items.single.deudaDolares, 0);
      expect(page.items.single.lineaUtilizada, 1500.5);
      expect(page.items.single.credito, 5000);
      expect(page.total, 42);
      expect(page.totalSoles, 9000.25);
      expect(page.totalDolares, 120);
      expect(page.hasMore, isTrue);
    });

    test('sin datos devuelve una lista vacía y totales en cero', () {
      final page = debtPageFromJson({'data': [], 'total': 0});
      expect(page.items, isEmpty);
      expect(page.totalSoles, 0);
      expect(page.hasMore, isFalse);
    });

    test('los clientes usan el nombre que ve la web', () {
      final list = debtClientOptionsFromJson([
        {'id': 1, 'display_label': 'ACME SAC - 20123456789', 'name': 'x'},
        {'id': 2, 'razon_social': 'BETA SAC'},
        {'id': 3, 'name': 'Ana', 'last_name': 'Pérez'},
        {'id': 4},
      ]);
      expect(list.map((o) => o.name), ['ACME SAC - 20123456789', 'BETA SAC', 'Ana Pérez']);
      expect(debtClientOptionsFromJson({'message': 'x'}), isEmpty);
    });

    test('los ejecutivos salen de usuarios/list', () {
      final list = debtSellerOptionsFromJson([
        {'id': 5, 'name': 'LUIS', 'usuario': 'luis'},
        {'id': 6},
      ]);
      expect(list.single, const DebtOption(id: 5, name: 'LUIS'));
    });
  });

  group('Datasource de deudas', () {
    test('GET /deudas/clientes/resumen manda paginación y filtros como la web', () async {
      late Uri uri;
      final ds = DebtRemoteDataSourceImpl(
        client: MockClient((request) async {
          uri = request.url;
          expect(request.method, 'GET');
          return http.Response('{"data": [], "current_page": 1, "last_page": 1, "total": 0}', 200);
        }),
      );

      await ds.getDebts(
        't',
        page: 2,
        pageSize: 30,
        filters: const DebtFiltersEntity(
          search: 'acme',
          client: DebtOption(id: 7, name: 'X'),
          seller: DebtOption(id: 4, name: 'Y'),
        ),
      );

      expect(uri.path, '$_apiPath/deudas/clientes/resumen');
      expect(uri.queryParameters, {
        'pagination[current]': '2',
        'pagination[pageSize]': '30',
        'filters[client_id]': '7',
        'filters[vendedor_id]': '4',
        'filters[cliente]': 'acme',
      });
    });

    test('sin filtros solo manda la paginación', () async {
      late Uri uri;
      final ds = DebtRemoteDataSourceImpl(
        client: MockClient((request) async {
          uri = request.url;
          return http.Response('{"data": []}', 200);
        }),
      );

      await ds.getDebts('t', page: 1, pageSize: 30, filters: const DebtFiltersEntity());

      expect(uri.queryParameters.keys, ['pagination[current]', 'pagination[pageSize]']);
    });

    test('la búsqueda de clientes pide validar_vendedor solo si no ve a todos', () async {
      final uris = <Uri>[];
      final ds = DebtRemoteDataSourceImpl(
        client: MockClient((request) async {
          uris.add(request.url);
          return http.Response('[{"id": 1, "display_label": "ACME"}]', 200);
        }),
      );

      final all = await ds.searchClients('t', companyId: 3, search: 'ac', onlyMine: false);
      await ds.searchClients('t', companyId: 3, search: 'ac', onlyMine: true);

      expect(all.single.name, 'ACME');
      expect(uris.first.path, '$_apiPath/clientes/search');
      expect(uris.first.queryParameters, {'company_id': '3', 'search': 'ac'});
      expect(uris.last.queryParameters, {'company_id': '3', 'search': 'ac', 'validar_vendedor': 'true'});
    });

    test('los ejecutivos son los usuarios con rol Vendedor de la empresa', () async {
      late Uri uri;
      final ds = DebtRemoteDataSourceImpl(
        client: MockClient((request) async {
          uri = request.url;
          return http.Response('[{"id": 5, "name": "LUIS"}]', 200);
        }),
      );

      final sellers = await ds.getSellers('t', companyId: 3);

      expect(uri.path, '$_apiPath/usuarios/list');
      expect(uri.queryParameters, {'company_id': '3', 'roles[0]': 'Vendedor'});
      expect(sellers.single.name, 'LUIS');
    });

    test('el Excel es un POST con los filtros de cliente y ejecutivo', () async {
      late http.Request req;
      final ds = DebtRemoteDataSourceImpl(
        client: MockClient((request) async {
          req = request;
          return http.Response.bytes([9, 9], 200);
        }),
      );

      final bytes = await ds.exportDebts(
        't',
        filters: const DebtFiltersEntity(
          search: 'no va',
          client: DebtOption(id: 7, name: 'X'),
          seller: DebtOption(id: 4, name: 'Y'),
        ),
      );

      expect(bytes, [9, 9]);
      expect(req.method, 'POST');
      expect(req.url.path, '$_apiPath/deudas/clientes/resumen/export-excel');
      expect(req.url.queryParameters, {'filters[client_id]': '7', 'filters[vendedor_id]': '4'});
    });
  });

  group('DebtsProvider', () {
    test('carga la primera página con sus totales', () async {
      final repo = _FakeDebtRepository();
      final p = _provider(repo);

      await p.ensureLoaded();

      expect(p.items, hasLength(1));
      expect(p.total, 42);
      expect(p.totalSoles, 9000.25);
      expect(p.totalDolares, 120);
      expect(repo.calls.single.page, 1);
    });

    test('loadMore suma la página siguiente y para al llegar a la última', () async {
      final repo = _FakeDebtRepository()..lastPage = 2;
      final p = _provider(repo);
      await p.refresh();
      expect(p.hasMore, isTrue);

      repo.items = [_debt(id: 2, cliente: 'BETA')];
      await p.loadMore();
      await p.loadMore();

      expect(p.items.map((d) => d.cliente), ['ACME SAC', 'BETA']);
      expect(p.hasMore, isFalse);
      expect(repo.calls.map((c) => c.page), [1, 2]);
    });

    test('un error deja la lista vacía con el mensaje', () async {
      final repo = _FakeDebtRepository()..failure = const ServerFailure('Falló');
      final p = _provider(repo);

      await p.refresh();

      expect(p.items, isEmpty);
      expect(p.error, 'Falló');
      expect(p.totalSoles, 0);
    });

    test('quien ve a todos manda solo los filtros que eligió', () async {
      final repo = _FakeDebtRepository();
      final p = _provider(repo, session: _session(permissions: {'pagos.index', 'pagos.todos_los_vendedores'}));
      await p.refresh();
      expect(p.canSeeAll, isTrue);
      expect(repo.calls.last.filters.seller, isNull);

      await p.setFilters(const DebtFiltersEntity(seller: DebtOption(id: 4, name: 'F')));
      expect(repo.calls.last.filters.seller!.id, 4);
    });

    test('también vale el permiso deudas.todos_los_vendedores', () {
      final p = _provider(_FakeDebtRepository(), session: _session(permissions: {'pagos.index', 'deudas.todos_los_vendedores'}));
      expect(p.canSeeAll, isTrue);
    });

    test('sin ver a todos, siempre filtra por el propio usuario (igual que la web)', () async {
      final repo = _FakeDebtRepository();
      final p = _provider(repo);
      await p.refresh();
      expect(p.canSeeAll, isFalse);
      expect(repo.calls.last.filters.seller!.id, 9);

      // Aunque intente elegir otro ejecutivo, el pedido sigue siendo por sí mismo.
      await p.setFilters(const DebtFiltersEntity(seller: DebtOption(id: 4, name: 'F'), client: DebtOption(id: 7, name: 'C')));
      expect(repo.calls.last.filters.seller!.id, 9);
      expect(repo.calls.last.filters.client!.id, 7);
    });

    test('la búsqueda va por nombre de cliente', () async {
      final repo = _FakeDebtRepository();
      final p = _provider(repo);

      await p.setSearch('  acme ');

      expect(repo.calls.last.filters.search, 'acme');
      expect(p.filters.active, isTrue);
    });

    test('buscar clientes pide solo los de su cartera si no ve a todos', () async {
      final repo = _FakeDebtRepository();
      final mine = _provider(repo);
      final all = _provider(repo, session: _session(permissions: {'pagos.index', 'pagos.todos_los_vendedores'}));

      await mine.searchClients('ac');
      await all.searchClients('ac');

      expect(repo.searches.map((s) => s.onlyMine), [true, false]);
    });

    test('los ejecutivos se piden una sola vez', () async {
      final repo = _FakeDebtRepository();
      final p = _provider(repo);

      await p.loadSellers();
      await p.loadSellers();

      expect(repo.sellerCalls, 1);
      expect(p.sellers, hasLength(2));
    });

    test('al cambiar de empresa se descarta todo', () async {
      final repo = _FakeDebtRepository();
      final p = _provider(repo);
      await p.refresh();
      await p.setSearch('x');

      p.syncSession(_session(companyId: 2));

      expect(p.items, isEmpty);
      expect(p.filters.active, isFalse);
      expect(p.sellers, isNull);
    });

    test('exportAll devuelve el Excel con su nombre y manda los filtros de cliente y ejecutivo', () async {
      final repo = _FakeDebtRepository();
      final p = _provider(repo, session: _session(permissions: {'pagos.index', 'pagos.todos_los_vendedores'}));
      await p.setFilters(const DebtFiltersEntity(client: DebtOption(id: 7, name: 'C'), seller: DebtOption(id: 4, name: 'S')));

      final result = await p.exportAll();

      expect(result.isRight, isTrue);
      expect(result.right.name, 'Deudas Pendientes.xlsx');
      expect(result.right.bytes, [1, 2, 3]);
      expect(repo.exported!.client!.id, 7);
      expect(repo.exported!.seller!.id, 4);
      expect(p.exporting, isFalse);
    });
  });

  group('Pantalla de Deudas', () {
    testWidgets('muestra las deudas con soles, dólares, línea utilizada y crédito', (tester) async {
      await _pump(tester, setUp: (r) => r.items = [_debt(dolares: 250), _debt(id: 2, cliente: 'BETA SAC', soles: 99)]);

      expect(find.text('Deudas'), findsWidgets);
      expect(find.byType(AppListCard), findsNWidgets(2));
      expect(find.text('ACME SAC'), findsOneWidget);
      expect(find.text('S/. 1,500.50'), findsOneWidget);
      expect(find.text(r'$. 250.00'), findsOneWidget);
      expect(find.text('Línea utilizada S/. 1,500.50'), findsWidgets);
      expect(find.text('Crédito S/. 5,000.00'), findsWidgets);
      // Sin deuda en dólares no sale ese dato.
      expect(find.textContaining(r'$. 0.00'), findsNothing);
    });

    testWidgets('los totales ya no salen sueltos arriba: están en Acciones → Totales', (tester) async {
      await _pump(tester);

      // Arriba de la lista no hay tarjetas informativas.
      expect(find.byType(AppMetricCard), findsNothing);
      expect(find.text('Total soles'), findsNothing);

      await tester.tap(find.text('Acciones'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Totales'));
      await tester.pumpAndSettle();

      expect(find.byType(AppMetricCard), findsNWidgets(2));
      expect(find.text('Total soles'), findsOneWidget);
      expect(find.text('S/. 9,000.25'), findsOneWidget);
      expect(find.text('Total dólares'), findsOneWidget);
      expect(find.text(r'$. 120.00'), findsOneWidget);
    });

    testWidgets('sin deudas dice que no hay', (tester) async {
      await _pump(tester, setUp: (r) => r.items = []);

      expect(find.text('No hay deudas pendientes'), findsOneWidget);
      expect(find.text('Total soles'), findsNothing);
    });

    testWidgets('si falla muestra el error y Reintentar vuelve a pedir', (tester) async {
      final r = await _pump(tester, setUp: (r) => r.failure = const ServerFailure('Sin conexión con el servidor'));

      expect(find.text('No se pudieron cargar las deudas'), findsOneWidget);
      expect(find.text('Sin conexión con el servidor'), findsOneWidget);

      r.repo.failure = null;
      await tester.tap(find.text('Reintentar'));
      await tester.pumpAndSettle();

      expect(find.text('ACME SAC'), findsOneWidget);
      expect(r.repo.calls, hasLength(2));
    });

    testWidgets('sin permiso pagos.index no pide nada y avisa', (tester) async {
      final r = await _pump(tester, permissions: const {});

      expect(find.text('Sin acceso'), findsOneWidget);
      expect(find.byType(AppListCard), findsNothing);
      expect(r.repo.calls, isEmpty);
    });

    testWidgets('escribir en el buscador filtra por cliente tras una pausa', (tester) async {
      final r = await _pump(tester);

      await tester.enterText(find.byType(SearchBar), 'acme');
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();

      expect(r.repo.calls.last.filters.search, 'acme');
    });

    testWidgets('el filtro de cliente busca, se elige y queda como chip que se quita', (tester) async {
      final r = await _pump(tester);

      await tester.tap(find.byTooltip('Filtros'));
      await tester.pumpAndSettle();
      expect(find.text('Filtros'), findsWidgets);
      // Sin ver a todos no hay filtro de ejecutivo.
      expect(find.text('Ejecutivo comercial'), findsNothing);

      await tester.tap(find.widgetWithText(AppPickerField, 'Todos').first);
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).last, 'dis');
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pumpAndSettle();
      // Con su cartera limitada, la búsqueda pide solo sus clientes.
      expect(r.repo.searches.last, (search: 'dis', onlyMine: true));
      await tester.tap(find.text('DISTRIBUIDORA SUR'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Aplicar filtros'));
      await tester.pumpAndSettle();

      expect(find.text('Cliente: DISTRIBUIDORA SUR'), findsOneWidget);
      expect(r.repo.calls.last.filters.client!.id, 7);

      await tester.ensureVisible(find.byTooltip('Quitar Cliente: DISTRIBUIDORA SUR'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Quitar Cliente: DISTRIBUIDORA SUR'));
      await tester.pumpAndSettle();
      expect(find.text('Cliente: DISTRIBUIDORA SUR'), findsNothing);
      expect(r.repo.calls.last.filters.client, isNull);
    });

    testWidgets('quien ve a todos elige el ejecutivo comercial (con nombre corto)', (tester) async {
      final r = await _pump(tester, permissions: const {'pagos.index', 'pagos.todos_los_vendedores'});

      await tester.tap(find.byTooltip('Filtros'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(AppPickerField, 'Todos').last);
      await tester.pumpAndSettle();
      expect(find.text('FRANCIS B.'), findsOneWidget);
      await tester.tap(find.text('FRANCIS B.'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Aplicar filtros'));
      await tester.pumpAndSettle();

      expect(find.text('Ejecutivo: FRANCIS B.'), findsOneWidget);
      expect(r.repo.calls.last.filters.seller!.id, 4);
    });

    testWidgets('en tablet la lista no se estira y se ve bien', (tester) async {
      await _pump(tester, size: const Size(1100, 800));

      final card = tester.getSize(find.byType(AppListCard).first);
      expect(card.width, lessThanOrEqualTo(720));
      expect(tester.takeException(), isNull);
    });

    testWidgets('en modo oscuro y con letra grande no se desborda', (tester) async {
      await _pump(
        tester,
        size: const Size(360, 640),
        mode: ThemeMode.dark,
        textScale: 1.4,
        setUp: (r) => r.items = [_debt(cliente: 'DISTRIBUIDORA DE REPUESTOS AUTOMOTRICES DEL SUR SAC', dolares: 12345.67)],
      );

      expect(tester.takeException(), isNull);
      expect(find.byType(AppListCard), findsOneWidget);
    });
  });
}
