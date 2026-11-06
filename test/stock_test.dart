import 'dart:convert';
import 'dart:typed_data';

import 'package:app_novik/core/errors/failures.dart';
import 'package:app_novik/core/utils/either.dart';
import 'package:app_novik/core/utils/format.dart';
import 'package:app_novik/data/datasources/stock_remote_datasource.dart';
import 'package:app_novik/data/models/stock_model.dart';
import 'package:app_novik/data/datasources/theme_local_datasource.dart';
import 'package:app_novik/domain/entities/company_entity.dart';
import 'package:app_novik/domain/entities/document_entity.dart' show DownloadedFile;
import 'package:app_novik/domain/entities/import_entity.dart';
import 'package:app_novik/domain/entities/other_document_entity.dart';
import 'package:app_novik/domain/entities/product_form_entity.dart';
import 'package:app_novik/domain/entities/saved_credentials_entity.dart';
import 'package:app_novik/domain/entities/session_context_entity.dart';
import 'package:app_novik/domain/entities/user_entity.dart';
import 'package:app_novik/domain/repositories/auth_repository.dart';
import 'package:app_novik/domain/usecases/auth_usecases.dart';
import 'package:app_novik/presentation/pages/stock_add_page.dart';
import 'package:app_novik/presentation/pages/stock_page.dart';
import 'package:app_novik/presentation/pages/stock_transfer_page.dart';
import 'package:app_novik/presentation/utils/import_file.dart';
import 'package:app_novik/presentation/providers/auth_provider.dart';
import 'package:app_novik/presentation/providers/theme_provider.dart';
import 'package:app_novik/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:app_novik/domain/entities/stock_entity.dart';
import 'package:app_novik/domain/entities/stock_manage_entity.dart';
import 'package:app_novik/domain/repositories/stock_management_repository.dart';
import 'package:app_novik/domain/usecases/stock_manage_usecases.dart';
import 'package:app_novik/domain/usecases/stock_usecases.dart';
import 'package:app_novik/presentation/providers/stock_provider.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

class _FakeStockRepository implements StockManagementRepository {
  final List<({int warehouseId, int? priceListId, bool includeZero, List<String> search, int page})>
      calls = [];
  final List<String?> tipos = [];
  List<StockItemEntity>? itemsOverride;

  // Operaciones que cambian el stock.
  List<StockProductEntity> products = const [];
  final List<String> searches = [];
  final List<({int warehouseId, List<({int productId, double? costo, int stock})> items})> adds = [];
  Either<Failure, void>? nextAdd;
  int templates = 0;
  final List<({int warehouseId, String fileName, int size})> imports = [];
  Either<Failure, StockImportResultEntity>? nextImport;
  final List<({int userId, int from, int to, List<({int productId, double cantidad})> items})> transfers = [];
  Either<Failure, OtherDocumentEntity>? nextTransfer;
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
    String? tipo,
  }) async {
    tipos.add(tipo);
    calls.add((
      warehouseId: warehouseId,
      priceListId: priceListId,
      includeZero: includeZero,
      search: search,
      page: page,
    ));
    return Either.right(StockPageEntity(
      items: itemsOverride ??
          [StockItemEntity(productId: page, codigo: 'P$page', name: 'Producto $page')],
      currentPage: page,
      lastPage: 2,
      total: 2,
      costoTotal: 100,
      totalVenta: 250,
    ));
  }
  @override
  Future<Either<Failure, List<StockProductEntity>>> searchProducts({
    required int companyId,
    required String search,
  }) async {
    searches.add(search);
    return Either.right(products);
  }

  @override
  Future<Either<Failure, void>> addStock({
    required int warehouseId,
    required List<({int productId, double? costo, int stock})> items,
  }) async {
    adds.add((warehouseId: warehouseId, items: items));
    return nextAdd ?? Either.rightVoid();
  }

  @override
  Future<Either<Failure, DownloadedFile>> downloadStockTemplate() async {
    templates++;
    return Either.right(
      DownloadedFile(name: 'Plantilla de Productos(Stock).xlsx', bytes: Uint8List.fromList([9])),
    );
  }

  @override
  Future<Either<Failure, StockImportResultEntity>> importStock({
    required int companyId,
    required int warehouseId,
    required String fileName,
    required Uint8List bytes,
  }) async {
    imports.add((warehouseId: warehouseId, fileName: fileName, size: bytes.length));
    return nextImport ??
        Either.right(const StockImportResultEntity(
          rows: [StockImportRow(row: 2, codigo: 'SUB-1', costo: '10.5', stock: '4')],
        ));
  }

  @override
  Future<Either<Failure, OtherDocumentEntity>> transferStock({
    required int companyId,
    required int userId,
    required int from,
    required int to,
    required List<({int productId, double cantidad})> items,
  }) async {
    transfers.add((userId: userId, from: from, to: to, items: items));
    return nextTransfer ??
        Either.right(const OtherDocumentEntity(
          kind: OtherDocumentKind.traslado,
          id: 31,
          numero: 'T001-0031',
          desde: 'LIMA',
          hacia: 'AREQUIPA',
        ));
  }
}

StockProvider _provider(_FakeStockRepository repo) => StockProvider(
      getWarehousesUseCase: GetWarehousesUseCase(repository: repo),
      getPriceListsUseCase: GetPriceListsUseCase(repository: repo),
      getStockUseCase: GetStockUseCase(repository: repo),
      exportStockUseCase: ExportStockUseCase(repository: repo),
      searchStockProductsUseCase: SearchStockProductsUseCase(repository: repo),
      addStockUseCase: AddStockUseCase(repository: repo),
      updateStockUseCase: UpdateStockUseCase(repository: repo),
      downloadStockTemplateUseCase: DownloadStockTemplateUseCase(repository: repo),
      importStockUseCase: ImportStockUseCase(repository: repo),
      transferStockUseCase: TransferStockUseCase(repository: repo),
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
      permissions: const {'almacenes.show.totales', 'stock.show'},
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
        _session(roles: const ['Vendedor'], permissions: const {'almacenes.show.totales', 'stock.show'}),
      );

      // Con una sola acción el botón flotante es esa acción.
      expect(find.text('Acciones'), findsNothing);
      expect(find.text('Totales'), findsNothing);
      expect(find.text('Exportar'), findsOneWidget);
      expect(repo.exports, isEmpty);
    });
  });
  // ---------------------------------------------------------------------------------------------
  // Operaciones que cambian el stock, filtros y permisos
  // ---------------------------------------------------------------------------------------------

  StockProductEntity product(
    int id, {
    String name = 'SUBWOOFER',
    double? ultimoCosto = 10.5,
    Map<int, StockWarehouseLevel> levels = const {
      1: StockWarehouseLevel(stock: 8, costoPromedio: 9),
      2: StockWarehouseLevel(stock: 0),
    },
  }) =>
      StockProductEntity(
        id: id,
        codigo: 'SUB-$id',
        name: name,
        marca: 'PIONEER',
        ultimoCosto: ultimoCosto,
        levels: levels,
      );

  group('modelos de stock', () {
    test('la existencia trae el último costo promedio', () {
      final item = stockItemFromJson({
        'id': 5,
        'codigo': 'A',
        'name': 'A',
        'warehouses': [
          {
            'id': 1,
            'pivot': {'stock': 3, 'costo_promedio': '0', 'ultimo_costo_promedio': '12.5'},
          },
        ],
      });

      expect(item.costoPromedio, 0);
      expect(item.ultimoCosto, 12.5);
    });

    test('un producto del buscador trae marca, último costo de entrada y lo que tiene en cada almacén', () {
      final p = stockProductFromJson({
        'id': 7,
        'codigo': 'SUB-1',
        'name': 'SUBWOOFER 12"',
        'brand': {'id': 1, 'name': 'PIONEER'},
        'stocks': [
          {
            'id': 3,
            'pivot': {'costo': '45.5', 'stock': 10},
          },
        ],
        'warehouses': [
          {
            'id': 1,
            'name': 'LIMA',
            'pivot': {'stock': '8', 'costo_promedio': '40'},
          },
          {
            'id': 2,
            'name': 'AREQUIPA',
            'pivot': {'stock': 0, 'costo_promedio': 0},
          },
        ],
      });

      expect(p.marca, 'PIONEER');
      expect(p.ultimoCosto, 45.5);
      expect(p.existeEn(1), isTrue);
      expect(p.stockEn(1), 8);
      expect(p.costoPromedioEn(1), 40);
      expect(p.stockEn(2), 0);
      expect(p.existeEn(3), isFalse);
      expect(p.stockEn(3), 0);
    });

    test('un producto sin entradas de stock no tiene último costo', () {
      final p = stockProductFromJson({'id': 1, 'codigo': 'A', 'name': 'A', 'stocks': [], 'warehouses': []});

      expect(p.ultimoCosto, isNull);
      expect(p.levels, isEmpty);
    });

    test('la subida de stocks lee las filas (lista u objeto) y los errores', () {
      final withList = stockImportResultFromJson({
        'message': [
          {'row_number': 2, 'codigo': 'SUB-1', 'costo': '10.5', 'stock': '4'},
          {'row_number': 3, 'codigo': 'SUB-2', 'costo': '', 'stock': 'x'},
        ],
        'failures': {
          'e-3': {
            'row': 3,
            'errors': ['El stock debe ser un número: x'],
          },
        },
      });

      expect(withList.rows.map((r) => r.codigo), ['SUB-1', 'SUB-2']);
      expect(withList.rows.first.costo, '10.5');
      expect(withList.rows.last.costo, isNull);
      expect(withList.hasFailures, isTrue);
      expect(withList.failureOf(3)!.errors, ['El stock debe ser un número: x']);
      expect(withList.failureOf(2), isNull);

      // El servidor devuelve un objeto con las posiciones como claves cuando descarta filas.
      final withMap = stockImportResultFromJson({
        'message': {
          '0': {'row_number': 2, 'codigo': 'A', 'stock': '1'},
          '2': {'row_number': 4, 'codigo': 'C', 'stock': '3'},
        },
      });

      expect(withMap.rows.map((r) => r.codigo), ['A', 'C']);
      expect(withMap.hasFailures, isFalse);
    });

    test('el costo de actualizar es el promedio, o el último si el promedio es 0 o no hay stock', () {
      StockItemEntity item({double? promedio, double? ultimo, double stock = 5}) => StockItemEntity(
            productId: 1,
            codigo: 'A',
            name: 'A',
            disponible: stock,
            costoPromedio: promedio,
            ultimoCosto: ultimo,
          );

      expect(stockUpdateCost(item(promedio: 10, ultimo: 12)), 10);
      expect(stockUpdateCost(item(promedio: 0, ultimo: 12)), 12);
      expect(stockUpdateCost(item(promedio: 10, ultimo: 12, stock: 0)), 12);
      expect(stockUpdateCost(item(promedio: 10, stock: 0)), 10);
      expect(stockUpdateCost(item()), 0);
    });
  });

  group('StockRemoteDataSource: operaciones', () {
    late http.BaseRequest sent;
    late String body;

    StockRemoteDataSourceImpl source(http.Response Function(http.Request) respond) => StockRemoteDataSourceImpl(
          client: MockClient((request) async {
            sent = request;
            body = utf8.decode(request.bodyBytes, allowMalformed: true);
            return respond(request);
          }),
        );

    test('la lista manda el tipo como filters[tipo][] y los términos como search[]', () async {
      final ds = source((_) => http.Response(jsonEncode({'data': [], 'current_page': 1, 'last_page': 1}), 200));

      await ds.getStock(
        token: 'tok',
        companyId: 7,
        warehouseId: 2,
        search: const ['tubo pvc', 'azul'],
        includeZero: true,
        page: 1,
        pageSize: 20,
        tipo: 's',
      );

      expect(sent.url.queryParametersAll['filters[tipo][]'], ['s']);
      expect(sent.url.queryParametersAll['search[]'], ['tubo pvc', 'azul']);
      expect(sent.url.queryParametersAll['include_0'], ['true']);
    });

    test('sin tipo no se manda el filtro', () async {
      final ds = source((_) => http.Response(jsonEncode({'data': [], 'current_page': 1, 'last_page': 1}), 200));

      await ds.getStock(
        token: 'tok',
        companyId: 7,
        warehouseId: 2,
        search: const [],
        includeZero: false,
        page: 1,
        pageSize: 20,
      );

      expect(sent.url.queryParametersAll.keys.any((k) => k.contains('tipo')), isFalse);
    });

    test('POST /stock manda el almacén y los datos como la web', () async {
      final ds = source((_) => http.Response(jsonEncode({'message': 'Stock actualizado con éxito'}), 200));

      await ds.addStock(
        token: 'tok',
        warehouseId: 2,
        items: const [
          (productId: 5, costo: 12.5, stock: 3),
          (productId: 6, costo: null, stock: -2),
        ],
      );

      expect(sent.method, 'POST');
      expect(sent.url.path, endsWith('/stock'));
      expect(jsonDecode(body), {
        'warehouse_id': 2,
        'datos': [
          {'product_id': 5, 'costo': 12.5, 'stock': 3},
          {'product_id': 6, 'costo': null, 'stock': -2},
        ],
      });
    });

    test('el buscador pide company_id, search y without_defaults', () async {
      final ds = source((_) => http.Response(
            jsonEncode([
              {
                'id': 7,
                'codigo': 'SUB-1',
                'name': 'SUBWOOFER',
                'warehouses': [
                  {
                    'id': 1,
                    'pivot': {'stock': 8, 'costo_promedio': 9},
                  },
                ],
              },
            ]),
            200,
          ));

      final found = await ds.searchProducts('tok', 7, 'sub');

      expect(sent.url.path, endsWith('/productos/search'));
      expect(sent.url.queryParameters, {'company_id': '7', 'search': 'sub', 'without_defaults': 'true'});
      expect(found.single.stockEn(1), 8);
    });

    test('la plantilla se pide por POST /stock/export', () async {
      final ds = source((_) => http.Response.bytes([1, 2, 3], 200));

      final bytes = await ds.downloadStockTemplate('tok');

      expect(sent.method, 'POST');
      expect(sent.url.path, endsWith('/stock/export'));
      expect(bytes, [1, 2, 3]);
    });

    test('subir stocks va en multipart con el archivo, el almacén y la empresa', () async {
      final ds = source((_) => http.Response(
            jsonEncode({
              'message': [
                {'row_number': 2, 'codigo': 'SUB-1', 'costo': '10', 'stock': '4'},
              ],
            }),
            200,
          ));

      final result = await ds.importStock(
        token: 'tok',
        companyId: 7,
        warehouseId: 2,
        fileName: 'stocks.xlsx',
        bytes: Uint8List.fromList(utf8.encode('EXCEL')),
      );

      expect(sent.method, 'POST');
      expect(sent.url.path, endsWith('/stock/import'));
      expect(sent.headers['content-type'], startsWith('multipart/form-data'));
      expect(body, contains('name="warehouse_id"'));
      expect(body, contains('name="company_id"'));
      expect(body, contains('name="file"; filename="stocks.xlsx"'));
      expect(result.rows.single.codigo, 'SUB-1');
    });

    test('transferir manda from, to, usuario, empresa y productos, y devuelve el traslado', () async {
      final ds = source((_) => http.Response(
            jsonEncode({
              'id': 31,
              'nro_documento': 31,
              'from': 1,
              'to': 2,
              'estado': true,
              'from_warehouse': {'id': 1, 'name': 'LIMA'},
              'to_warehouse': {'id': 2, 'name': 'AREQUIPA'},
              'user': {'id': 9, 'name': 'Ana'},
              'products': [],
            }),
            200,
          ));

      final doc = await ds.transferStock(
        token: 'tok',
        companyId: 7,
        userId: 9,
        from: 1,
        to: 2,
        items: const [(productId: 5, cantidad: 3.0)],
      );

      expect(sent.url.path, endsWith('/stock-transfer'));
      expect(jsonDecode(body), {
        'from': 1,
        'to': 2,
        'user_id': 9,
        'company_id': 7,
        'products': [
          {'product_id': 5, 'cantidad': 3.0},
        ],
      });
      expect(doc.numero, 'T001-0031');
      expect(doc.desde, 'LIMA');
      expect(doc.hacia, 'AREQUIPA');
    });

    test('un 400 del servidor llega con su mensaje', () async {
      final ds = source((_) => http.Response(jsonEncode({'error': 'El producto no tiene stock suficiente'}), 400));

      await expectLater(
        ds.transferStock(
          token: 'tok',
          companyId: 7,
          userId: 9,
          from: 1,
          to: 2,
          items: const [(productId: 5, cantidad: 3.0)],
        ),
        throwsA(isA<Exception>()),
      );
    });
  });

  group('casos de uso de stock', () {
    late _FakeStockRepository repo;
    setUp(() => repo = _FakeStockRepository());

    test('buscar sin texto no pide nada', () async {
      final result = await SearchStockProductsUseCase(repository: repo)(companyId: 7, search: '   ');

      expect(result.right, isEmpty);
      expect(repo.searches, isEmpty);
    });

    test('buscar recorta el texto', () async {
      await SearchStockProductsUseCase(repository: repo)(companyId: 7, search: '  sub  ');

      expect(repo.searches, ['sub']);
    });

    test('agregar stock pide almacén y al menos un producto', () async {
      final add = AddStockUseCase(repository: repo);

      expect((await add(warehouseId: null, lines: [StockEntryLine(product: product(1))])).left.message, 'Elige un almacén');
      expect((await add(warehouseId: 1, lines: const [])).left.message, 'Agrega al menos un producto');
      expect(repo.adds, isEmpty);
    });

    test('agregar stock no acepta cantidades menores a 1', () async {
      final result = await AddStockUseCase(repository: repo)(
        warehouseId: 1,
        lines: [StockEntryLine(product: product(1), stock: 0)],
      );

      expect(result.left.message, contains('SUB-1'));
      expect(repo.adds, isEmpty);
    });

    test('agregar stock manda el costo en nulo si es 0 o está vacío', () async {
      await AddStockUseCase(repository: repo)(
        warehouseId: 2,
        lines: [
          StockEntryLine(product: product(1), stock: 5, costo: 12.5),
          StockEntryLine(product: product(2), stock: 3, costo: 0),
          StockEntryLine(product: product(3), stock: 1),
        ],
      );

      expect(repo.adds.single.warehouseId, 2);
      expect(repo.adds.single.items, [
        (productId: 1, costo: 12.5, stock: 5),
        (productId: 2, costo: null, stock: 3),
        (productId: 3, costo: null, stock: 1),
      ]);
    });

    test('actualizar manda la diferencia con el costo promedio', () async {
      const item = StockItemEntity(
        productId: 5,
        codigo: 'A',
        name: 'A',
        disponible: 10,
        costoPromedio: 8,
        ultimoCosto: 9,
      );
      final update = UpdateStockUseCase(repository: repo);

      await update(warehouseId: 1, item: item, newStock: 14);
      await update(warehouseId: 1, item: item, newStock: 4);

      expect(repo.adds[0].items.single, (productId: 5, costo: 8.0, stock: 4));
      expect(repo.adds[1].items.single, (productId: 5, costo: 8.0, stock: -6));
    });

    test('actualizar usa el último costo si el promedio es 0', () async {
      const item = StockItemEntity(
        productId: 5,
        codigo: 'A',
        name: 'A',
        disponible: 10,
        costoPromedio: 0,
        ultimoCosto: 9,
      );

      await UpdateStockUseCase(repository: repo)(warehouseId: 1, item: item, newStock: 11);

      expect(repo.adds.single.items.single.costo, 9);
    });

    test('actualizar rechaza lo que no cambia, lo negativo y lo decimal', () async {
      const item = StockItemEntity(productId: 5, codigo: 'A', name: 'A', disponible: 10);
      final update = UpdateStockUseCase(repository: repo);

      expect((await update(warehouseId: 1, item: item, newStock: 10)).left.message, contains('mismo'));
      expect((await update(warehouseId: 1, item: item, newStock: -1)).left.message, contains('entero'));
      expect((await update(warehouseId: 1, item: item, newStock: 2.5)).left.message, contains('entero'));
      expect(repo.adds, isEmpty);
    });

    test('actualizar puede dejar el stock en 0', () async {
      const item = StockItemEntity(productId: 5, codigo: 'A', name: 'A', disponible: 10, costoPromedio: 3);

      final result = await UpdateStockUseCase(repository: repo)(warehouseId: 1, item: item, newStock: 0);

      expect(result.isRight, isTrue);
      expect(repo.adds.single.items.single.stock, -10);
    });

    test('subir stocks pide un almacén', () async {
      final result = await ImportStockUseCase(repository: repo)(
        companyId: 7,
        warehouseId: null,
        fileName: 'a.xlsx',
        bytes: Uint8List(1),
      );

      expect(result.left.message, 'Elige un almacén');
      expect(repo.imports, isEmpty);
    });

    group('transferir', () {
      Future<Either<Failure, OtherDocumentEntity>> transfer({
        int? userId = 9,
        int? from = 1,
        int? to = 2,
        List<StockTransferLine>? lines,
      }) =>
          TransferStockUseCase(repository: repo)(
            companyId: 7,
            userId: userId,
            from: from,
            to: to,
            lines: lines ?? [StockTransferLine(product: product(1), cantidad: 3)],
          );

      test('manda los productos con su cantidad y el usuario', () async {
        final result = await transfer();

        expect(result.isRight, isTrue);
        expect(repo.transfers.single.userId, 9);
        expect(repo.transfers.single.from, 1);
        expect(repo.transfers.single.to, 2);
        expect(repo.transfers.single.items, [(productId: 1, cantidad: 3.0)]);
      });

      test('pide origen, destino y que sean distintos', () async {
        expect((await transfer(from: null)).left.message, 'Elige el almacén de origen');
        expect((await transfer(to: null)).left.message, 'Elige el almacén de destino');
        expect((await transfer(to: 1)).left.message, 'No puede transferir al mismo almacén');
        expect(repo.transfers, isEmpty);
      });

      test('pide al menos un producto y un usuario con sesión', () async {
        expect((await transfer(lines: const [])).left.message, 'Agrega al menos un producto');
        expect((await transfer(userId: null)).left.message, contains('sesión'));
      });

      test('no deja pasar más de lo que hay en el origen, menos de 1 ni productos que no están', () async {
        expect(
          (await transfer(lines: [StockTransferLine(product: product(1), cantidad: 9)])).left.message,
          'Stock insuficiente de SUB-1',
        );
        expect(
          (await transfer(lines: [StockTransferLine(product: product(1), cantidad: 0.5)])).left.message,
          contains('1 o más'),
        );
        expect(
          (await transfer(lines: [StockTransferLine(product: product(1, levels: const {}), cantidad: 1)])).left.message,
          contains('no existe en el almacén de origen'),
        );
        expect(repo.transfers, isEmpty);
      });
    });
  });

  group('StockProvider: filtros y operaciones', () {
    late _FakeStockRepository repo;
    late StockProvider provider;

    setUp(() async {
      repo = _FakeStockRepository();
      provider = _provider(repo)..syncSession(7, defaultWarehouseId: 1, defaultPriceListId: 10, userId: 9);
      await provider.ensureLoaded();
    });

    test('el tipo se manda al repositorio y activa el indicador de filtros', () async {
      expect(provider.filtersActive, isFalse);

      await provider.setTipo('s');

      expect(repo.tipos.last, 's');
      expect(provider.filtersActive, isTrue);
      expect(repo.calls.last.page, 1);

      await provider.setTipo(null);
      expect(repo.tipos.last, isNull);
      expect(provider.filtersActive, isFalse);
    });

    test('setFilters cambia incluir-sin-stock y tipo con un solo pedido', () async {
      final before = repo.calls.length;

      await provider.setFilters(includeZero: true, tipo: 'p');

      expect(repo.calls.length, before + 1);
      expect(repo.calls.last.includeZero, isTrue);
      expect(repo.tipos.last, 'p');
    });

    test('los términos confirmados se suman a lo que se escribe y viajan al Excel', () async {
      await provider.addSearchTerm('tubo pvc');
      await provider.setSearch('azul');

      expect(provider.searchTerms, ['tubo pvc']);
      expect(repo.calls.last.search, ['tubo pvc', 'azul']);

      await provider.exportCurrent();
      expect(repo.exports.last.search, ['tubo pvc', 'azul']);
    });

    test('confirmar un término no repite ni acepta vacíos, y quitarlo vuelve a pedir', () async {
      await provider.addSearchTerm('uno');
      await provider.addSearchTerm('uno');
      await provider.addSearchTerm('  ');
      expect(provider.searchTerms, ['uno']);

      await provider.addSearchTerm('dos');
      await provider.removeSearchTerm('uno');
      expect(repo.calls.last.search, ['dos']);

      await provider.clearSearchTerms();
      expect(repo.calls.last.search, isEmpty);
    });

    test('cambiar de empresa limpia tipo y términos', () async {
      await provider.setTipo('s');
      await provider.addSearchTerm('uno');

      provider.syncSession(8, userId: 9);

      expect(provider.tipo, isNull);
      expect(provider.searchTerms, isEmpty);
    });

    test('agregar stock al almacén que se está viendo recarga la lista', () async {
      final before = repo.calls.length;

      final problem = await provider.addStock(1, [StockEntryLine(product: product(1), stock: 2, costo: 5)]);

      expect(problem, isNull);
      expect(repo.adds.single.warehouseId, 1);
      expect(repo.calls.length, before + 1);
    });

    test('agregar stock a otro almacén no recarga la lista', () async {
      final before = repo.calls.length;

      await provider.addStock(2, [StockEntryLine(product: product(1), stock: 2)]);

      expect(repo.calls.length, before);
    });

    test('un error al agregar stock vuelve como mensaje y no recarga', () async {
      repo.nextAdd = Either.left(const ValidationFailure('El producto no existe'));
      final before = repo.calls.length;

      final problem = await provider.addStock(1, [StockEntryLine(product: product(1))]);

      expect(problem, 'El producto no existe');
      expect(repo.calls.length, before);
    });

    test('actualizar usa el almacén elegido y recarga', () async {
      const item = StockItemEntity(productId: 5, codigo: 'A', name: 'A', disponible: 10, costoPromedio: 8);
      final before = repo.calls.length;

      final problem = await provider.updateStock(item, 12);

      expect(problem, isNull);
      expect(repo.adds.single.warehouseId, 1);
      expect(repo.adds.single.items.single.stock, 2);
      expect(repo.calls.length, before + 1);
    });

    test('actualizar con el mismo stock devuelve el motivo y no llama al servidor', () async {
      const item = StockItemEntity(productId: 5, codigo: 'A', name: 'A', disponible: 10);

      final problem = await provider.updateStock(item, 10);

      expect(problem, contains('mismo'));
      expect(repo.adds, isEmpty);
    });

    test('subir stocks devuelve las filas y recarga si es el almacén que se ve', () async {
      final before = repo.calls.length;

      final result = await provider.importStock(warehouseId: 1, fileName: 's.xlsx', bytes: Uint8List(4));

      expect(result.right.rows.single.codigo, 'SUB-1');
      expect(repo.imports.single.warehouseId, 1);
      expect(repo.calls.length, before + 1);
    });

    test('transferir manda el usuario de la sesión y recarga si toca el almacén que se ve', () async {
      final before = repo.calls.length;

      final result = await provider.transferStock(
        from: 1,
        to: 2,
        lines: [StockTransferLine(product: product(1), cantidad: 2)],
      );

      expect(result.right.numero, 'T001-0031');
      expect(repo.transfers.single.userId, 9);
      expect(repo.calls.length, before + 1);
    });

    test('una transferencia entre otros dos almacenes no recarga la lista', () async {
      final before = repo.calls.length;

      await provider.transferStock(
        from: 2,
        to: 3,
        lines: [StockTransferLine(product: product(1, levels: const {2: StockWarehouseLevel(stock: 5)}), cantidad: 2)],
      );

      expect(repo.calls.length, before);
    });

    test('la plantilla se pide al repositorio', () async {
      final result = await provider.downloadStockTemplate();

      expect(result.right.name, 'Plantilla de Productos(Stock).xlsx');
      expect(repo.templates, 1);
    });

    test('buscar productos pasa el texto al repositorio', () async {
      repo.products = [product(1)];

      final result = await provider.searchProducts('sub');

      expect(result.right.single.id, 1);
      expect(repo.searches, ['sub']);
    });
  });

  // ---------------------------------------------------------------------------------------------
  // Pantallas
  // ---------------------------------------------------------------------------------------------

  Future<_FakeStockRepository> pumpPage(
    WidgetTester tester,
    Widget page, {
    Set<String> permissions = const {'stock.show', 'stock.store', 'stock.update', 'transferir-stock.store'},
    List<String> roles = const [],
    void Function(_FakeStockRepository repo)? setUpRepo,
    StockProvider? provider,
    bool preload = true,
  }) async {
    // Las pruebas dibujan con la fuente Ahem (casi el doble de ancha que una real).
    tester.view.physicalSize = const Size(360 * 3, 780 * 3);
    tester.view.devicePixelRatio = 3;
    tester.platformDispatcher.textScaleFactorTestValue = 0.55;
    addTearDown(() {
      tester.view.reset();
      tester.platformDispatcher.clearTextScaleFactorTestValue();
    });

    final repo = _FakeStockRepository();
    setUpRepo?.call(repo);
    final stock = provider ?? _provider(repo)
      ..syncSession(7, defaultWarehouseId: 1, defaultPriceListId: 10, userId: 9);
    // Las pantallas de agregar y transferir usan los almacenes que ya cargó la de Stock.
    if (preload && page is! StockPage) await stock.ensureLoaded();
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<ThemeProvider>(
            create: (_) => ThemeProvider(storage: _FakeThemeStorage()),
          ),
          ChangeNotifierProvider<AuthProvider>.value(
            value: _auth(_session(permissions: permissions, roles: roles)),
          ),
          ChangeNotifierProvider<StockProvider>.value(value: stock),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: page is StockPage ? Scaffold(body: page) : page,
        ),
      ),
    );
    await tester.pumpAndSettle();
    return repo;
  }

  Future<void> searchFor(WidgetTester tester, String text) async {
    await tester.enterText(find.byType(SearchBar), text);
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();
  }

  group('StockPage: permisos, filtros y acciones', () {
    const todos = {'stock.show', 'stock.store', 'stock.update', 'transferir-stock.store'};

    testWidgets('sin ningún permiso de stock se avisa que no hay acceso', (tester) async {
      final repo = await pumpPage(tester, const StockPage(), permissions: const {});

      expect(find.text('Sin acceso'), findsOneWidget);
      expect(find.text('Producto 1'), findsNothing);
      // Y no se pide nada al servidor.
      expect(repo.calls, isEmpty);
    });

    testWidgets('con solo almacenes.show se ve la lista', (tester) async {
      await pumpPage(tester, const StockPage(), permissions: const {'almacenes.show'});

      expect(find.text('Producto 1'), findsOneWidget);
      expect(find.text('Sin acceso'), findsNothing);
    });

    testWidgets('con solo stock.store no hay lista pero sí la acción de agregar', (tester) async {
      final repo = await pumpPage(tester, const StockPage(), permissions: const {'stock.store'});

      expect(find.text('Solo puedes registrar stock'), findsOneWidget);
      expect(find.text('Producto 1'), findsNothing);
      expect(find.byType(SearchBar), findsNothing);
      expect(repo.calls, isEmpty);

      await tester.tap(find.text('Acciones'));
      await tester.pumpAndSettle();
      expect(find.byTooltip('Agregar stock'), findsOneWidget);
      expect(find.byTooltip('Transferir stock'), findsNothing);
    });

    testWidgets('Acciones ofrece agregar y transferir solo con sus permisos', (tester) async {
      await pumpPage(tester, const StockPage(), permissions: todos);

      await tester.tap(find.text('Acciones'));
      await tester.pumpAndSettle();

      expect(find.byTooltip('Agregar stock'), findsOneWidget);
      expect(find.byTooltip('Transferir stock'), findsOneWidget);
      expect(find.byTooltip('Exportar'), findsOneWidget);
    });

    testWidgets('sin esos permisos solo queda Exportar, directo', (tester) async {
      await pumpPage(tester, const StockPage(), permissions: const {'stock.show'});

      expect(find.text('Acciones'), findsNothing);
      expect(find.text('Exportar'), findsOneWidget);
      expect(find.text('Agregar stock'), findsNothing);
      expect(find.text('Transferir stock'), findsNothing);
    });

    testWidgets('el panel de filtros ofrece el tipo y lo aplica', (tester) async {
      final repo = await pumpPage(tester, const StockPage());

      await tester.tap(find.byTooltip('Filtros'));
      await tester.pumpAndSettle();
      expect(find.text('Tipo'), findsOneWidget);

      await tester.tap(find.widgetWithText(DropdownButtonFormField<String?>, 'Tipo'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Servicios').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ver resultados'));
      await tester.pumpAndSettle();

      expect(repo.tipos.last, 's');
    });

    testWidgets('enviar la búsqueda la vuelve un chip que se puede quitar', (tester) async {
      final repo = await pumpPage(tester, const StockPage());

      await tester.enterText(find.byType(SearchBar), 'tubo pvc');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('chip-tubo pvc')), findsOneWidget);
      expect(repo.calls.last.search, ['tubo pvc']);
      expect(tester.widget<SearchBar>(find.byType(SearchBar)).controller!.text, isEmpty);

      await tester.tap(find.byTooltip('Quitar "tubo pvc"'));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('chip-tubo pvc')), findsNothing);
      expect(repo.calls.last.search, isEmpty);
    });

    testWidgets('la tarjeta ofrece Actualizar stock solo con stock.update', (tester) async {
      await pumpPage(tester, const StockPage(), permissions: const {'stock.show'});
      expect(find.byTooltip('Actualizar stock'), findsNothing);
    });

    group('Actualizar stock', () {
      void withItem(_FakeStockRepository repo) => repo.itemsOverride = const [
            StockItemEntity(
              productId: 5,
              codigo: 'SUB-5',
              name: 'SUBWOOFER 12',
              disponible: 10,
              costoPromedio: 8,
              ultimoCosto: 9,
            ),
          ];

      testWidgets('muestra el stock actual y se habilita al escribir otro valor', (tester) async {
        await pumpPage(tester, const StockPage(), setUpRepo: withItem);

        await tester.tap(find.byTooltip('Actualizar stock'));
        await tester.pumpAndSettle();

        expect(find.text('Actualizar stock'), findsOneWidget);
        expect(find.text('Stock actual'), findsOneWidget);
        FilledButton button() => tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Actualizar'));
        // Con el mismo valor no hay nada que actualizar.
        expect(button().onPressed, isNull);

        await tester.enterText(find.byKey(const ValueKey('stock-nuevo')), '14');
        await tester.pumpAndSettle();

        expect(button().onPressed, isNotNull);
        expect(find.text('Se suman 4'), findsOneWidget);

        await tester.enterText(find.byKey(const ValueKey('stock-nuevo')), '4');
        await tester.pumpAndSettle();
        expect(find.text('Se restan 6'), findsOneWidget);
      });

      testWidgets('manda la diferencia al servidor y recarga', (tester) async {
        final repo = await pumpPage(tester, const StockPage(), setUpRepo: withItem);
        final before = repo.calls.length;

        await tester.tap(find.byTooltip('Actualizar stock'));
        await tester.pumpAndSettle();
        await tester.enterText(find.byKey(const ValueKey('stock-nuevo')), '14');
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(FilledButton, 'Actualizar'));
        await tester.pumpAndSettle();

        expect(repo.adds.single.warehouseId, 1);
        expect(repo.adds.single.items.single, (productId: 5, costo: 8.0, stock: 4));
        expect(repo.calls.length, before + 1);
        expect(find.text('Cambio Registrado'), findsOneWidget);
      });

      testWidgets('si el servidor rechaza, el modal sigue abierto con el motivo', (tester) async {
        final repo = await pumpPage(tester, const StockPage(), setUpRepo: withItem);
        repo.nextAdd = Either.left(const ValidationFailure('Sin permiso para cambiar stock'));

        await tester.tap(find.byTooltip('Actualizar stock'));
        await tester.pumpAndSettle();
        await tester.enterText(find.byKey(const ValueKey('stock-nuevo')), '3');
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(FilledButton, 'Actualizar'));
        await tester.pumpAndSettle();

        expect(find.text('Sin permiso para cambiar stock'), findsOneWidget);
        expect(find.byKey(const ValueKey('stock-nuevo')), findsOneWidget);
      });

      testWidgets('el costo solo se muestra a quien puede verlo', (tester) async {
        await pumpPage(
          tester,
          const StockPage(),
          permissions: const {'stock.show', 'stock.update'},
          setUpRepo: withItem,
        );
        await tester.tap(find.byTooltip('Actualizar stock'));
        await tester.pumpAndSettle();
        expect(find.text('Costo'), findsNothing);

        // Con el permiso de costos aparece.
        await tester.tap(find.text('Cancelar'));
        await tester.pumpAndSettle();
      });

      testWidgets('con permiso de costos se ve el costo que se usará', (tester) async {
        await pumpPage(
          tester,
          const StockPage(),
          permissions: const {'stock.show', 'stock.update', 'almacenes.show.costo_promedio'},
          setUpRepo: withItem,
        );
        await tester.tap(find.byTooltip('Actualizar stock'));
        await tester.pumpAndSettle();

        expect(find.text('Costo'), findsWidgets);
        expect(find.text('S/. 8.00'), findsWidgets);
      });
    });
  });

  group('StockAddPage', () {
    void withProducts(_FakeStockRepository repo) => repo.products = [
          product(1, name: 'SUBWOOFER 12'),
          product(2, name: 'PARLANTE 6', ultimoCosto: null),
        ];

    Future<_FakeStockRepository> openAdd(
      WidgetTester tester, {
      Future<PickedImportFile?> Function()? pickFile,
    }) =>
        pumpPage(tester, StockAddPage(pickFile: pickFile ?? pickImportFile), setUpRepo: withProducts);

    testWidgets('empieza vacía, con el almacén que se estaba viendo y Guardar apagado', (tester) async {
      await openAdd(tester);

      expect(find.text('Agregar stock'), findsOneWidget);
      expect(find.text('Aún no hay productos'), findsOneWidget);
      expect(find.text('LIMA'), findsOneWidget);
      expect(
        tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Guardar')).onPressed,
        isNull,
      );
    });

    testWidgets('buscar muestra los productos y tocar uno lo agrega con 1 unidad y su último costo', (tester) async {
      await openAdd(tester);

      await searchFor(tester, 'sub');
      expect(find.text('SUBWOOFER 12'), findsOneWidget);
      expect(find.byKey(const ValueKey('resultado-2')), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('resultado-1')));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('linea-1')), findsOneWidget);
      expect(tester.widget<TextField>(find.byKey(const ValueKey('campo-stock'))).controller!.text, '1');
      expect(tester.widget<TextField>(find.byKey(const ValueKey('campo-costo'))).controller!.text, '10.5');
      expect(find.text('S/ 10.50'), findsNothing); // el total usa el símbolo de la web
      expect(find.text('S/. 10.50'), findsOneWidget);
    });

    testWidgets('tocar el mismo producto otra vez suma una unidad', (tester) async {
      await openAdd(tester);
      await searchFor(tester, 'sub');

      await tester.tap(find.byKey(const ValueKey('resultado-1')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('resultado-1')));
      await tester.pumpAndSettle();

      expect(tester.widget<TextField>(find.byKey(const ValueKey('campo-stock'))).controller!.text, '2');
      expect(find.text('S/. 21.00'), findsOneWidget);
    });

    testWidgets('un producto sin entradas previas entra sin costo', (tester) async {
      await openAdd(tester);
      await searchFor(tester, 'par');

      await tester.tap(find.byKey(const ValueKey('resultado-2')));
      await tester.pumpAndSettle();

      expect(tester.widget<TextField>(find.byKey(const ValueKey('campo-costo'))).controller!.text, isEmpty);
      expect(find.text('S/. 0.00'), findsOneWidget);
    });

    testWidgets('el total sale de costo por stock y se actualiza al escribir', (tester) async {
      await openAdd(tester);
      await searchFor(tester, 'sub');
      await tester.tap(find.byKey(const ValueKey('resultado-1')));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const ValueKey('campo-stock')), '4');
      await tester.enterText(find.byKey(const ValueKey('campo-costo')), '12.25');
      await tester.pumpAndSettle();

      expect(find.text('S/. 49.00'), findsOneWidget);
    });

    testWidgets('una cantidad vacía o 0 bloquea Guardar y avisa el mínimo', (tester) async {
      await openAdd(tester);
      await searchFor(tester, 'sub');
      await tester.tap(find.byKey(const ValueKey('resultado-1')));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const ValueKey('campo-stock')), '0');
      await tester.pumpAndSettle();

      expect(find.text('Mínimo 1'), findsOneWidget);
      expect(
        tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Guardar')).onPressed,
        isNull,
      );
    });

    testWidgets('quitar la línea vuelve al estado vacío', (tester) async {
      await openAdd(tester);
      await searchFor(tester, 'sub');
      await tester.tap(find.byKey(const ValueKey('resultado-1')));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Quitar'));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('linea-1')), findsNothing);
      expect(find.text('Aún no hay productos'), findsOneWidget);
    });

    testWidgets('guardar pide confirmar y manda el aumento con el costo en nulo si es 0', (tester) async {
      final repo = await openAdd(tester);
      await searchFor(tester, 'sub');
      await tester.tap(find.byKey(const ValueKey('resultado-1')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('resultado-2')));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const ValueKey('campo-stock')).first, '5');
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Guardar'));
      await tester.pumpAndSettle();

      expect(find.text('¿Desea confirmar el aumento de Stock?'), findsOneWidget);
      expect(repo.adds, isEmpty);

      await tester.tap(find.widgetWithText(FilledButton, 'Confirmar'));
      await tester.pumpAndSettle();

      expect(repo.adds.single.warehouseId, 1);
      expect(repo.adds.single.items, [
        (productId: 1, costo: 10.5, stock: 5),
        (productId: 2, costo: null, stock: 1),
      ]);
    });

    testWidgets('cancelar la confirmación no guarda nada', (tester) async {
      final repo = await openAdd(tester);
      await searchFor(tester, 'sub');
      await tester.tap(find.byKey(const ValueKey('resultado-1')));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(FilledButton, 'Guardar'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();

      expect(repo.adds, isEmpty);
      expect(find.byKey(const ValueKey('linea-1')), findsOneWidget);
    });

    testWidgets('si el servidor rechaza el aumento, la pantalla sigue con sus líneas y el motivo', (tester) async {
      final repo = await openAdd(tester);
      repo.nextAdd = Either.left(const ValidationFailure('El producto no existe'));
      await searchFor(tester, 'sub');
      await tester.tap(find.byKey(const ValueKey('resultado-1')));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(FilledButton, 'Guardar'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Confirmar'));
      await tester.pumpAndSettle();

      expect(find.text('El producto no existe'), findsOneWidget);
      expect(find.byKey(const ValueKey('linea-1')), findsOneWidget);
    });

    testWidgets('una búsqueda sin resultados lo dice', (tester) async {
      await pumpPage(tester, const StockAddPage(), setUpRepo: (r) => r.products = const []);

      await searchFor(tester, 'zzz');

      expect(find.text('No se encontraron productos'), findsOneWidget);
    });

    testWidgets('en la lista de resultados se ve lo que hay en el almacén elegido', (tester) async {
      await openAdd(tester);

      await searchFor(tester, 'sub');

      expect(find.textContaining('En el almacén: 8'), findsWidgets);
    });

    testWidgets('Plantilla pide el Excel al servidor', (tester) async {
      final repo = await openAdd(tester);

      await tester.tap(find.text('Plantilla'));
      await tester.pumpAndSettle();

      expect(repo.templates, 1);
    });

    testWidgets('Subir stocks sube el archivo al almacén y muestra las filas leídas', (tester) async {
      final repo = await openAdd(
        tester,
        pickFile: () async => (name: 'stocks.xlsx', bytes: Uint8List.fromList([1, 2, 3, 4])),
      );

      await tester.tap(find.text('Subir stocks'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Toca para elegir un archivo'));
      await tester.pumpAndSettle();
      expect(find.text('stocks.xlsx'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Subir'));
      await tester.pumpAndSettle();

      expect(repo.imports.single.warehouseId, 1);
      expect(repo.imports.single.fileName, 'stocks.xlsx');
      expect(repo.imports.single.size, 4);
      expect(find.text('Se subieron los stocks'), findsOneWidget);
      expect(find.text('SUB-1'), findsOneWidget);
      expect(find.text('Stock: 4'), findsOneWidget);
      expect(find.text('Costo: S/. 10.50'), findsOneWidget);
    });

    testWidgets('las filas con error se muestran con su motivo', (tester) async {
      final repo = await openAdd(
        tester,
        pickFile: () async => (name: 'stocks.xlsx', bytes: Uint8List.fromList([1])),
      );
      repo.nextImport = Either.right(const StockImportResultEntity(
        rows: [
          StockImportRow(row: 2, codigo: 'SUB-1', costo: '10', stock: '4'),
          StockImportRow(row: 3, codigo: 'SUB-2', stock: 'x'),
        ],
        failures: [
          ImportFailureEntity(row: 3, errors: ['El stock debe ser un número: x']),
        ],
      ));

      await tester.tap(find.text('Subir stocks'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Toca para elegir un archivo'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Subir'));
      await tester.pumpAndSettle();

      expect(find.text('Menos las filas con error'), findsOneWidget);
      expect(find.text('Error en fila 3'), findsOneWidget);
      expect(find.text('• El stock debe ser un número: x'), findsOneWidget);
    });

    testWidgets('si el servidor rechaza el archivo, el modal queda abierto con el motivo', (tester) async {
      final repo = await openAdd(
        tester,
        pickFile: () async => (name: 'stocks.xlsx', bytes: Uint8List.fromList([1])),
      );
      repo.nextImport = Either.left(const ValidationFailure('El archivo no es un Excel'));

      await tester.tap(find.text('Subir stocks'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Toca para elegir un archivo'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Subir'));
      await tester.pumpAndSettle();

      expect(find.text('El archivo no es un Excel'), findsOneWidget);
      expect(find.text('Se subieron los stocks'), findsNothing);
    });
  });

  group('StockTransferPage', () {
    // En LIMA (1) hay 8; en AREQUIPA (2) hay 0; CUSCO (3) no lo tiene.
    void withProducts(_FakeStockRepository repo) => repo.products = [
          product(1, name: 'SUBWOOFER 12'),
          product(2, name: 'PARLANTE 6', levels: const {1: StockWarehouseLevel(stock: 0)}),
          product(3, name: 'TWEETER', levels: const {2: StockWarehouseLevel(stock: 5)}),
        ];

    Future<_FakeStockRepository> openTransfer(WidgetTester tester) =>
        pumpPage(tester, const StockTransferPage(), setUpRepo: withProducts);

    Future<void> chooseDestination(WidgetTester tester, String name) async {
      await tester.tap(find.widgetWithText(DropdownButtonFormField<int>, 'Hacia'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(name).last);
      await tester.pumpAndSettle();
    }

    FilledButton transferButton(WidgetTester tester) =>
        tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Transferir'));

    testWidgets('empieza con el almacén que se veía de origen y sin destino', (tester) async {
      await openTransfer(tester);

      expect(find.text('Transferir stock'), findsOneWidget);
      expect(find.text('LIMA'), findsOneWidget);
      expect(find.text('Aún no hay productos'), findsOneWidget);
      expect(transferButton(tester).onPressed, isNull);
    });

    testWidgets('el destino no ofrece el almacén de origen', (tester) async {
      await openTransfer(tester);

      await tester.tap(find.widgetWithText(DropdownButtonFormField<int>, 'Hacia'));
      await tester.pumpAndSettle();

      expect(find.text('AREQUIPA'), findsWidgets);
      expect(find.text('CUSCO'), findsWidgets);
      // LIMA solo está como origen, no como opción del destino.
      expect(find.text('LIMA'), findsOneWidget);
    });

    testWidgets('un producto con stock en el origen se agrega y muestra lo disponible', (tester) async {
      await openTransfer(tester);

      await searchFor(tester, 'sub');
      expect(find.textContaining('LIMA: 8'), findsWidgets);
      await tester.tap(find.byKey(const ValueKey('resultado-1')));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('linea-1')), findsOneWidget);
      expect(tester.widget<TextField>(find.byKey(const ValueKey('campo-cantidad'))).controller!.text, '1');
      expect(find.text('Disponible: 8'), findsOneWidget);
    });

    testWidgets('un producto sin stock en el origen no se agrega y se avisa', (tester) async {
      await openTransfer(tester);
      await searchFor(tester, 'par');

      await tester.tap(find.byKey(const ValueKey('resultado-2')));
      await tester.pumpAndSettle();

      expect(find.text('No hay stock disponible en LIMA'), findsOneWidget);
      expect(find.byKey(const ValueKey('linea-2')), findsNothing);
    });

    testWidgets('un producto que no existe en el origen tampoco se agrega', (tester) async {
      await openTransfer(tester);
      await searchFor(tester, 'twe');

      await tester.tap(find.byKey(const ValueKey('resultado-3')));
      await tester.pumpAndSettle();

      expect(find.text('No hay stock disponible en LIMA'), findsOneWidget);
      expect(find.byKey(const ValueKey('linea-3')), findsNothing);
    });

    testWidgets('tocar el mismo producto suma una unidad hasta lo que hay', (tester) async {
      await openTransfer(tester);
      await searchFor(tester, 'sub');

      for (var i = 0; i < 9; i++) {
        await tester.tap(find.byKey(const ValueKey('resultado-1')));
        await tester.pump();
      }
      await tester.pumpAndSettle();

      // Empieza en 1 y sube hasta 8; el noveno toque avisa.
      expect(tester.widget<TextField>(find.byKey(const ValueKey('campo-cantidad'))).controller!.text, '8');
      expect(find.text('Stock insuficiente'), findsOneWidget);
    });

    testWidgets('una cantidad mayor a la que hay marca el error y bloquea Transferir', (tester) async {
      await openTransfer(tester);
      await searchFor(tester, 'sub');
      await tester.tap(find.byKey(const ValueKey('resultado-1')));
      await tester.pumpAndSettle();
      await chooseDestination(tester, 'AREQUIPA');

      expect(transferButton(tester).onPressed, isNotNull);

      await tester.enterText(find.byKey(const ValueKey('campo-cantidad')), '9');
      await tester.pumpAndSettle();

      expect(find.text('Stock insuficiente (máx. 8)'), findsOneWidget);
      expect(transferButton(tester).onPressed, isNull);

      await tester.enterText(find.byKey(const ValueKey('campo-cantidad')), '0');
      await tester.pumpAndSettle();
      expect(find.text('Mínimo 1'), findsOneWidget);
      expect(transferButton(tester).onPressed, isNull);
    });

    testWidgets('sin destino no se puede transferir', (tester) async {
      await openTransfer(tester);
      await searchFor(tester, 'sub');
      await tester.tap(find.byKey(const ValueKey('resultado-1')));
      await tester.pumpAndSettle();

      expect(transferButton(tester).onPressed, isNull);
    });

    testWidgets('transferir pide confirmar, manda el traslado y muestra su número', (tester) async {
      final repo = await openTransfer(tester);
      await searchFor(tester, 'sub');
      await tester.tap(find.byKey(const ValueKey('resultado-1')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const ValueKey('campo-cantidad')), '3');
      await chooseDestination(tester, 'AREQUIPA');

      await tester.tap(find.widgetWithText(FilledButton, 'Transferir'));
      await tester.pumpAndSettle();
      expect(find.text('¿Desea confirmar la Transferencia de Stock?'), findsOneWidget);
      expect(repo.transfers, isEmpty);

      await tester.tap(find.widgetWithText(FilledButton, 'Confirmar'));
      await tester.pumpAndSettle();

      expect(repo.transfers.single.userId, 9);
      expect(repo.transfers.single.from, 1);
      expect(repo.transfers.single.to, 2);
      expect(repo.transfers.single.items, [(productId: 1, cantidad: 3.0)]);
      expect(find.text('T001-0031'), findsOneWidget);
      expect(find.text('Traslados de Stock'), findsOneWidget);
    });

    testWidgets('cancelar la confirmación no transfiere nada', (tester) async {
      final repo = await openTransfer(tester);
      await searchFor(tester, 'sub');
      await tester.tap(find.byKey(const ValueKey('resultado-1')));
      await tester.pumpAndSettle();
      await chooseDestination(tester, 'AREQUIPA');

      await tester.tap(find.widgetWithText(FilledButton, 'Transferir'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();

      expect(repo.transfers, isEmpty);
      expect(find.byKey(const ValueKey('linea-1')), findsOneWidget);
    });

    testWidgets('si el servidor rechaza, se ve el motivo y quedan las líneas', (tester) async {
      final repo = await openTransfer(tester);
      repo.nextTransfer = Either.left(const ValidationFailure('El producto no tiene stock suficiente'));
      await searchFor(tester, 'sub');
      await tester.tap(find.byKey(const ValueKey('resultado-1')));
      await tester.pumpAndSettle();
      await chooseDestination(tester, 'AREQUIPA');

      await tester.tap(find.widgetWithText(FilledButton, 'Transferir'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Confirmar'));
      await tester.pumpAndSettle();

      expect(find.text('El producto no tiene stock suficiente'), findsOneWidget);
      expect(find.byKey(const ValueKey('linea-1')), findsOneWidget);
    });

    testWidgets('al cambiar el origen, un producto que no está ahí se marca y no se transfiere', (tester) async {
      final repo = await openTransfer(tester);
      await searchFor(tester, 'sub');
      await tester.tap(find.byKey(const ValueKey('resultado-1')));
      await tester.pumpAndSettle();

      // El producto 1 tiene 8 en LIMA y 0 en AREQUIPA; CUSCO no lo tiene.
      await tester.tap(find.widgetWithText(DropdownButtonFormField<int>, 'Desde'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('CUSCO').last);
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('fuera-del-origen')), findsOneWidget);
      expect(find.byKey(const ValueKey('campo-cantidad')), findsNothing);
      // Sin líneas que transferir no se puede enviar.
      await chooseDestination(tester, 'AREQUIPA');
      expect(transferButton(tester).onPressed, isNull);
      expect(repo.transfers, isEmpty);
    });

    testWidgets('al cambiar el origen, el destino que coincidía se limpia', (tester) async {
      await openTransfer(tester);
      await chooseDestination(tester, 'AREQUIPA');

      await tester.tap(find.widgetWithText(DropdownButtonFormField<int>, 'Desde'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('AREQUIPA').last);
      await tester.pumpAndSettle();

      // AREQUIPA ahora es el origen y ya no puede ser el destino.
      expect(find.text('AREQUIPA'), findsOneWidget);
    });
  });

}
