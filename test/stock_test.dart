import 'dart:typed_data';

import 'package:app_novik/core/errors/failures.dart';
import 'package:app_novik/core/utils/either.dart';
import 'package:app_novik/core/utils/format.dart';
import 'package:app_novik/data/models/stock_model.dart';
import 'package:app_novik/data/datasources/theme_local_datasource.dart';
import 'package:app_novik/domain/entities/company_entity.dart';
import 'package:app_novik/domain/entities/document_entity.dart' show DownloadedFile;
import 'package:app_novik/domain/entities/product_form_entity.dart';
import 'package:app_novik/domain/entities/saved_credentials_entity.dart';
import 'package:app_novik/domain/entities/session_context_entity.dart';
import 'package:app_novik/domain/entities/user_entity.dart';
import 'package:app_novik/domain/repositories/auth_repository.dart';
import 'package:app_novik/domain/usecases/auth_usecases.dart';
import 'package:app_novik/presentation/pages/stock_page.dart';
import 'package:app_novik/presentation/providers/auth_provider.dart';
import 'package:app_novik/presentation/providers/theme_provider.dart';
import 'package:app_novik/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:app_novik/domain/entities/stock_entity.dart';
import 'package:app_novik/domain/repositories/stock_repository.dart';
import 'package:app_novik/domain/usecases/stock_usecases.dart';
import 'package:app_novik/presentation/providers/stock_provider.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeStockRepository implements StockRepository {
  final List<({int warehouseId, int? priceListId, bool includeZero, List<String> search, int page})>
      calls = [];
  Either<Failure, List<CatalogItemEntity>>? warehouses;
  final List<({int warehouseId, int? priceListId, List<String> search, String name})> exports = [];

  @override
  Future<Either<Failure, List<CatalogItemEntity>>> getWarehouses(int companyId) async =>
      warehouses ??
      Either.right(const [
        CatalogItemEntity(id: 1, name: 'LIMA'),
        CatalogItemEntity(id: 2, name: 'AREQUIPA'),
        CatalogItemEntity(id: 3, name: 'CUSCO'),
      ]);

  @override
  Future<Either<Failure, List<PriceListEntity>>> getPriceLists(int companyId) async =>
      Either.right(const [
        PriceListEntity(id: 10, name: 'MAYORISTA'),
        PriceListEntity(id: 11, name: 'DÓLARES', esDolares: true),
      ]);

  @override
  Future<Either<Failure, DownloadedFile>> exportStock({
    required int warehouseId,
    int? priceListId,
    List<String> search = const [],
    required String name,
  }) async {
    exports.add((warehouseId: warehouseId, priceListId: priceListId, search: search, name: name));
    return Either.right(DownloadedFile(name: name, bytes: Uint8List.fromList([1, 2, 3])));
  }

  @override
  Future<Either<Failure, StockPageEntity>> getStock({
    required int companyId,
    required int warehouseId,
    int? priceListId,
    List<String> search = const [],
    bool includeZero = false,
    int page = 1,
    int pageSize = 20,
  }) async {
    calls.add((
      warehouseId: warehouseId,
      priceListId: priceListId,
      includeZero: includeZero,
      search: search,
      page: page,
    ));
    return Either.right(StockPageEntity(
      items: [StockItemEntity(productId: page, codigo: 'P$page', name: 'Producto $page')],
      currentPage: page,
      lastPage: 2,
      total: 2,
      costoTotal: 100,
      totalVenta: 250,
    ));
  }
}

StockProvider _provider(_FakeStockRepository repo) => StockProvider(
      getWarehousesUseCase: GetWarehousesUseCase(repository: repo),
      getPriceListsUseCase: GetPriceListsUseCase(repository: repo),
      getStockUseCase: GetStockUseCase(repository: repo),
      exportStockUseCase: ExportStockUseCase(repository: repo),
    );

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
  Future<Either<Failure, void>> saveCredentials(String usuario, String password) async =>
      Either.rightVoid();

  @override
  Future<Either<Failure, void>> clearSavedCredentials() async => Either.rightVoid();
}

SessionContextEntity _session({List<String> roles = const [], Set<String> permissions = const {}}) =>
    SessionContextEntity(
      user: const UserEntity(id: 9, name: 'Ana', usuario: 'ana'),
      company: const CompanyEntity(id: 7, razonSocial: 'ACME'),
      modules: const [],
      permissions: permissions,
      roles: roles,
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

void main() {
  group('StockPageModel', () {
    test('lee las existencias como las calcula la web', () {
      final page = StockPageModel.fromJson({
        'current_page': 1,
        'last_page': 2,
        'total': 30,
        'costo_total': 1234.5,
        'total_venta': '2000.00',
        'data': [
          {
            'id': 5,
            'codigo': 'SUB-1200',
            'name': 'SUBWOOFER',
            'tipo': 'p',
            'vender_sin_stock': true,
            'brand': {'id': 1, 'name': 'PIONEER'},
            'warehouses': [
              {
                'id': 1,
                'pivot': {'stock': 24, 'costo_promedio': '50.5'},
              },
            ],
            'list_prices': [
              {
                'id': 10,
                'pivot': {'precio': '89.9'},
              },
            ],
            'cantidad_total': '2',
            'cantidad_total_cotizaciones': null,
            'cantidad_total_transferencias': '3',
            'transfers_pendientes': '4',
          },
          {'id': 6, 'codigo': 'X', 'name': 'SIN DATOS', 'warehouses': []},
        ],
      });

      expect(page.total, 30);
      expect(page.hasMore, isTrue);
      expect(page.costoTotal, 1234.5);
      expect(page.totalVenta, 2000);

      final s = page.items.first;
      expect(s.marca, 'PIONEER');
      expect(s.disponible, 24);
      expect(s.porDespachar, 5); // 2 + 0 + 3
      expect(s.porRecibir, 4);
      expect(s.stockTotal, 29);
      expect(s.ventaSinStock, isTrue);
      expect(s.costoPromedio, 50.5);
      expect(s.precio, 89.9);

      final vacio = page.items.last;
      expect(vacio.disponible, 0);
      expect(vacio.precio, isNull);
    });

    test('las listas de precios distinguen dólares', () {
      final lists = priceListsFromJson([
        {'id': 1, 'name': 'SOLES', 'tipo_moneda': 's'},
        {'id': 2, 'name': 'USD', 'tipo_moneda': 'd'},
      ]);

      expect(lists.map((l) => l.simboloMoneda), ['S/', r'$']);
    });
  });

  group('formato', () {
    test('cantidades y montos', () {
      expect(formatQuantity(24), '24');
      expect(formatQuantity(24.5), '24.50');
      expect(formatMoney(1234.5), 'S/ 1,234.50');
      expect(formatMoney(10, symbol: r'$'), r'$ 10.00');
    });
  });

  group('StockProvider', () {
    test('usa el almacén y la lista predeterminados del usuario', () async {
      final repo = _FakeStockRepository();
      final provider = _provider(repo)
        ..syncSession(7, defaultWarehouseId: 2, defaultPriceListId: 11);

      await provider.ensureLoaded();

      expect(provider.warehouseId, 2);
      expect(provider.priceListId, 11);
      expect(repo.calls.single.warehouseId, 2);
      expect(provider.costoTotal, 100);
      expect(provider.totalVenta, 250);
    });

    test('sin predeterminado elige el último, como la web', () async {
      final repo = _FakeStockRepository();
      final provider = _provider(repo)..syncSession(7);

      await provider.ensureLoaded();

      expect(provider.warehouseId, 3);
      expect(provider.priceListId, 11);
    });

    test('cambiar de almacén, filtro o búsqueda vuelve a la primera página', () async {
      final repo = _FakeStockRepository();
      final provider = _provider(repo)..syncSession(7);
      await provider.ensureLoaded();
      await provider.loadMore();
      expect(repo.calls.last.page, 2);

      await provider.selectWarehouse(1);
      expect(repo.calls.last.warehouseId, 1);
      expect(repo.calls.last.page, 1);

      await provider.setIncludeZero(true);
      expect(repo.calls.last.includeZero, isTrue);

      await provider.setSearch('subwoofer, pioneer');
      expect(repo.calls.last.search, ['subwoofer', 'pioneer']);
    });

    test('cambiar de empresa descarta todo y vuelve a cargar', () async {
      final repo = _FakeStockRepository();
      final provider = _provider(repo)..syncSession(7);
      await provider.ensureLoaded();

      provider.syncSession(8);
      expect(provider.items, isEmpty);
      expect(provider.warehouses, isEmpty);

      await provider.ensureLoaded();
      expect(provider.items, isNotEmpty);
    });

    test('si fallan los almacenes queda el error', () async {
      final repo = _FakeStockRepository()
        ..warehouses = Either.left(const NetworkFailure('Sin conexión a internet'));
      final provider = _provider(repo)..syncSession(7);

      await provider.ensureLoaded();

      expect(provider.error, 'Sin conexión a internet');
      expect(repo.calls, isEmpty);
    });
  });

  group('StockProvider.exportCurrent', () {
    test('pide el Excel del almacén y lista elegidos y lo nombra como el almacén', () async {
      final repo = _FakeStockRepository();
      final provider = _provider(repo)..syncSession(7, defaultWarehouseId: 2, defaultPriceListId: 11);
      await provider.ensureLoaded();
      await provider.setSearch('subwoofer');

      final result = await provider.exportCurrent();

      expect(result.isRight, isTrue);
      expect(result.right.name, 'AREQUIPA.xlsx');
      expect(repo.exports.single.warehouseId, 2);
      expect(repo.exports.single.priceListId, 11);
      expect(repo.exports.single.search, ['subwoofer']);
      expect(provider.exporting, isFalse);
    });

    test('sin almacén elegido no exporta', () async {
      final repo = _FakeStockRepository();
      final provider = _provider(repo)..syncSession(7);

      final result = await provider.exportCurrent();

      expect(result.isLeft, isTrue);
      expect(repo.exports, isEmpty);
    });
  });

  group('StockPage', () {
    Future<_FakeStockRepository> pump(WidgetTester tester, SessionContextEntity session) async {
      // Las pruebas dibujan con la fuente Ahem (casi el doble de ancha que una real).
      tester.view.physicalSize = const Size(360 * 3, 780 * 3);
      tester.view.devicePixelRatio = 3;
      tester.platformDispatcher.textScaleFactorTestValue = 0.55;
      addTearDown(() {
        tester.view.reset();
        tester.platformDispatcher.clearTextScaleFactorTestValue();
      });

      final repo = _FakeStockRepository();
      final stock = _provider(repo)..syncSession(7, defaultWarehouseId: 1, defaultPriceListId: 10);
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<ThemeProvider>(
              create: (_) => ThemeProvider(storage: _FakeThemeStorage()),
            ),
            ChangeNotifierProvider<AuthProvider>.value(value: _auth(session)),
            ChangeNotifierProvider<StockProvider>.value(value: stock),
          ],
          child: MaterialApp(theme: AppTheme.light, home: const Scaffold(body: StockPage())),
        ),
      );
      await tester.pumpAndSettle();
      return repo;
    }

    final conTotales = _session(
      roles: const ['Contador'],
      permissions: const {'almacenes.show.totales'},
    );

    testWidgets('tiene el botón Acciones y no muestra los totales sueltos', (tester) async {
      await pump(tester, conTotales);

      expect(find.text('Acciones'), findsOneWidget);
      expect(find.text('Producto 1'), findsOneWidget);
      expect(find.textContaining('Costo Total'), findsNothing);
      expect(find.textContaining('Total Venta'), findsNothing);
    });

    testWidgets('Acciones ofrece Exportar y Totales', (tester) async {
      await pump(tester, conTotales);

      await tester.tap(find.text('Acciones'));
      await tester.pumpAndSettle();

      expect(find.byTooltip('Exportar'), findsOneWidget);
      expect(find.byTooltip('Totales'), findsOneWidget);
    });

    testWidgets('Totales abre un modal con el costo total y el total de venta', (tester) async {
      await pump(tester, conTotales);

      await tester.tap(find.text('Acciones'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Totales'));
      await tester.pumpAndSettle();

      expect(find.text('Costo Total'), findsOneWidget);
      expect(find.text('S/. 100.00'), findsOneWidget);
      expect(find.text('Total Venta'), findsOneWidget);
      expect(find.text('S/. 250.00'), findsOneWidget);
      expect(find.text('Cerrar'), findsOneWidget);
    });

    testWidgets('sin el rol de totales solo queda Exportar, directo', (tester) async {
      final repo = await pump(
        tester,
        _session(roles: const ['Vendedor'], permissions: const {'almacenes.show.totales'}),
      );

      // Con una sola acción el botón flotante es esa acción.
      expect(find.text('Acciones'), findsNothing);
      expect(find.text('Totales'), findsNothing);
      expect(find.text('Exportar'), findsOneWidget);
      expect(repo.exports, isEmpty);
    });
  });
}
