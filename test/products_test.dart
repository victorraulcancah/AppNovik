import 'dart:convert';
import 'dart:typed_data';

import 'package:app_novik/core/errors/failures.dart';
import 'package:app_novik/core/utils/either.dart';
import 'package:app_novik/data/datasources/product_remote_datasource.dart';
import 'package:app_novik/data/datasources/theme_local_datasource.dart';
import 'package:app_novik/data/models/product_form_model.dart';
import 'package:app_novik/data/models/product_model.dart';
import 'package:app_novik/domain/entities/company_entity.dart';
import 'package:app_novik/domain/entities/document_entity.dart' show DownloadedFile;
import 'package:app_novik/domain/entities/import_entity.dart';
import 'package:app_novik/domain/entities/product_entity.dart';
import 'package:app_novik/domain/entities/product_form_entity.dart';
import 'package:app_novik/domain/entities/saved_credentials_entity.dart';
import 'package:app_novik/domain/entities/session_context_entity.dart';
import 'package:app_novik/domain/entities/user_entity.dart';
import 'package:app_novik/domain/repositories/auth_repository.dart';
import 'package:app_novik/domain/repositories/product_repository.dart';
import 'package:app_novik/domain/usecases/auth_usecases.dart';
import 'package:app_novik/domain/usecases/product_usecases.dart';
import 'package:app_novik/presentation/pages/products_page.dart';
import 'package:app_novik/presentation/providers/auth_provider.dart';
import 'package:app_novik/presentation/providers/products_provider.dart';
import 'package:app_novik/presentation/providers/theme_provider.dart';
import 'package:app_novik/presentation/utils/import_file.dart';
import 'package:app_novik/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';

class _FakeProductRepository implements ProductRepository {
  final List<(int companyId, int page, List<String> search, String? tipo)> calls = [];
  final List<(int companyId, int? id)> saves = [];
  Either<Failure, ProductPageEntity>? next;
  Either<Failure, ProductEntity>? nextSave;
  int exports = 0;
  int catalogCalls = 0;
  final List<({int companyId, ImportKind kind, String fileName, int size})> imports = [];
  Either<Failure, ImportResultEntity>? nextImport;

  @override
  Future<Either<Failure, ProductPageEntity>> getProducts({
    required int companyId,
    int page = 1,
    int pageSize = 20,
    List<String> search = const [],
    String? tipo,
  }) async {
    calls.add((companyId, page, search, tipo));
    return next ??
        Either.right(ProductPageEntity(
          items: [
            ProductEntity(id: page, codigo: 'P$page', name: 'Producto $page'),
          ],
          currentPage: page,
          lastPage: 2,
          total: 2,
        ));
  }

  @override
  Future<Either<Failure, ProductCatalogsEntity>> getCatalogs() async {
    catalogCalls++;
    return Either.right(const ProductCatalogsEntity(
        marcas: [CatalogItemEntity(id: 1, name: 'PIONEER')],
        categorias: [],
        medidas: [],
        proveedores: [],
        canales: [],
        giros: [],
      ));
  }

  @override
  Future<Either<Failure, DownloadedFile>> exportProducts() async {
    exports++;
    return Either.right(DownloadedFile(name: 'Lista de Productos.xlsx', bytes: Uint8List.fromList([1, 2])));
  }

  @override
  Future<Either<Failure, ImportResultEntity>> importFile({
    required int companyId,
    required ImportKind kind,
    required String fileName,
    required Uint8List bytes,
  }) async {
    imports.add((companyId: companyId, kind: kind, fileName: fileName, size: bytes.length));
    return nextImport ?? Either.right(const ImportResultEntity());
  }

  @override
  Future<Either<Failure, ProductEntity>> saveProduct({
    required int companyId,
    required ProductFormEntity form,
    int? id,
  }) async {
    saves.add((companyId, id));
    return nextSave ??
        Either.right(ProductEntity(id: id ?? 99, codigo: form.codigo, name: form.name));
  }
}

const _form = ProductFormEntity(
  tipo: 'p',
  codigo: 'SUB-1',
  name: 'SUBWOOFER',
  brandId: 1,
  categoryId: 2,
  providerId: 3,
  canalId: 4,
  giroNegocioId: 5,
);

void main() {
  group('ProductPageModel', () {
    test('lee la respuesta paginada de Laravel', () {
      final page = ProductPageModel.fromJson({
        'current_page': 1,
        'last_page': 3,
        'total': 57,
        'data': [
          {
            'id': 10,
            'codigo': 'SUB-1200',
            'name': 'SUBWOOFER 12"',
            'tipo': 'p',
            'estado': true,
            'brand': {'id': 1, 'name': 'PIONEER'},
            'category': {'id': 2, 'name': 'PARLANTES'},
            'measure': {'id': 3, 'name': 'UNIDAD'},
            'cantidad_bloque': 1,
            'cod_barra': '7750010123456',
            'sku': 'SKU-10',
            'descripcion': 'Con caja',
            'provider': {'id': 4, 'name': 'IMPORTADORA SAC'},
            'user': {'id': 5, 'name': 'ADMIN'},
            'vender_sin_stock': 1,
            'duplicar': false,
            'created_at': '2024-08-21T15:30:00.000000Z',
            'brand_id': 1,
            'category_id': 2,
            'measure_id': 3,
            'provider_id': 4,
            'canal_id': 6,
            'giro_negocio_id': 7,
          },
          {'id': 11, 'codigo': 'SRV-1', 'name': 'INSTALACION', 'tipo': 's', 'estado': 0},
        ],
      });

      expect(page.total, 57);
      expect(page.hasMore, isTrue);
      final first = page.items.first;
      expect(first.marca, 'PIONEER');
      expect(first.categoria, 'PARLANTES');
      expect(first.unidadLabel, 'UNIDAD (1 c/u)');
      expect(first.codBarra, '7750010123456');
      expect(first.sku, 'SKU-10');
      expect(first.proveedor, 'IMPORTADORA SAC');
      expect(first.descripcion, 'Con caja');
      expect(first.usuario, 'ADMIN');
      expect(first.ventaSinStock, isTrue);
      expect(first.duplicar, isFalse);
      expect(first.creado, isNotNull);
      expect(
        [first.marcaId, first.categoriaId, first.unidadId, first.proveedorId, first.canalId, first.giroNegocioId],
        [1, 2, 3, 4, 6, 7],
      );
      expect(first.esServicio, isFalse);
      final servicio = page.items.last;
      expect(servicio.esServicio, isTrue);
      expect(servicio.activo, isFalse);
      expect(servicio.unidadLabel, isNull);
      expect(servicio.creado, isNull);
    });
  });

  group('formulario de producto', () {
    test('el cuerpo de crear lleva los campos que valida el backend', () {
      final body = _form.toJson(companyId: 7, editing: false);

      expect(body['company_id'], 7);
      expect(body['codigo'], 'SUB-1');
      expect(body['name'], 'SUBWOOFER');
      expect(
        [body['brand_id'], body['category_id'], body['provider_id'], body['canal_id'], body['giro_negocio_id']],
        [1, 2, 3, 4, 5],
      );
      // El SKU y el código de barras vacíos se omiten: los genera el backend.
      expect(body.containsKey('sku'), isFalse);
      expect(body.containsKey('cod_barra'), isFalse);
      expect(body.containsKey('eliminar_imagen'), isFalse);
    });

    test('el cuerpo de editar exige eliminar_imagen', () {
      final body = _form.toJson(companyId: 7, editing: true);
      expect(body['eliminar_imagen'], false);
    });

    test('los catálogos aceptan name y nombre', () {
      final items = catalogFromJson([
        {'id': 1, 'name': 'PIONEER'},
        {'id': 2, 'nombre': 'ELECTRÓNICA'},
        {'id': 3},
      ]);

      expect(items.map((i) => i.name), ['PIONEER', 'ELECTRÓNICA']);
    });

    test('editar sin SKU se rechaza antes de llamar a la API', () async {
      final repo = _FakeProductRepository();
      final useCase = SaveProductUseCase(repository: repo);

      final result = await useCase(companyId: 7, form: _form, id: 10);

      expect(result.isLeft, isTrue);
      expect(result.left, isA<ValidationFailure>());
      expect(repo.saves, isEmpty);
    });
  });

  group('ProductsProvider', () {
    late _FakeProductRepository repo;
    late ProductsProvider provider;

    setUp(() {
      repo = _FakeProductRepository();
      provider = ProductsProvider(
        getProductsUseCase: GetProductsUseCase(repository: repo),
        getCatalogsUseCase: GetProductCatalogsUseCase(repository: repo),
        saveProductUseCase: SaveProductUseCase(repository: repo),
        exportProductsUseCase: ExportProductsUseCase(repository: repo),
        importCatalogUseCase: ImportCatalogUseCase(repository: repo),
      )..syncCompany(7);
    });

    test('carga la primera página con el company_id de la sesión', () async {
      await provider.ensureLoaded();

      expect(repo.calls.single.$1, 7);
      expect(repo.calls.single.$2, 1);
      expect(provider.items, hasLength(1));
      expect(provider.hasMore, isTrue);
    });

    test('loadMore añade la página siguiente y se detiene al final', () async {
      await provider.refresh();
      await provider.loadMore();
      await provider.loadMore(); // ya no hay más páginas

      expect(provider.items.map((p) => p.id), [1, 2]);
      expect(repo.calls, hasLength(2));
      expect(provider.hasMore, isFalse);
    });

    test('la búsqueda se divide en términos y reinicia la lista', () async {
      await provider.refresh();
      await provider.setSearch('subwoofer, pioneer');

      expect(repo.calls.last.$3, ['subwoofer', 'pioneer']);
      expect(repo.calls.last.$2, 1);
    });

    test('cambiar de empresa descarta los productos anteriores', () async {
      await provider.refresh();
      provider.syncCompany(8);

      expect(provider.items, isEmpty);
      await provider.ensureLoaded();
      expect(repo.calls.last.$1, 8);
    });

    test('un error en la primera página queda en error', () async {
      repo.next = Either.left(const NetworkFailure('Sin conexión a internet'));
      await provider.refresh();

      expect(provider.error, 'Sin conexión a internet');
      expect(provider.items, isEmpty);
    });

    test('guardar crea con la empresa de la sesión y recarga la lista', () async {
      final error = await provider.saveProduct(_form);

      expect(error, isNull);
      expect(repo.saves.single, (7, null));
      expect(repo.calls, isNotEmpty); // recargó
    });

    test('guardar con error devuelve el mensaje del backend', () async {
      repo.nextSave = Either.left(const ValidationFailure('El código ya existe'));

      final error = await provider.saveProduct(_form);

      expect(error, 'El código ya existe');
    });

    test('los catálogos se piden una sola vez por empresa', () async {
      final first = await provider.loadCatalogs();
      final second = await provider.loadCatalogs();

      expect(identical(first, second), isTrue);
      expect(first.marcas.single.name, 'PIONEER');
    });

    test('exportar pide el Excel de productos', () async {
      final result = await provider.exportAll();

      expect(result.right.name, 'Lista de Productos.xlsx');
      expect(repo.exports, 1);
      expect(provider.exporting, isFalse);
    });

    test('subir un Excel manda la empresa y el tipo, y recarga la lista y los catálogos', () async {
      await provider.loadCatalogs();
      expect(repo.catalogCalls, 1);

      final result = await provider.importFile(
        ImportKind.marcas,
        fileName: 'marcas.xlsx',
        bytes: Uint8List.fromList([1, 2, 3]),
      );

      expect(result.isRight, isTrue);
      expect(repo.imports.single, (companyId: 7, kind: ImportKind.marcas, fileName: 'marcas.xlsx', size: 3));
      expect(repo.calls, isNotEmpty); // recargó la lista
      await provider.loadCatalogs();
      expect(repo.catalogCalls, 2); // volvió a pedir marcas y categorías
      expect(provider.importing, isFalse);
    });

    test('si la importación falla no se recarga nada', () async {
      repo.nextImport = Either.left(const ValidationFailure('El archivo no es válido'));

      final result = await provider.importFile(
        ImportKind.productos,
        fileName: 'p.xlsx',
        bytes: Uint8List.fromList([1]),
      );

      expect(result.left.message, 'El archivo no es válido');
      expect(repo.calls, isEmpty);
    });
  });

  group('importación de Excel', () {
    test('solo se aceptan archivos .xlsx con contenido', () async {
      final repo = _FakeProductRepository();
      final useCase = ImportCatalogUseCase(repository: repo);

      final xls = await useCase(
        companyId: 7,
        kind: ImportKind.productos,
        fileName: 'productos.xls',
        bytes: Uint8List.fromList([1]),
      );
      final empty = await useCase(
        companyId: 7,
        kind: ImportKind.productos,
        fileName: 'productos.xlsx',
        bytes: Uint8List(0),
      );
      final ok = await useCase(
        companyId: 7,
        kind: ImportKind.productos,
        fileName: 'PRODUCTOS.XLSX',
        bytes: Uint8List.fromList([1]),
      );

      expect(xls.left.message, 'El archivo debe ser un Excel (.xlsx)');
      expect(empty.left.message, 'El archivo está vacío');
      expect(ok.isRight, isTrue);
      expect(repo.imports, hasLength(1));
    });

    test('la respuesta lee el mensaje o las filas con error', () {
      expect(importResultFromJson({'message': 'Importación exitosa'}).hasFailures, isFalse);

      final result = importResultFromJson({
        'failures': {
          '0': {
            'row': 3,
            'attribute': 'codigo',
            'errors': ['El código ya existe'],
          },
          '1': {
            'row': 5,
            'errors': ['Falta la marca', 'Falta la categoría'],
          },
        },
      });

      expect(result.hasFailures, isTrue);
      expect(result.failures.map((f) => f.row), [3, 5]);
      expect(result.failures.last.errors, ['Falta la marca', 'Falta la categoría']);
    });

    test('cada tipo se sube a su ruta como formulario con el archivo y la empresa', () async {
      final requests = <http.BaseRequest>[];
      final bodies = <String>[];
      final dataSource = ProductRemoteDataSourceImpl(
        client: MockClient((request) async {
          requests.add(request);
          bodies.add(utf8.decode(request.bodyBytes, allowMalformed: true));
          return http.Response(
            jsonEncode({
              'failures': {
                '0': {'row': 2, 'errors': ['Falta la marca']},
              },
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }),
      );

      for (final (kind, path) in [
        (ImportKind.productos, '/productos/import'),
        (ImportKind.marcas, '/marcas/import'),
        (ImportKind.categorias, '/categorias/import'),
      ]) {
        final result = await dataSource.importFile(
          token: 'tok',
          companyId: 7,
          kind: kind,
          fileName: 'datos.xlsx',
          bytes: Uint8List.fromList(utf8.encode('EXCEL')),
        );
        expect(requests.last.url.path, endsWith(path));
        expect(result.failures.single.row, 2);
      }

      expect(requests.first.method, 'POST');
      expect(requests.first.headers['Authorization'], 'Bearer tok');
      expect(requests.first.headers['content-type'], startsWith('multipart/form-data'));
      expect(bodies.first, contains('name="company_id"'));
      expect(bodies.first, contains('name="file"; filename="datos.xlsx"'));
      expect(bodies.first, contains('EXCEL'));
    });

    test('exportar hace POST a /productos/export', () async {
      late http.BaseRequest sent;
      final dataSource = ProductRemoteDataSourceImpl(
        client: MockClient((request) async {
          sent = request;
          return http.Response('xlsx', 200);
        }),
      );

      final bytes = await dataSource.exportProducts('tok');

      expect(sent.method, 'POST');
      expect(sent.url.path, endsWith('/productos/export'));
      expect(utf8.decode(bytes), 'xlsx');
    });

    test('las plantillas de la web vienen incluidas en la app', () async {
      TestWidgetsFlutterBinding.ensureInitialized();
      final names = <String>[];
      for (final kind in ImportKind.values) {
        final file = await loadImportTemplate(kind);
        names.add(file.name);
        expect(file.bytes.length, greaterThan(1000), reason: kind.label);
        // Un .xlsx es un ZIP: empieza con "PK".
        expect(file.bytes.sublist(0, 2), [0x50, 0x4B]);
      }
      expect(names, ['Plantilla Productos.xlsx', 'Plantilla Marcas.xlsx', 'Plantilla Categorías.xlsx']);
    });
  });

  group('ProductsPage: acciones', () {
    Future<_FakeProductRepository> pump(
      WidgetTester tester,
      Set<String> permissions, {
      Future<PickedImportFile?> Function()? pickFile,
    }) async {
      // Las pruebas dibujan con la fuente Ahem (casi el doble de ancha que una real).
      tester.view.physicalSize = const Size(360 * 3, 780 * 3);
      tester.view.devicePixelRatio = 3;
      tester.platformDispatcher.textScaleFactorTestValue = 0.55;
      addTearDown(() {
        tester.view.reset();
        tester.platformDispatcher.clearTextScaleFactorTestValue();
      });

      final repo = _FakeProductRepository();
      final products = ProductsProvider(
        getProductsUseCase: GetProductsUseCase(repository: repo),
        getCatalogsUseCase: GetProductCatalogsUseCase(repository: repo),
        saveProductUseCase: SaveProductUseCase(repository: repo),
        exportProductsUseCase: ExportProductsUseCase(repository: repo),
        importCatalogUseCase: ImportCatalogUseCase(repository: repo),
      )..syncCompany(7);
      final session = SessionContextEntity(
        user: const UserEntity(id: 9, name: 'Ana', usuario: 'ana'),
        company: const CompanyEntity(id: 7, razonSocial: 'ACME'),
        modules: const [],
        permissions: permissions,
        roles: const [],
        warehouses: const [],
      );

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<ThemeProvider>(
              create: (_) => ThemeProvider(storage: _FakeThemeStorage()),
            ),
            ChangeNotifierProvider<AuthProvider>.value(value: _auth(session)),
            ChangeNotifierProvider<ProductsProvider>.value(value: products),
          ],
          child: MaterialApp(
            theme: AppTheme.light,
            home: Scaffold(
              body: pickFile == null ? const ProductsPage() : ProductsPage(pickFile: pickFile),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      return repo;
    }

    const todo = {
      'productos.store',
      'productos.acciones-adicionales',
      'productos.export',
      'brand.store',
      'category.store',
    };

    Future<void> openActions(WidgetTester tester) async {
      await tester.tap(find.text('Acciones'));
      await tester.pumpAndSettle();
    }

    /// El arco muestra cuatro acciones a la vez; se desliza para ver las demás.
    Future<void> slideActions(WidgetTester tester) async {
      await tester.dragFrom(const Offset(180, 450), const Offset(0, -400));
      await tester.pumpAndSettle();
    }

    testWidgets('con todos los permisos salen las seis acciones de la web', (tester) async {
      await pump(tester, todo);
      await openActions(tester);

      for (final label in ['Crear', 'Descargar plantilla', 'Subir productos', 'Exportar']) {
        expect(find.byTooltip(label), findsOneWidget, reason: label);
      }
      await slideActions(tester);
      for (final label in ['Importar marcas', 'Importar categorías']) {
        expect(find.byTooltip(label), findsOneWidget, reason: label);
      }
    });

    testWidgets('cada acción sale solo con su permiso, como en la web', (tester) async {
      await pump(tester, const {'productos.store', 'productos.acciones-adicionales'});
      await openActions(tester);

      expect(find.byTooltip('Crear'), findsOneWidget);
      expect(find.byTooltip('Descargar plantilla'), findsOneWidget);
      expect(find.byTooltip('Subir productos'), findsOneWidget);
      expect(find.byTooltip('Exportar'), findsNothing); // falta productos.export
      expect(find.byTooltip('Importar marcas'), findsNothing); // falta brand.store
      expect(find.byTooltip('Importar categorías'), findsNothing); // falta category.store
    });

    testWidgets('sin ningún permiso no hay botón de acciones', (tester) async {
      await pump(tester, const {});

      expect(find.text('Acciones'), findsNothing);
    });

    testWidgets('Exportar pide el Excel de productos', (tester) async {
      final repo = await pump(tester, todo);
      await openActions(tester);

      await tester.tap(find.byTooltip('Exportar'));
      await tester.pumpAndSettle();

      expect(repo.exports, 1);
    });

    testWidgets('subir marcas: se elige el Excel, se sube y avisa', (tester) async {
      final repo = await pump(
        tester,
        todo,
        pickFile: () async => (name: 'marcas.xlsx', bytes: Uint8List.fromList([1, 2, 3])),
      );
      await openActions(tester);
      await slideActions(tester);
      await tester.tap(find.byTooltip('Importar marcas'));
      await tester.pumpAndSettle();

      expect(find.text('Importar marcas'), findsWidgets);
      // Sin archivo, Subir está desactivado.
      expect(
        tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Subir')).onPressed,
        isNull,
      );

      await tester.tap(find.text('Toca para elegir un archivo'));
      await tester.pumpAndSettle();
      expect(find.text('marcas.xlsx'), findsOneWidget);

      await tester.tap(find.widgetWithText(FilledButton, 'Subir'));
      await tester.pumpAndSettle();

      expect(repo.imports.single.kind, ImportKind.marcas);
      expect(repo.imports.single.companyId, 7);
      expect(repo.imports.single.size, 3);
      expect(find.text('Marcas subidos'), findsOneWidget);
      expect(find.text('Filas con errores'), findsNothing);
    });

    testWidgets('si el servidor devuelve filas con error se muestran una por una', (tester) async {
      final repo = await pump(
        tester,
        todo,
        pickFile: () async => (name: 'productos.xlsx', bytes: Uint8List.fromList([1])),
      );
      repo.nextImport = Either.right(const ImportResultEntity(failures: [
        ImportFailureEntity(row: 3, errors: ['El código ya existe']),
        ImportFailureEntity(row: 8, errors: ['Falta la marca', 'Falta la categoría']),
      ]));
      await openActions(tester);
      await tester.tap(find.byTooltip('Subir productos'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Toca para elegir un archivo'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Subir'));
      await tester.pumpAndSettle();

      expect(find.text('Filas con errores'), findsOneWidget);
      expect(find.text('Error en fila 3'), findsOneWidget);
      expect(find.text('El código ya existe'), findsOneWidget);
      expect(find.text('Error en fila 8'), findsOneWidget);
      expect(find.text('Falta la categoría'), findsOneWidget);
    });

    testWidgets('si el servidor rechaza el archivo, el modal sigue abierto con el motivo', (tester) async {
      final repo = await pump(
        tester,
        todo,
        pickFile: () async => (name: 'categorias.xlsx', bytes: Uint8List.fromList([1])),
      );
      repo.nextImport = Either.left(const ValidationFailure('The file field must be a file of type: xlsx.'));
      await openActions(tester);
      await slideActions(tester);
      await tester.tap(find.byTooltip('Importar categorías'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Toca para elegir un archivo'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Subir'));
      await tester.pumpAndSettle();

      expect(find.text('The file field must be a file of type: xlsx.'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Subir'), findsOneWidget);
      expect(find.text('Categorías subidos'), findsNothing);
    });

    testWidgets('si se cancela el selector no se elige nada', (tester) async {
      final repo = await pump(tester, todo, pickFile: () async => null);
      await openActions(tester);
      await tester.tap(find.byTooltip('Subir productos'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Toca para elegir un archivo'));
      await tester.pumpAndSettle();

      expect(find.text('Toca para elegir un archivo'), findsOneWidget);
      expect(
        tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Subir')).onPressed,
        isNull,
      );
      expect(repo.imports, isEmpty);
    });
  });
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
  Future<Either<Failure, void>> saveCredentials(String usuario, String password) async =>
      Either.rightVoid();

  @override
  Future<Either<Failure, void>> clearSavedCredentials() async => Either.rightVoid();
}

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

