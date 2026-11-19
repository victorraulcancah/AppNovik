import 'dart:convert';
import 'dart:typed_data';

import 'package:app_novik/core/constants/api_constants.dart';
import 'package:app_novik/core/errors/exceptions.dart';
import 'package:app_novik/core/errors/failures.dart';
import 'package:app_novik/core/utils/either.dart';
import 'package:app_novik/data/datasources/price_list_remote_datasource.dart';
import 'package:app_novik/data/datasources/theme_local_datasource.dart';
import 'package:app_novik/data/models/price_list_model.dart';
import 'package:app_novik/domain/entities/company_entity.dart';
import 'package:app_novik/domain/entities/import_entity.dart';
import 'package:app_novik/domain/entities/price_list_entity.dart';
import 'package:app_novik/domain/entities/saved_credentials_entity.dart';
import 'package:app_novik/domain/entities/session_context_entity.dart';
import 'package:app_novik/domain/entities/user_entity.dart';
import 'package:app_novik/domain/repositories/auth_repository.dart';
import 'package:app_novik/domain/repositories/price_list_repository.dart';
import 'package:app_novik/domain/usecases/auth_usecases.dart';
import 'package:app_novik/domain/usecases/price_list_usecases.dart';
import 'package:app_novik/presentation/components/app_list_card.dart'
    show AppListCard;
import 'package:app_novik/presentation/pages/price_list_detail_page.dart';
import 'package:app_novik/presentation/pages/price_lists_page.dart';
import 'package:app_novik/presentation/providers/auth_provider.dart';
import 'package:app_novik/presentation/providers/price_lists_provider.dart';
import 'package:app_novik/presentation/providers/theme_provider.dart';
import 'package:app_novik/presentation/utils/import_file.dart';
import 'package:app_novik/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';

/// Ruta base de la API según la URL con la que se compile (en producción lleva `/7power/public`).
final _apiPath = Uri.parse(ApiConstants.baseUrl).path;

Map<String, dynamic> _listJson({
  int id = 1,
  String name = 'MAYORISTA',
  String moneda = 's',
  dynamic estado = true,
}) => {
  'id': id,
  'name': name,
  'tipo_moneda': moneda,
  'estado': estado,
  'company_id': 1,
};

Map<String, dynamic> _productJson({
  int id = 10,
  num? precio = 12.5,
  String tipo = 'p',
  String? marca = 'BOSCH',
}) => {
  'id': id,
  'tipo': tipo,
  'codigo': 'COD-$id',
  'name': 'FILTRO DE ACEITE $id',
  'img': '/storage/images/a.png',
  'brand': marca == null ? null : {'id': 1, 'name': marca},
  'list_prices': precio == null
      ? []
      : [
          {
            'id': 1,
            'name': 'MAYORISTA',
            'pivot': {
              'list_price_id': 1,
              'product_id': id,
              'precio': '$precio',
            },
          },
        ],
};

PriceListEntity _list({
  int id = 1,
  String name = 'MAYORISTA',
  String moneda = 's',
  bool active = true,
}) => PriceListEntity(id: id, name: name, currency: moneda, active: active);

PriceListProductEntity _product({
  int id = 10,
  double? precio = 12.5,
  String tipo = 'p',
  String? marca = 'BOSCH',
}) => PriceListProductEntity(
  id: id,
  tipo: tipo,
  codigo: 'COD-$id',
  name: 'FILTRO DE ACEITE $id',
  marca: marca,
  precio: precio,
);

class _FakePriceListRepository implements PriceListRepository {
  List<PriceListEntity> lists = [
    _list(),
    _list(id: 2, name: 'MINORISTA', moneda: 'd', active: false),
  ];
  List<PriceListProductEntity> products = [
    _product(),
    _product(id: 11, precio: null, tipo: 's', marca: null),
  ];
  int lastPage = 1;
  Failure? failure;
  Failure? saveFailure;
  Failure? priceFailure;
  Either<Failure, ImportResultEntity>? nextImport;

  final calls = <({int page, PriceListFiltersEntity filters})>[];
  final productCalls =
      <({int listId, int page, PriceListProductFiltersEntity filters})>[];
  final saves = <({PriceListFormEntity form, int? id, int companyId})>[];
  final prices = <({int listId, int productId, double precio})>[];
  final imports = <({int listId, int companyId, String fileName, int size})>[];
  final exports = <int>[];

  @override
  Future<Either<Failure, PriceListPageEntity>> getPriceLists({
    required int companyId,
    required int page,
    required int pageSize,
    required PriceListFiltersEntity filters,
  }) async {
    calls.add((page: page, filters: filters));
    if (failure != null) return Either.left(failure!);
    return Either.right(
      PriceListPageEntity(
        items: lists,
        currentPage: page,
        lastPage: lastPage,
        total: lists.length,
      ),
    );
  }

  @override
  Future<Either<Failure, PriceListEntity>> savePriceList({
    required int companyId,
    required PriceListFormEntity form,
    int? id,
  }) async {
    saves.add((form: form, id: id, companyId: companyId));
    if (saveFailure != null) return Either.left(saveFailure!);
    return Either.right(
      PriceListEntity(
        id: id ?? 99,
        name: form.name.toUpperCase(),
        currency: form.currency,
        active: form.active,
      ),
    );
  }

  @override
  Future<Either<Failure, PriceListProductPageEntity>> getProducts({
    required int listPriceId,
    required int page,
    required int pageSize,
    required PriceListProductFiltersEntity filters,
  }) async {
    productCalls.add((listId: listPriceId, page: page, filters: filters));
    if (failure != null) return Either.left(failure!);
    return Either.right(
      PriceListProductPageEntity(
        items: products,
        currentPage: page,
        lastPage: lastPage,
        total: 120,
      ),
    );
  }

  @override
  Future<Either<Failure, PriceListProductEntity>> updatePrice({
    required int listPriceId,
    required int productId,
    required double precio,
  }) async {
    prices.add((listId: listPriceId, productId: productId, precio: precio));
    if (priceFailure != null) return Either.left(priceFailure!);
    return Either.right(_product(id: productId, precio: precio));
  }

  @override
  Future<Either<Failure, Uint8List>> exportTemplate({
    required int listPriceId,
  }) async {
    exports.add(listPriceId);
    return Either.right(Uint8List.fromList([1, 2, 3]));
  }

  @override
  Future<Either<Failure, ImportResultEntity>> importPrices({
    required int listPriceId,
    required int companyId,
    required String fileName,
    required Uint8List bytes,
  }) async {
    imports.add((
      listId: listPriceId,
      companyId: companyId,
      fileName: fileName,
      size: bytes.length,
    ));
    return nextImport ?? Either.right(const ImportResultEntity());
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
  Future<Either<Failure, UserEntity>> login(
    String usuario,
    String password,
  ) async => Either.right(const UserEntity(id: 9, name: 'Ana', usuario: 'ana'));

  @override
  Future<Either<Failure, void>> logout() async => Either.rightVoid();

  @override
  Future<Either<Failure, SessionContextEntity?>> getSessionContext() async =>
      Either.right(null);

  @override
  Future<String?> getToken() async => null;

  @override
  Future<Either<Failure, SavedCredentialsEntity?>>
  getSavedCredentials() async => Either.right(null);

  @override
  Future<Either<Failure, void>> saveCredentials(
    String usuario,
    String password,
  ) async => Either.rightVoid();

  @override
  Future<Either<Failure, void>> clearSavedCredentials() async =>
      Either.rightVoid();
}

const _all = {
  'lista-de-precios.index',
  'lista-de-precios.store',
  'lista-de-precios.update',
  'lista-de-precios.show',
};

SessionContextEntity _session({
  int companyId = 1,
  Set<String> permissions = _all,
}) => SessionContextEntity(
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
    clearSavedCredentialsUseCase: ClearSavedCredentialsUseCase(
      repository: repo,
    ),
  )..session = session;
}

PriceListsProvider _provider(
  _FakePriceListRepository repo, {
  int companyId = 1,
  VoidCallback? onExpired,
}) => PriceListsProvider(
  getPriceListsUseCase: GetPriceListPageUseCase(repository: repo),
  savePriceListUseCase: SavePriceListUseCase(repository: repo),
  getProductsUseCase: GetPriceListProductsUseCase(repository: repo),
  updatePriceUseCase: UpdatePriceListPriceUseCase(repository: repo),
  exportTemplateUseCase: ExportPriceListTemplateUseCase(repository: repo),
  importPricesUseCase: ImportPriceListUseCase(repository: repo),
  onSessionExpired: onExpired,
)..syncCompany(companyId);

Future<({_FakePriceListRepository repo, PriceListsProvider provider})> _pump(
  WidgetTester tester, {
  Widget home = const PriceListsPage(),
  Set<String> permissions = _all,
  Size size = const Size(400, 900),
  ThemeMode mode = ThemeMode.light,
  double textScale = 1,
  void Function(_FakePriceListRepository repo)? setUp,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final repo = _FakePriceListRepository();
  setUp?.call(repo);
  final session = _session(permissions: permissions);
  final provider = _provider(repo);

  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<ThemeProvider>(
          create: (_) => ThemeProvider(storage: _FakeThemeStorage()),
        ),
        ChangeNotifierProvider<AuthProvider>.value(value: _auth(session)),
        ChangeNotifierProvider<PriceListsProvider>.value(value: provider),
      ],
      child: MaterialApp(
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        themeMode: mode,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: Scaffold(body: home),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return (repo: repo, provider: provider);
}

PriceListDetailPage _detail({
  PriceListEntity? list,
  Future<PickedImportFile?> Function()? pickFile,
}) => PriceListDetailPage(
  list: list ?? _list(),
  pickFile: pickFile ?? () async => null,
);

void main() {
  group('Modelo de lista de precios', () {
    test('lee una lista con moneda y estado', () {
      final soles = priceListFromJson(_listJson());
      final dolares = priceListFromJson(
        _listJson(id: 2, moneda: 'd', estado: false),
      );

      expect(soles.name, 'MAYORISTA');
      expect(soles.currency, 's');
      expect(soles.currencyLabel, 'Soles');
      expect(soles.symbol, 'S/.');
      expect(soles.active, isTrue);
      expect(dolares.isDollars, isTrue);
      expect(dolares.currencyLabel, 'Dólares');
      expect(dolares.symbol, r'$.');
      expect(dolares.active, isFalse);
    });

    test('el estado acepta 1 y 0 como la base de datos', () {
      expect(priceListFromJson(_listJson(estado: 1)).active, isTrue);
      expect(priceListFromJson(_listJson(estado: 0)).active, isFalse);
    });

    test('lee una página del paginador de Laravel', () {
      final page = priceListPageFromJson({
        'data': [_listJson(), _listJson(id: 2)],
        'current_page': 1,
        'last_page': 3,
        'total': 5,
      });

      expect(page.items, hasLength(2));
      expect(page.total, 5);
      expect(page.hasMore, isTrue);
      expect(priceListPageFromJson({'data': []}).items, isEmpty);
    });

    test('el producto trae su precio de list_prices (puede venir como texto) y la marca', () {
      final p = priceListProductFromJson(_productJson(precio: 12.5));
      final sin = priceListProductFromJson(
        _productJson(id: 11, precio: null, tipo: 's', marca: null),
      );

      expect(p.precio, 12.5);
      expect(p.marca, 'BOSCH');
      expect(p.imagen, '/storage/images/a.png');
      expect(p.esServicio, isFalse);
      expect(sin.precio, isNull);
      expect(sin.marca, isNull);
      expect(sin.esServicio, isTrue);
    });

    test('"/storage/" solo es "sin imagen"', () {
      final json = _productJson()..['img'] = '/storage/';
      expect(priceListProductFromJson(json).imagen, isNull);
    });

    test('las fallas de la importación pueden ser filas, textos sueltos, lista o mapa', () {
      final result = priceListImportResultFromJson({
        'failures': [
          {
            'row': 3,
            'attribute': 'sku',
            'errors': ['El SKU del Producto no existe.'],
            'values': {},
          },
          'Algo salió mal',
        ],
      });
      expect(result.hasFailures, isTrue);
      expect(result.failures.first.row, 3);
      expect(result.failures.first.errors, ['El SKU del Producto no existe.']);
      expect(result.failures.last.row, 0);
      expect(result.failures.last.errors, ['Algo salió mal']);

      final map = priceListImportResultFromJson({
        'failures': {
          'e-4': {
            'row': 4,
            'errors': ['x'],
          },
        },
      });
      expect(map.failures.single.row, 4);

      final ok = priceListImportResultFromJson({
        'message': 'Importación exitosa',
      });
      expect(ok.hasFailures, isFalse);
      expect(ok.message, 'Importación exitosa');
    });
  });

  group('Datasource de lista de precios', () {
    test('GET /lista-de-precios manda empresa, paginación, search[] y filtros como la web', () async {
      late Uri uri;
      final ds = PriceListRemoteDataSourceImpl(
        client: MockClient((request) async {
          uri = request.url;
          expect(request.method, 'GET');
          expect(request.headers['Authorization'], 'Bearer t');
          return http.Response(
            jsonEncode({
              'data': [_listJson()],
              'current_page': 2,
              'last_page': 3,
              'total': 70,
            }),
            200,
          );
        }),
      );

      final page = await ds.getPriceLists(
        't',
        companyId: 5,
        page: 2,
        pageSize: 30,
        filters: const PriceListFiltersEntity(
          terms: ['may', 'min'],
          currency: 'd',
          active: false,
        ),
      );

      expect(uri.path, '$_apiPath/lista-de-precios');
      expect(uri.queryParametersAll['company_id'], ['5']);
      expect(uri.queryParametersAll['pagination[current]'], ['2']);
      expect(uri.queryParametersAll['pagination[pageSize]'], ['30']);
      expect(uri.queryParametersAll['search[]'], ['may', 'min']);
      expect(uri.queryParametersAll['filters[tipo_moneda][]'], ['d']);
      expect(uri.queryParametersAll['filters[estado][]'], ['false']);
      expect(page.items.single.name, 'MAYORISTA');
      expect(page.hasMore, isTrue);
    });

    test('sin búsqueda ni filtros solo manda empresa y paginación', () async {
      late Uri uri;
      final ds = PriceListRemoteDataSourceImpl(
        client: MockClient((request) async {
          uri = request.url;
          return http.Response('{"data": []}', 200);
        }),
      );

      await ds.getPriceLists(
        't',
        companyId: 5,
        page: 1,
        pageSize: 30,
        filters: const PriceListFiltersEntity(),
      );

      expect(uri.queryParameters.keys, [
        'company_id',
        'pagination[current]',
        'pagination[pageSize]',
      ]);
    });

    test(
      'crear es POST a storeOnlyList con empresa, nombre, moneda y estado',
      () async {
        late http.Request req;
        final ds = PriceListRemoteDataSourceImpl(
          client: MockClient((request) async {
            req = request;
            return http.Response(
              jsonEncode(_listJson(id: 7, name: 'NUEVA')),
              200,
            );
          }),
        );

        final created = await ds.savePriceList(
          't',
          companyId: 5,
          form: const PriceListFormEntity(
            name: 'Nueva',
            currency: 'd',
            active: false,
          ),
        );

        expect(req.method, 'POST');
        expect(req.url.path, '$_apiPath/lista-de-precios/storeOnlyList');
        expect(jsonDecode(req.body), {
          'company_id': 5,
          'name': 'Nueva',
          'estado': false,
          'tipo_moneda': 'd',
        });
        expect(created.id, 7);
      },
    );

    test('editar es PUT a storeOnlyList/{id} y no manda la moneda', () async {
      late http.Request req;
      final ds = PriceListRemoteDataSourceImpl(
        client: MockClient((request) async {
          req = request;
          return http.Response(jsonEncode(_listJson(id: 3)), 200);
        }),
      );

      await ds.savePriceList(
        't',
        companyId: 5,
        id: 3,
        form: const PriceListFormEntity(name: 'Mayorista', currency: 'd'),
      );

      expect(req.method, 'PUT');
      expect(req.url.path, '$_apiPath/lista-de-precios/storeOnlyList/3');
      expect(jsonDecode(req.body), {
        'company_id': 5,
        'name': 'Mayorista',
        'estado': true,
      });
    });

    test('un nombre repetido dice "La lista ya existe" como la web', () async {
      final ds = PriceListRemoteDataSourceImpl(
        client: MockClient(
          (request) async => http.Response(
            jsonEncode({
              'error': {
                'name': ['The name has already been taken.'],
              },
            }),
            422,
          ),
        ),
      );

      await expectLater(
        ds.savePriceList(
          't',
          companyId: 5,
          form: const PriceListFormEntity(name: 'X', currency: 's'),
        ),
        throwsA(
          isA<ValidationException>().having(
            (e) => e.message,
            'message',
            'La lista ya existe',
          ),
        ),
      );
    });

    test('otro error de validación conserva su mensaje', () async {
      final ds = PriceListRemoteDataSourceImpl(
        client: MockClient(
          (request) async => http.Response(
            jsonEncode({
              'error': {
                'tipo_moneda': ['Elige la moneda'],
              },
            }),
            422,
          ),
        ),
      );

      await expectLater(
        ds.savePriceList(
          't',
          companyId: 5,
          form: const PriceListFormEntity(name: 'X', currency: 's'),
        ),
        throwsA(
          isA<ValidationException>().having(
            (e) => e.message,
            'message',
            'Elige la moneda',
          ),
        ),
      );
    });

    test('GET /lista-de-precios/details manda list_price_id, paginación, búsqueda y tipo', () async {
      late Uri uri;
      final ds = PriceListRemoteDataSourceImpl(
        client: MockClient((request) async {
          uri = request.url;
          return http.Response(
            jsonEncode({
              'data': [_productJson()],
              'current_page': 1,
              'last_page': 1,
              'total': 1,
            }),
            200,
          );
        }),
      );

      final page = await ds.getProducts(
        't',
        listPriceId: 4,
        page: 1,
        pageSize: 50,
        filters: const PriceListProductFiltersEntity(
          search: 'filtro',
          tipo: 's',
        ),
      );

      expect(uri.path, '$_apiPath/lista-de-precios/details');
      expect(uri.queryParametersAll['list_price_id'], ['4']);
      expect(uri.queryParametersAll['pagination[current]'], ['1']);
      expect(uri.queryParametersAll['pagination[pageSize]'], ['50']);
      expect(uri.queryParametersAll['search[]'], ['filtro']);
      expect(uri.queryParametersAll['filters[tipo][]'], ['s']);
      expect(page.items.single.precio, 12.5);
    });

    test('cambiar el precio es PATCH /lista-de-precios/{id} con precio y product_id', () async {
      late http.Request req;
      final ds = PriceListRemoteDataSourceImpl(
        client: MockClient((request) async {
          req = request;
          return http.Response(jsonEncode(_productJson(precio: 20)), 200);
        }),
      );

      final product = await ds.updatePrice(
        't',
        listPriceId: 4,
        productId: 10,
        precio: 20,
      );

      expect(req.method, 'PATCH');
      expect(req.url.path, '$_apiPath/lista-de-precios/4');
      expect(jsonDecode(req.body), {'precio': 20.0, 'product_id': 10});
      expect(product.precio, 20);
    });

    test('la plantilla es un POST a /lista-de-precios/{id}/export y devuelve los bytes', () async {
      late http.Request req;
      final ds = PriceListRemoteDataSourceImpl(
        client: MockClient((request) async {
          req = request;
          return http.Response.bytes([9, 9], 200);
        }),
      );

      final bytes = await ds.exportTemplate('t', listPriceId: 4);

      expect(bytes, [9, 9]);
      expect(req.method, 'POST');
      expect(req.url.path, '$_apiPath/lista-de-precios/4/export');
    });

    test(
      'subir precios va en multipart con el archivo, la lista y la empresa',
      () async {
        late http.BaseRequest sent;
        late String body;
        final ds = PriceListRemoteDataSourceImpl(
          client: MockClient.streaming((request, stream) async {
            sent = request;
            body = utf8.decode(await stream.expand((chunk) => chunk).toList());
            return http.StreamedResponse(
              Stream.value(
                utf8.encode(
                  jsonEncode({
                    'failures': [
                      {
                        'row': 2,
                        'attribute': 'sku',
                        'errors': ['El SKU del Producto no existe.'],
                      },
                    ],
                  }),
                ),
              ),
              200,
              headers: {'content-type': 'application/json'},
            );
          }),
        );

        final result = await ds.importPrices(
          't',
          listPriceId: 4,
          companyId: 5,
          fileName: 'precios.xlsx',
          bytes: Uint8List.fromList(utf8.encode('EXCEL')),
        );

        expect(sent.method, 'POST');
        expect(sent.url.path, '$_apiPath/lista-de-precios/4/import');
        expect(sent.headers['content-type'], startsWith('multipart/form-data'));
        expect(body, contains('name="list_price_id"'));
        expect(body, contains('name="company_id"'));
        expect(body, contains('name="file"; filename="precios.xlsx"'));
        expect(body, contains('EXCEL'));
        expect(result.failures.single.row, 2);
      },
    );
  });

  group('PriceListsProvider', () {
    test('carga la primera página', () async {
      final repo = _FakePriceListRepository();
      final p = _provider(repo);

      await p.ensureLoaded();

      expect(p.items, hasLength(2));
      expect(p.total, 2);
      expect(repo.calls.single.page, 1);
    });

    test(
      'loadMore suma la página siguiente y para al llegar a la última',
      () async {
        final repo = _FakePriceListRepository()..lastPage = 2;
        final p = _provider(repo);
        await p.refresh();
        expect(p.hasMore, isTrue);

        repo.lists = [_list(id: 3, name: 'OFERTA')];
        await p.loadMore();
        await p.loadMore();

        expect(p.items.map((l) => l.name), [
          'MAYORISTA',
          'MINORISTA',
          'OFERTA',
        ]);
        expect(p.hasMore, isFalse);
        expect(repo.calls.map((c) => c.page), [1, 2]);
      },
    );

    test(
      'un error deja la lista vacía con el mensaje y avisa si la sesión venció',
      () async {
        final repo = _FakePriceListRepository()
          ..failure = const AuthenticationFailure('Sesión expirada');
        var expired = 0;
        final p = _provider(repo, onExpired: () => expired++);

        await p.refresh();

        expect(p.items, isEmpty);
        expect(p.error, 'Sesión expirada');
        expect(expired, 1);
      },
    );

    test('lo que se escribe y los chips se mandan juntos; repetidos y vacíos se ignoran', () async {
      final repo = _FakePriceListRepository();
      final p = _provider(repo);

      await p.addSearchTerm(' mayorista ');
      await p.addSearchTerm('mayorista');
      await p.addSearchTerm('   ');
      await p.setSearch('oferta');

      expect(p.searchTerms, ['mayorista']);
      expect(repo.calls.last.filters.terms, ['mayorista', 'oferta']);

      await p.removeSearchTerm('mayorista');
      expect(repo.calls.last.filters.terms, ['oferta']);

      await p.addSearchTerm('oferta');
      expect(p.search, '');
      expect(p.searchTerms, ['oferta']);
      await p.clearSearchTerms();
      expect(repo.calls.last.filters.terms, isEmpty);
    });

    test('la moneda y el estado van en una sola consulta', () async {
      final repo = _FakePriceListRepository();
      final p = _provider(repo);

      await p.setFilters(currency: 'd', active: true);

      expect(repo.calls, hasLength(1));
      expect(repo.calls.last.filters.currency, 'd');
      expect(repo.calls.last.filters.active, isTrue);
      expect(p.filtersActive, isTrue);
    });

    test(
      'guardar crea con la empresa y recarga; si falla devuelve el motivo',
      () async {
        final repo = _FakePriceListRepository();
        final p = _provider(repo);

        final ok = await p.save(
          const PriceListFormEntity(name: 'Nueva', currency: 's'),
        );
        expect(ok, isNull);
        expect(repo.saves.single.companyId, 1);
        expect(repo.saves.single.id, isNull);
        expect(repo.calls, hasLength(1));

        repo.saveFailure = const ValidationFailure('La lista ya existe');
        final bad = await p.save(
          const PriceListFormEntity(name: 'Nueva', currency: 's'),
          id: 2,
        );
        expect(bad, 'La lista ya existe');
        expect(repo.saves.last.id, 2);
      },
    );

    test(
      'abrir una lista trae sus productos y cambia de tipo y búsqueda',
      () async {
        final repo = _FakePriceListRepository();
        final p = _provider(repo);

        await p.openList(_list(id: 4));
        expect(p.products, hasLength(2));
        expect(p.productsTotal, 120);
        expect(repo.productCalls.single.listId, 4);

        await p.setProductSearch('  filtro ');
        expect(repo.productCalls.last.filters.search, 'filtro');
        await p.setProductTipo('s');
        expect(repo.productCalls.last.filters.tipo, 's');
        expect(repo.productCalls.last.filters.search, 'filtro');
        await p.setProductTipo(null);
        expect(repo.productCalls.last.filters.tipo, isNull);
      },
    );

    test('abrir otra lista descarta los productos de la anterior', () async {
      final repo = _FakePriceListRepository();
      final p = _provider(repo);
      await p.openList(_list(id: 4));
      await p.setProductSearch('filtro');

      repo.products = [_product(id: 77)];
      await p.openList(_list(id: 5, name: 'OTRA'));

      expect(p.products.single.id, 77);
      expect(p.productFilters.isActive, isFalse);
      expect(repo.productCalls.last.listId, 5);
    });

    test(
      'cambiar un precio actualiza el producto de la lista en pantalla',
      () async {
        final repo = _FakePriceListRepository();
        final p = _provider(repo);
        await p.openList(_list(id: 4));

        final problem = await p.updatePrice(p.products.last, 33.5);

        expect(problem, isNull);
        expect(repo.prices.single, (listId: 4, productId: 11, precio: 33.5));
        expect(p.products.last.precio, 33.5);
        expect(p.products.first.precio, 12.5);
      },
    );

    test(
      'si el servidor rechaza el precio, devuelve el motivo y no cambia nada',
      () async {
        final repo = _FakePriceListRepository()
          ..priceFailure = const ValidationFailure(
            'El precio debe ser un número',
          );
        final p = _provider(repo);
        await p.openList(_list(id: 4));

        final problem = await p.updatePrice(p.products.first, 5);

        expect(problem, 'El precio debe ser un número');
        expect(p.products.first.precio, 12.5);
      },
    );

    test(
      'la plantilla se llama "Lista de {nombre}.xlsx" como en la web',
      () async {
        final repo = _FakePriceListRepository();
        final p = _provider(repo);
        await p.openList(_list(id: 4, name: 'MAYORISTA'));

        final result = await p.downloadTemplate();

        expect(result.isRight, isTrue);
        expect(result.right.name, 'Lista de MAYORISTA.xlsx');
        expect(result.right.bytes, [1, 2, 3]);
        expect(repo.exports, [4]);
        expect(p.exporting, isFalse);
      },
    );

    test('subir precios manda empresa y lista, y recarga los productos al terminar', () async {
      final repo = _FakePriceListRepository();
      final p = _provider(repo);
      await p.openList(_list(id: 4));

      final result = await p.importPrices(
        fileName: 'p.xlsx',
        bytes: Uint8List.fromList([1, 2]),
      );

      expect(result.isRight, isTrue);
      expect(repo.imports.single, (
        listId: 4,
        companyId: 1,
        fileName: 'p.xlsx',
        size: 2,
      ));
      expect(repo.productCalls, hasLength(2));
      expect(p.importing, isFalse);
    });

    test('sin lista abierta no descarga ni sube', () async {
      final p = _provider(_FakePriceListRepository());

      expect((await p.downloadTemplate()).isLeft, isTrue);
      expect(
        (await p.importPrices(fileName: 'p.xlsx', bytes: Uint8List(1))).isLeft,
        isTrue,
      );
    });

    test('al cambiar de empresa se descarta todo', () async {
      final repo = _FakePriceListRepository();
      final p = _provider(repo);
      await p.openList(_list(id: 4));
      await p.refresh();
      await p.addSearchTerm('x');

      p.syncCompany(2);

      expect(p.items, isEmpty);
      expect(p.products, isEmpty);
      expect(p.current, isNull);
      expect(p.searchTerms, isEmpty);
    });
  });

  group('Pantalla de Lista de precios', () {
    testWidgets('muestra las listas con moneda y estado', (tester) async {
      await _pump(tester);

      expect(find.text('Lista de precios'), findsWidgets);
      expect(find.byType(AppListCard), findsNWidgets(2));
      expect(find.text('MAYORISTA'), findsOneWidget);
      expect(find.text('Moneda · S/. Soles'), findsOneWidget);
      expect(find.text('Moneda · \$. Dólares'), findsOneWidget);
      expect(find.text('Activo'), findsOneWidget);
      expect(find.text('Inactivo'), findsOneWidget);
    });

    testWidgets('el buscador no tiene micrófono', (tester) async {
      await _pump(tester);

      expect(find.widgetWithText(TextField, 'Búsqueda por nombre…'), findsOneWidget);
      expect(find.byTooltip('Buscar por voz'), findsNothing);
    });

    testWidgets('sin listas dice que no hay', (tester) async {
      await _pump(tester, setUp: (r) => r.lists = []);

      expect(find.text('No hay listas de precios'), findsOneWidget);
    });

    testWidgets('si falla muestra el error y Reintentar vuelve a pedir', (
      tester,
    ) async {
      final r = await _pump(
        tester,
        setUp: (r) =>
            r.failure = const ServerFailure('Sin conexión con el servidor'),
      );

      expect(
        find.text('No se pudieron cargar las listas de precios'),
        findsOneWidget,
      );
      expect(find.text('Sin conexión con el servidor'), findsOneWidget);

      r.repo.failure = null;
      await tester.tap(find.text('Reintentar'));
      await tester.pumpAndSettle();

      expect(find.text('MAYORISTA'), findsOneWidget);
      expect(r.repo.calls, hasLength(2));
    });

    testWidgets('sin permiso index no pide nada y avisa', (tester) async {
      final r = await _pump(tester, permissions: const {});

      expect(find.text('Sin acceso'), findsOneWidget);
      expect(find.byType(AppListCard), findsNothing);
      expect(r.repo.calls, isEmpty);
    });

    testWidgets(
      'sin store ni update no hay crear ni editar; sin show no hay ver',
      (tester) async {
        await _pump(tester, permissions: const {'lista-de-precios.index'});

        expect(find.text('Crear lista'), findsNothing);
        expect(find.byTooltip('Editar'), findsNothing);
        expect(find.byTooltip('Ver detalle'), findsNothing);
        expect(find.byType(AppListCard), findsNWidgets(2));
      },
    );

    testWidgets('escribir en el buscador filtra por nombre tras una pausa', (
      tester,
    ) async {
      final r = await _pump(tester);

      await tester.enterText(find.byType(SearchBar), 'may');
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();

      expect(r.repo.calls.last.filters.terms, ['may']);
    });

    testWidgets(
      '"buscar" en el teclado deja la búsqueda como chip y libera el campo',
      (tester) async {
        final r = await _pump(tester);

        await tester.enterText(find.byType(SearchBar), 'mayorista');
        await tester.testTextInput.receiveAction(TextInputAction.done);
        await tester.pumpAndSettle();

        expect(find.byKey(const ValueKey('chip-mayorista')), findsOneWidget);
        expect(r.repo.calls.last.filters.terms, ['mayorista']);

        await tester.tap(find.byTooltip('Quitar "mayorista"'));
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey('chip-mayorista')), findsNothing);
        expect(r.repo.calls.last.filters.terms, isEmpty);
      },
    );

    testWidgets(
      'el panel de filtros elige moneda y estado, y salen como chips que se quitan',
      (tester) async {
        // Ancho de celular grande: así caben "Limpiar" y los dos chips sin desplazar la fila.
        final r = await _pump(tester, size: const Size(560, 900));

        await tester.tap(find.byTooltip('Filtros'));
        await tester.pumpAndSettle();
        await tester.tap(find.byType(DropdownButtonFormField<String?>).first);
        await tester.pumpAndSettle();
        await tester.tap(
          find.widgetWithText(DropdownMenuItem<String?>, 'Dólares').last,
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byType(DropdownButtonFormField<String?>).last);
        await tester.pumpAndSettle();
        await tester.tap(
          find.widgetWithText(DropdownMenuItem<String?>, 'Activo').last,
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Ver resultados'));
        await tester.pumpAndSettle();

        expect(r.repo.calls.last.filters.currency, 'd');
        expect(r.repo.calls.last.filters.active, isTrue);
        expect(find.text('Moneda: Dólares'), findsOneWidget);
        expect(find.text('Estado: Activo'), findsOneWidget);

        await tester.tap(find.byTooltip('Quitar Moneda: Dólares'));
        await tester.pumpAndSettle();
        expect(r.repo.calls.last.filters.currency, isNull);
        expect(r.repo.calls.last.filters.active, isTrue);
      },
    );

    testWidgets(
      'crear: nombre, moneda y estado; guarda con la empresa y avisa',
      (tester) async {
        final r = await _pump(tester);

        await tester.tap(find.text('Crear lista'));
        await tester.pumpAndSettle();
        expect(find.text('Crear lista de precios'), findsOneWidget);
        expect(find.text('Tipo de moneda'), findsOneWidget);

        // Sin nombre ni moneda no se guarda.
        await tester.tap(find.widgetWithText(FilledButton, 'Crear'));
        await tester.pumpAndSettle();
        expect(find.text('Escribe el nombre de la lista'), findsOneWidget);
        expect(find.text('Elige la moneda'), findsOneWidget);
        expect(r.repo.saves, isEmpty);

        await tester.enterText(
          find.byKey(const ValueKey('lista-nombre')),
          'Distribuidor',
        );
        await tester.tap(find.byKey(const ValueKey('lista-moneda')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Dólares').last);
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('lista-estado')));
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(FilledButton, 'Crear'));
        await tester.pumpAndSettle();

        expect(r.repo.saves.single.companyId, 1);
        expect(r.repo.saves.single.id, isNull);
        expect(r.repo.saves.single.form.name, 'Distribuidor');
        expect(r.repo.saves.single.form.currency, 'd');
        expect(r.repo.saves.single.form.active, isFalse);
        expect(find.text('Lista de Precio Creado'), findsOneWidget);
        // Recargó la lista.
        expect(r.repo.calls, hasLength(2));
      },
    );

    testWidgets(
      'si el servidor rechaza el nombre, el modal sigue abierto con el motivo',
      (tester) async {
        final r = await _pump(
          tester,
          setUp: (r) =>
              r.saveFailure = const ValidationFailure('La lista ya existe'),
        );

        await tester.tap(find.text('Crear lista'));
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byKey(const ValueKey('lista-nombre')),
          'Mayorista',
        );
        await tester.tap(find.byKey(const ValueKey('lista-moneda')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Soles').last);
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(FilledButton, 'Crear'));
        await tester.pumpAndSettle();

        expect(find.text('La lista ya existe'), findsOneWidget);
        expect(find.text('Crear lista de precios'), findsOneWidget);
        expect(r.repo.saves, hasLength(1));
      },
    );

    testWidgets(
      'editar trae el nombre y el estado, no deja cambiar la moneda y guarda con el id',
      (tester) async {
        final r = await _pump(tester);

        await tester.tap(find.byTooltip('Editar').first);
        await tester.pumpAndSettle();

        expect(find.text('Editar lista de precios'), findsOneWidget);
        expect(find.text('Tipo de moneda'), findsNothing);
        expect(find.widgetWithText(TextFormField, 'MAYORISTA'), findsOneWidget);

        await tester.enterText(
          find.byKey(const ValueKey('lista-nombre')),
          'Mayorista 2',
        );
        await tester.tap(find.widgetWithText(FilledButton, 'Editar'));
        await tester.pumpAndSettle();

        expect(r.repo.saves.single.id, 1);
        expect(r.repo.saves.single.form.name, 'Mayorista 2');
        expect(r.repo.saves.single.form.active, isTrue);
        expect(find.text('Lista de Precio Editado'), findsOneWidget);
      },
    );

    testWidgets(
      'tocar una lista abre su detalle con los productos y sus precios',
      (tester) async {
        final r = await _pump(tester);

        await tester.tap(find.text('MAYORISTA'));
        await tester.pumpAndSettle();

        expect(find.byType(PriceListDetailPage), findsOneWidget);
        expect(r.repo.productCalls.single.listId, 1);
        expect(find.text('FILTRO DE ACEITE 10'), findsOneWidget);
        expect(find.text('S/. 12.50'), findsOneWidget);
        expect(find.text('Sin precio'), findsOneWidget);
        expect(find.text('Código · COD-10'), findsOneWidget);
        expect(find.text('Servicio'), findsOneWidget);
      },
    );

    testWidgets('en tablet la lista no se estira y se ve bien', (tester) async {
      await _pump(tester, size: const Size(1100, 800));

      final card = tester.getSize(find.byType(AppListCard).first);
      expect(card.width, lessThanOrEqualTo(720));
      expect(tester.takeException(), isNull);
    });

    testWidgets('en modo oscuro y con letra grande no se desborda', (
      tester,
    ) async {
      await _pump(
        tester,
        size: const Size(360, 640),
        mode: ThemeMode.dark,
        textScale: 1.4,
        setUp: (r) => r.lists = [
          _list(
            name: 'LISTA DE PRECIOS PARA DISTRIBUIDORES DE PROVINCIAS DEL SUR',
          ),
        ],
      );

      expect(tester.takeException(), isNull);
      expect(find.byType(AppListCard), findsOneWidget);
    });
  });

  group('Detalle de la lista de precios', () {
    Future<_FakePriceListRepository> openDetail(
      WidgetTester tester, {
      Set<String> permissions = _all,
      Future<PickedImportFile?> Function()? pickFile,
      void Function(_FakePriceListRepository repo)? setUp,
    }) async {
      final r = await _pump(
        tester,
        home: _detail(pickFile: pickFile),
        permissions: permissions,
        setUp: setUp,
      );
      return r.repo;
    }

    Future<void> openActions(WidgetTester tester) async {
      await tester.tap(find.text('Acciones'));
      await tester.pumpAndSettle();
    }

    testWidgets('el buscador del detalle no tiene micrófono', (tester) async {
      await openDetail(tester);

      expect(find.widgetWithText(TextField, 'Búsqueda por nombre, código…'), findsOneWidget);
      expect(find.byTooltip('Buscar por voz'), findsNothing);
    });

    testWidgets(
      'muestra el nombre, la moneda, el total y los productos con su precio',
      (tester) async {
        final repo = await openDetail(tester);

        expect(find.text('MAYORISTA'), findsOneWidget);
        expect(find.text('S/. Soles · 120 productos'), findsOneWidget);
        expect(find.byType(AppListCard), findsNWidgets(2));
        expect(find.text('S/. 12.50'), findsOneWidget);
        expect(find.text('BOSCH'), findsOneWidget);
        expect(find.text('Código · COD-10'), findsOneWidget);
        expect(find.text('Sin precio'), findsOneWidget);
        expect(repo.productCalls.single.listId, 1);
      },
    );

    testWidgets(
      'los precios de una lista en dólares llevan el prefijo de dólares',
      (tester) async {
        await _pump(
          tester,
          home: _detail(list: _list(moneda: 'd')),
        );

        expect(find.text(r'$. 12.50'), findsOneWidget);
      },
    );

    testWidgets('sin permiso show avisa y no pide nada', (tester) async {
      final repo = await openDetail(
        tester,
        permissions: const {'lista-de-precios.index'},
      );

      expect(find.text('Sin acceso'), findsOneWidget);
      expect(repo.productCalls, isEmpty);
    });

    testWidgets('escribir en el buscador filtra los productos tras una pausa', (
      tester,
    ) async {
      final repo = await openDetail(tester);

      await tester.enterText(find.byType(SearchBar), 'filtro');
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();

      expect(repo.productCalls.last.filters.search, 'filtro');
    });

    testWidgets('el filtro de tipo sale como chip y se quita', (tester) async {
      final repo = await openDetail(tester);

      await tester.tap(find.byTooltip('Filtros'));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(DropdownButtonFormField<String?>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Servicio').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ver resultados'));
      await tester.pumpAndSettle();

      expect(repo.productCalls.last.filters.tipo, 's');
      expect(find.text('Tipo: Servicio'), findsOneWidget);

      await tester.tap(find.byTooltip('Quitar Tipo: Servicio'));
      await tester.pumpAndSettle();
      expect(repo.productCalls.last.filters.tipo, isNull);
    });

    testWidgets(
      'cambiar el precio: abre el modal con el precio actual, guarda y actualiza la tarjeta',
      (tester) async {
        final repo = await openDetail(tester);

        await tester.tap(find.byTooltip('Cambiar precio').first);
        await tester.pumpAndSettle();
        expect(find.text('Precio del producto'), findsOneWidget);
        expect(find.widgetWithText(TextField, '12.5'), findsOneWidget);

        await tester.enterText(
          find.byKey(const ValueKey('precio-nuevo')),
          '20,5',
        );
        await tester.tap(find.widgetWithText(FilledButton, 'Guardar'));
        await tester.pumpAndSettle();

        expect(repo.prices.single, (listId: 1, productId: 10, precio: 20.5));
        expect(find.text('S/. 20.50'), findsOneWidget);
        expect(find.text('Precio Actualizado'), findsOneWidget);
      },
    );

    testWidgets('vaciar el precio guarda 0 como la web', (tester) async {
      final repo = await openDetail(tester);

      await tester.tap(find.byTooltip('Cambiar precio').first);
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const ValueKey('precio-nuevo')), '');
      await tester.tap(find.widgetWithText(FilledButton, 'Guardar'));
      await tester.pumpAndSettle();

      expect(repo.prices.single.precio, 0);
    });

    testWidgets(
      'si el servidor rechaza el precio, el modal sigue abierto con el motivo',
      (tester) async {
        await openDetail(
          tester,
          setUp: (r) =>
              r.priceFailure = const ValidationFailure('No autorizado'),
        );

        await tester.tap(find.byTooltip('Cambiar precio').first);
        await tester.pumpAndSettle();
        await tester.enterText(find.byKey(const ValueKey('precio-nuevo')), '5');
        await tester.tap(find.widgetWithText(FilledButton, 'Guardar'));
        await tester.pumpAndSettle();

        expect(find.text('No autorizado'), findsOneWidget);
        expect(find.text('Precio del producto'), findsOneWidget);
      },
    );

    testWidgets('sin update el precio es de solo lectura', (tester) async {
      await openDetail(
        tester,
        permissions: const {'lista-de-precios.index', 'lista-de-precios.show'},
      );

      expect(find.byTooltip('Cambiar precio'), findsNothing);
      await tester.tap(find.text('FILTRO DE ACEITE 10'));
      await tester.pumpAndSettle();
      expect(find.text('Precio del producto'), findsNothing);
    });

    testWidgets('subir precios: se elige el Excel, se sube y avisa', (
      tester,
    ) async {
      final repo = await openDetail(
        tester,
        pickFile: () async =>
            (name: 'precios.xlsx', bytes: Uint8List.fromList([1, 2, 3])),
      );
      await openActions(tester);
      await tester.tap(find.byTooltip('Subir precios'));
      await tester.pumpAndSettle();

      expect(find.text('Subir precios'), findsWidgets);
      // Sin archivo, Subir está desactivado.
      expect(
        tester
            .widget<FilledButton>(find.widgetWithText(FilledButton, 'Subir'))
            .onPressed,
        isNull,
      );

      await tester.tap(find.text('Toca para elegir un archivo'));
      await tester.pumpAndSettle();
      expect(find.text('precios.xlsx'), findsOneWidget);

      await tester.tap(find.widgetWithText(FilledButton, 'Subir'));
      await tester.pumpAndSettle();

      expect(repo.imports.single, (
        listId: 1,
        companyId: 1,
        fileName: 'precios.xlsx',
        size: 3,
      ));
      expect(find.text('Lista de Precios Subidos'), findsOneWidget);
      expect(find.text('Filas con errores'), findsNothing);
      // Recargó los productos.
      expect(repo.productCalls, hasLength(2));
    });

    testWidgets(
      'si el servidor devuelve filas con error se muestran una por una',
      (tester) async {
        final repo = await openDetail(
          tester,
          pickFile: () async =>
              (name: 'precios.xlsx', bytes: Uint8List.fromList([1])),
        );
        repo.nextImport = Either.right(
          const ImportResultEntity(
            failures: [
              ImportFailureEntity(
                row: 3,
                errors: ['El SKU del Producto no existe.'],
              ),
              ImportFailureEntity(row: 0, errors: ['Fila ilegible']),
            ],
          ),
        );
        await openActions(tester);
        await tester.tap(find.byTooltip('Subir precios'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Toca para elegir un archivo'));
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(FilledButton, 'Subir'));
        await tester.pumpAndSettle();

        expect(find.text('Filas con errores'), findsOneWidget);
        expect(find.text('Error en fila 3'), findsOneWidget);
        expect(find.text('El SKU del Producto no existe.'), findsOneWidget);
        expect(find.text('Error'), findsOneWidget);
        expect(find.text('Fila ilegible'), findsOneWidget);
      },
    );

    testWidgets(
      'si el servidor rechaza el archivo, el modal sigue abierto con el motivo',
      (tester) async {
        final repo = await openDetail(
          tester,
          pickFile: () async =>
              (name: 'precios.xlsx', bytes: Uint8List.fromList([1])),
        );
        repo.nextImport = Either.left(
          const ValidationFailure('El archivo debe ser xlsx'),
        );
        await openActions(tester);
        await tester.tap(find.byTooltip('Subir precios'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Toca para elegir un archivo'));
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(FilledButton, 'Subir'));
        await tester.pumpAndSettle();

        expect(find.text('El archivo debe ser xlsx'), findsOneWidget);
        expect(find.text('Toca para elegir un archivo'), findsNothing);
      },
    );

    testWidgets(
      'sin store ni import no hay Subir precios, pero sí la plantilla',
      (tester) async {
        await openDetail(
          tester,
          permissions: const {
            'lista-de-precios.index',
            'lista-de-precios.show',
          },
        );

        // Con una sola acción el botón flotante lleva su nombre (no hay "Acciones").
        expect(find.text('Subir precios'), findsNothing);
        expect(find.text('Plantilla'), findsOneWidget);
      },
    );

    testWidgets(
      'en celular angosto, modo oscuro y letra grande no se desborda',
      (tester) async {
        await _pump(
          tester,
          home: _detail(),
          size: const Size(360, 640),
          mode: ThemeMode.dark,
          textScale: 1.4,
          setUp: (r) => r.products = [
            PriceListProductEntity(
              id: 1,
              tipo: 'p',
              codigo: 'COD-LARGO-1234567890',
              name: 'FILTRO DE ACEITE PARA CAMIONES DE ALTO TONELAJE MODELO EXTRA LARGO',
              marca: 'MARCA CON UN NOMBRE MUY LARGO',
              precio: 123456.78,
            ),
          ],
        );

        expect(tester.takeException(), isNull);
        expect(find.byType(AppListCard), findsOneWidget);
      },
    );
  });
}
