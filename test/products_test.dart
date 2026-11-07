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
import 'package:app_novik/presentation/components/app_list_card.dart' show AppListCard;
import 'package:app_novik/presentation/widgets/product_image.dart';
import 'package:app_novik/core/constants/api_constants.dart';
import 'package:app_novik/presentation/components/app_summary.dart' show AppMetricCard;
import 'support/screen_look.dart';
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
  final List<bool?> activos = [];
  final List<(int companyId, int? id)> saves = [];
  final List<ProductFormEntity> forms = [];
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
    bool? activo,
  }) async {
    calls.add((companyId, page, search, tipo));
    activos.add(activo);
    return next ??
        Either.right(ProductPageEntity(
          items: [
            ProductEntity(id: page, codigo: 'P$page', name: 'Producto $page'),
          ],
          currentPage: page,
          lastPage: 2,
          total: 2,
          totalProductos: 1,
          totalServicios: 1,
        ));
  }

  @override
  Future<Either<Failure, ProductCatalogsEntity>> getCatalogs() async {
    catalogCalls++;
    return Either.right(const ProductCatalogsEntity(
        marcas: [CatalogItemEntity(id: 1, name: 'PIONEER')],
        categorias: [CatalogItemEntity(id: 1, name: 'PARLANTES')],
        medidas: [CatalogItemEntity(id: 1, name: 'UNIDAD')],
        proveedores: [CatalogItemEntity(id: 1, name: 'IMPORTADORA SAC')],
        canales: [CatalogItemEntity(id: 1, name: 'ELECTRÓNICA')],
        giros: [CatalogItemEntity(id: 1, name: 'CAR AUDIO')],
      ));
  }

  final List<({CatalogKind kind, String name})> created = [];
  Either<Failure, CatalogItemEntity>? nextCreated;

  @override
  Future<Either<Failure, CatalogItemEntity>> createCatalogItem({
    required CatalogKind kind,
    required String name,
  }) async {
    created.add((kind: kind, name: name));
    return nextCreated ?? Either.right(CatalogItemEntity(id: 50 + created.length, name: name));
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
    forms.add(form);
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
        createCatalogItemUseCase: CreateCatalogItemUseCase(repository: repo),
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

    test('crear manda un formulario multipart como la web, con la foto', () async {
      late http.BaseRequest sent;
      late String body;
      final dataSource = ProductRemoteDataSourceImpl(
        client: MockClient((request) async {
          sent = request;
          body = utf8.decode(request.bodyBytes, allowMalformed: true);
          return http.Response(jsonEncode({'id': 5, 'codigo': 'SUB-1', 'name': 'SUBWOOFER'}), 200);
        }),
      );

      final product = await dataSource.saveProduct(
        token: 'tok',
        companyId: 7,
        form: ProductFormEntity(
          tipo: 'p',
          codigo: 'SUB-1',
          name: 'SUBWOOFER',
          brandId: 1,
          categoryId: 2,
          providerId: 3,
          canalId: 4,
          giroNegocioId: 5,
          ventaSinStock: true,
          foto: ProductPhotoEntity(name: 'sub.jpg', bytes: Uint8List.fromList(utf8.encode('FOTO'))),
        ),
      );

      expect(product.id, 5);
      expect(sent.method, 'POST');
      expect(sent.url.path, endsWith('/productos'));
      expect(sent.headers['content-type'], startsWith('multipart/form-data'));
      for (final field in ['company_id', 'tipo', 'codigo', 'name', 'brand_id', 'vender_sin_stock', 'estado']) {
        expect(body, contains('name="$field"'), reason: field);
      }
      expect(body, contains('name="foto"; filename="sub.jpg"'));
      expect(body, contains('FOTO'));
      expect(body, isNot(contains('_method')));
      expect(body, isNot(contains('eliminar_imagen')));
    });

    test('editar va por POST con _method=put y avisa si se elimina la imagen', () async {
      late http.BaseRequest sent;
      late String body;
      final dataSource = ProductRemoteDataSourceImpl(
        client: MockClient((request) async {
          sent = request;
          body = utf8.decode(request.bodyBytes, allowMalformed: true);
          return http.Response(jsonEncode({'id': 9, 'codigo': 'X', 'name': 'Y'}), 200);
        }),
      );

      await dataSource.saveProduct(
        token: 'tok',
        companyId: 7,
        id: 9,
        form: const ProductFormEntity(
          tipo: 'p',
          codigo: 'X',
          sku: 'SKU-9',
          name: 'Y',
          brandId: 1,
          categoryId: 2,
          providerId: 3,
          canalId: 4,
          giroNegocioId: 5,
          eliminarImagen: true,
        ),
      );

      expect(sent.method, 'POST');
      expect(sent.url.path, endsWith('/productos/9'));
      expect(RegExp(r'name="_method"\r\n\r\nput').hasMatch(body), isTrue);
      expect(RegExp(r'name="eliminar_imagen"\r\n\r\ntrue').hasMatch(body), isTrue);
      expect(body, isNot(contains('name="foto"')));
    });

    test('el + de cada catálogo postea a su ruta con el nombre', () async {
      final requests = <http.BaseRequest>[];
      final bodies = <String>[];
      final dataSource = ProductRemoteDataSourceImpl(
        client: MockClient((request) async {
          requests.add(request);
          bodies.add(utf8.decode(request.bodyBytes));
          final canalOGiro = request.url.path.endsWith('canales') || request.url.path.endsWith('giros-negocio');
          return http.Response(
            jsonEncode(canalOGiro ? {'id': 70, 'nombre': 'NUEVO'} : {'id': 70, 'name': 'NUEVO'}),
            200,
          );
        }),
      );

      for (final (kind, path) in [
        (CatalogKind.medida, '/medidas'),
        (CatalogKind.marca, '/marcas'),
        (CatalogKind.categoria, '/categorias'),
        (CatalogKind.canal, '/canales'),
        (CatalogKind.giro, '/giros-negocio'),
      ]) {
        final item = await dataSource.createCatalogItem(token: 'tok', kind: kind, name: 'NUEVO');
        expect(requests.last.url.path, endsWith(path));
        expect(requests.last.method, 'POST');
        expect(jsonDecode(bodies.last), {'name': 'NUEVO'});
        expect((item.id, item.name), (70, 'NUEVO'), reason: kind.label);
      }
    });

    test('el nombre del catálogo no puede ir vacío', () async {
      final repo = _FakeProductRepository();
      final useCase = CreateCatalogItemUseCase(repository: repo);

      final empty = await useCase(kind: CatalogKind.marca, name: '   ');
      final ok = await useCase(kind: CatalogKind.marca, name: '  JBL ');

      expect(empty.left.message, 'Escribe el nombre de la marca');
      expect(ok.isRight, isTrue);
      expect(repo.created.single, (kind: CatalogKind.marca, name: 'JBL'));
    });

    test('crear en un catálogo lo deja primero en los catálogos guardados', () async {
      final repo = _FakeProductRepository();
      final provider = ProductsProvider(
        getProductsUseCase: GetProductsUseCase(repository: repo),
        getCatalogsUseCase: GetProductCatalogsUseCase(repository: repo),
        saveProductUseCase: SaveProductUseCase(repository: repo),
        exportProductsUseCase: ExportProductsUseCase(repository: repo),
        importCatalogUseCase: ImportCatalogUseCase(repository: repo),
        createCatalogItemUseCase: CreateCatalogItemUseCase(repository: repo),
      )..syncCompany(7);
      await provider.loadCatalogs();

      final item = await provider.createCatalogItem(CatalogKind.marca, 'JBL');
      final catalogs = await provider.loadCatalogs();

      expect(catalogs.marcas.map((m) => m.name), ['JBL', 'PIONEER']);
      expect(catalogs.categorias, hasLength(1));
      expect(item.name, 'JBL');
      expect(repo.catalogCalls, 1); // no volvió a pedirlos
    });

    test('la imagen del producto: sin imagen si es solo /storage/', () {
      expect(ProductModel.fromJson({'id': 1, 'img': '/storage/images/products/a.jpg'}).imagen, '/storage/images/products/a.jpg');
      expect(ProductModel.fromJson({'id': 1, 'img': '/storage/'}).imagen, isNull);
      expect(ProductModel.fromJson({'id': 1}).imagen, isNull);
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
      Future<PickedPhoto?> Function()? pickPhoto,
      ProductEntity? existing,
      Size size = const Size(360, 780),
      ScreenLook? look,
    }) async {
      if (look != null) {
        // Letra real (Roboto), modo claro u oscuro y letra grande del sistema.
        await prepareLook(tester, look);
      } else {
        // Las pruebas dibujan con la fuente Ahem (casi el doble de ancha que una real).
        tester.view.physicalSize = Size(size.width * 3, size.height * 3);
        tester.view.devicePixelRatio = 3;
        tester.platformDispatcher.textScaleFactorTestValue = 0.55;
        addTearDown(() {
          tester.view.reset();
          tester.platformDispatcher.clearTextScaleFactorTestValue();
        });
      }

      final repo = _FakeProductRepository();
      if (existing != null) {
        repo.next = Either.right(
          ProductPageEntity(items: [existing], currentPage: 1, lastPage: 1, total: 1),
        );
      }
      final products = ProductsProvider(
        getProductsUseCase: GetProductsUseCase(repository: repo),
        getCatalogsUseCase: GetProductCatalogsUseCase(repository: repo),
        saveProductUseCase: SaveProductUseCase(repository: repo),
        exportProductsUseCase: ExportProductsUseCase(repository: repo),
        importCatalogUseCase: ImportCatalogUseCase(repository: repo),
        createCatalogItemUseCase: CreateCatalogItemUseCase(repository: repo),
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
          child: lookApp(
            look,
            home: Scaffold(
              body: ProductsPage(
                pickFile: pickFile ?? pickImportFile,
                pickPhoto: pickPhoto ?? pickProductPhoto,
              ),
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

    Future<void> openCreateForm(WidgetTester tester) async {
      await openActions(tester);
      await tester.tap(find.byTooltip('Crear'));
      await tester.pumpAndSettle();
    }

    Finder inForm(Finder finder) => find.descendant(of: find.byType(BottomSheet), matching: finder);

    /// Elige [option] en la lista [label] (un desplegable del formulario).
    Future<void> choose(WidgetTester tester, String label, String option) async {
      await tester.ensureVisible(inForm(find.text(label)));
      await tester.tap(inForm(find.text(label)));
      await tester.pumpAndSettle();
      await tester.tap(find.text(option).last);
      await tester.pumpAndSettle();
    }

    Future<void> fill(WidgetTester tester, String label, String text) async {
      await tester.ensureVisible(inForm(find.widgetWithText(TextField, label)));
      await tester.enterText(inForm(find.widgetWithText(TextField, label)), text);
    }

    testWidgets('el formulario de crear es uno solo, con los campos de la web y en su orden', (tester) async {
      await pump(tester, todo);
      await openCreateForm(tester);

      // Sin pestañas.
      expect(find.text('General'), findsNothing);
      expect(find.text('Clasificación'), findsNothing);
      expect(find.text('Más opciones'), findsNothing);

      // Los campos de la web, de arriba hacia abajo.
      const orden = [
        'Tipo *',
        'Código *',
        'SKU',
        'Descripción *',
        'Estado',
        'Unidad de medida',
        'Cantidad',
        'Marca *',
        'Código de barras',
        'Categoría *',
        'Vender sin stock',
        'Proveedor *',
        'Duplicar',
        'Canal *',
        'Giro de negocio *',
        'Adicional',
        'Subir foto del producto',
      ];
      var antes = -1.0;
      for (final label in orden) {
        final finder = inForm(find.text(label));
        expect(finder, findsWidgets, reason: label);
        final y = tester.getTopLeft(finder.first).dy;
        expect(y, greaterThanOrEqualTo(antes), reason: '$label debe ir después del anterior');
        antes = y;
      }

      // Canal y giro vienen elegidos, como en la web.
      expect(inForm(find.text('ELECTRÓNICA')), findsOneWidget);
      expect(inForm(find.text('CAR AUDIO')), findsOneWidget);
      // El "+" junto a cada catálogo que se puede ampliar (el proveedor no lo tiene).
      for (final tip in [
        'Crear unidad de medida',
        'Crear marca',
        'Crear categoría',
        'Crear canal',
        'Crear giro de negocio',
      ]) {
        expect(inForm(find.byTooltip(tip)), findsOneWidget, reason: tip);
      }
      expect(inForm(find.byTooltip('Crear proveedor')), findsNothing);
    });

    testWidgets('el + crea la marca en el servidor y la deja elegida', (tester) async {
      final repo = await pump(tester, todo);
      await openCreateForm(tester);

      await tester.ensureVisible(inForm(find.byTooltip('Crear marca')));
      await tester.tap(inForm(find.byTooltip('Crear marca')));
      await tester.pumpAndSettle();
      expect(find.text('Crear marca'), findsOneWidget); // título del modal
      await tester.enterText(find.widgetWithText(TextField, 'Nombre de la marca'), 'JBL');
      await tester.tap(find.widgetWithText(FilledButton, 'Crear'));
      await tester.pumpAndSettle();

      expect(repo.created.single, (kind: CatalogKind.marca, name: 'JBL'));
      expect(inForm(find.text('JBL')), findsOneWidget); // quedó elegida
    });

    testWidgets('si el servidor rechaza el nombre, el modal sigue abierto con el motivo', (tester) async {
      final repo = await pump(tester, todo);
      repo.nextCreated = Either.left(const ValidationFailure('La Marca ya existe'));
      await openCreateForm(tester);

      await tester.ensureVisible(inForm(find.byTooltip('Crear marca')));
      await tester.tap(inForm(find.byTooltip('Crear marca')));
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextField, 'Nombre de la marca'), 'PIONEER');
      await tester.tap(find.widgetWithText(FilledButton, 'Crear'));
      await tester.pumpAndSettle();

      expect(find.text('La Marca ya existe'), findsOneWidget);
      expect(find.widgetWithText(TextField, 'Nombre de la marca'), findsOneWidget);
    });

    testWidgets('crear el producto manda los campos y la foto elegida', (tester) async {
      final repo = await pump(
        tester,
        todo,
        pickPhoto: () async => (name: 'sub.jpg', bytes: Uint8List.fromList([1, 2, 3])),
      );
      await openCreateForm(tester);

      await fill(tester, 'Código *', 'SUB-1');
      await fill(tester, 'Descripción *', 'SUBWOOFER 12');
      await choose(tester, 'Marca *', 'PIONEER');
      await choose(tester, 'Categoría *', 'PARLANTES');
      await choose(tester, 'Proveedor *', 'IMPORTADORA SAC');
      await tester.ensureVisible(inForm(find.text('Subir foto del producto')));
      await tester.tap(inForm(find.text('Subir foto del producto')));
      await tester.pumpAndSettle();
      expect(inForm(find.text('sub.jpg')), findsOneWidget);

      await tester.ensureVisible(find.widgetWithText(FilledButton, 'Crear producto'));
      await tester.tap(find.widgetWithText(FilledButton, 'Crear producto'));
      await tester.pumpAndSettle();

      final form = repo.forms.single;
      expect(form.codigo, 'SUB-1');
      expect(form.name, 'SUBWOOFER 12');
      expect(form.brandId, 1);
      expect(form.canalId, 1);
      expect(form.giroNegocioId, 1);
      expect(form.foto?.name, 'sub.jpg');
      expect(form.foto?.bytes, [1, 2, 3]);
      expect(form.eliminarImagen, isFalse);
    });

    testWidgets('una foto de 2 MB o más se rechaza con el aviso de la web', (tester) async {
      await pump(
        tester,
        todo,
        pickPhoto: () async => throw Exception('La foto debe pesar menos de 2MB'),
      );
      await openCreateForm(tester);

      await tester.ensureVisible(inForm(find.text('Subir foto del producto')));
      await tester.tap(inForm(find.text('Subir foto del producto')));
      await tester.pumpAndSettle();

      expect(inForm(find.text('La foto debe pesar menos de 2MB')), findsOneWidget);
    });

    testWidgets('editar muestra la imagen actual y permite eliminarla', (tester) async {
      final repo = await pump(
        tester,
        const {'productos.update'},
        existing: const ProductEntity(
          id: 1,
          codigo: 'P1',
          name: 'Producto 1',
          sku: 'SKU-1',
          imagen: '/storage/images/products/a.jpg',
          marcaId: 1,
          categoriaId: 1,
          proveedorId: 1,
          canalId: 1,
          giroNegocioId: 1,
        ),
      );
      await tester.tap(find.byTooltip('Editar'));
      await tester.pumpAndSettle();

      expect(inForm(find.text('Imagen actual')), findsOneWidget);
      await tester.ensureVisible(inForm(find.text('Eliminar imagen')));
      await tester.tap(inForm(find.text('Eliminar imagen')));
      await tester.pumpAndSettle();
      expect(inForm(find.text('Imagen actual')), findsNothing);

      await tester.ensureVisible(find.widgetWithText(FilledButton, 'Guardar cambios'));
      await tester.tap(find.widgetWithText(FilledButton, 'Guardar cambios'));
      await tester.pumpAndSettle();

      expect(repo.saves.single, (7, 1));
      expect(repo.forms.single.eliminarImagen, isTrue);
      expect(repo.forms.single.foto, isNull);
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

    group('modo oscuro y letra grande en pantallas completas', () {
      const largo = ProductEntity(
        id: 1,
        codigo: 'P-0001-LARGO',
        name: 'TUBO DE PVC PARA DESAGÜE DE 4 PULGADAS CON EMPAQUE DE JEBE Y ANILLO',
        marca: 'MARCA INTERNACIONAL DE TUBERÍAS',
        categoria: 'TUBERÍAS Y ACCESORIOS DE PLOMERÍA',
        unidad: 'UNIDAD',
        sku: 'SKU-1',
        marcaId: 1,
        categoriaId: 1,
        proveedorId: 1,
        canalId: 1,
        giroNegocioId: 1,
      );

      for (final look in screenLooks) {
        testWidgets('lista de Productos con todas las acciones: ${look.label}', (tester) async {
          final handle = tester.ensureSemantics();
          await pump(tester, todo, existing: largo, look: look);

          expect(find.byType(AppListCard), findsOneWidget);
          await expectLooksRight(tester, look);
          handle.dispose();
        });

        testWidgets('Productos con el menú de acciones abierto: ${look.label}', (tester) async {
          await pump(tester, todo, existing: largo, look: look);

          await tester.tap(find.text('Acciones'));
          await tester.pumpAndSettle();

          await expectLooksRight(tester, look, contrast: false);
        });

        testWidgets('formulario de crear producto: ${look.label}', (tester) async {
          await pump(tester, todo, existing: largo, look: look);
          await tester.tap(find.text('Acciones'));
          await tester.pumpAndSettle();
          await tester.tap(find.byTooltip('Crear'));
          await tester.pumpAndSettle();

          expect(find.byType(Form), findsWidgets);
          await expectLooksRight(tester, look, contrast: false);
        });
      }

      testWidgets('el detalle del producto se lee en modo oscuro con letra grande', (tester) async {
        final handle = tester.ensureSemantics();
        const look = ScreenLook(dark: true);
        await pump(tester, todo, existing: largo, look: look);

        await tester.tap(find.byTooltip('Ver detalle'));
        await tester.pumpAndSettle();

        expect(find.text('U. de medida'), findsOneWidget);
        await expectLooksRight(tester, look);
        handle.dispose();
      });
    });

    group('imagen del producto: miniatura en la lista y grande en el detalle', () {
      const conImagen = ProductEntity(
        id: 1,
        codigo: 'P1',
        name: 'Producto 1',
        imagen: '/storage/images/products/a.jpg',
      );
      const sinImagen = ProductEntity(id: 2, codigo: 'P2', name: 'Producto 2');

      testWidgets('un producto con imagen muestra su miniatura en la tarjeta', (tester) async {
        await pump(tester, const {}, existing: conImagen);

        expect(find.descendant(of: find.byType(AppListCard), matching: find.byType(ProductImage)), findsOneWidget);
        // Va a la izquierda del título.
        expect(
          tester.getTopLeft(find.byType(ProductImage)).dx,
          lessThan(tester.getTopLeft(find.text('Producto 1')).dx),
        );
      });

      testWidgets('un producto sin imagen no cambia: la tarjeta no lleva miniatura', (tester) async {
        await pump(tester, const {}, existing: sinImagen);

        expect(find.byType(ProductImage), findsNothing);
        expect(find.text('Producto 2'), findsOneWidget);
      });

      testWidgets('el detalle muestra la imagen grande, que crece y aparece con un fundido', (tester) async {
        await pump(tester, const {}, existing: conImagen);

        await tester.tap(find.text('Producto 1'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));

        Finder grow() => find.byType(ProductImageGrow);
        expect(grow(), findsOneWidget);
        // Al empezar todavía no se ve completa...
        final start = tester.widget<Opacity>(find.descendant(of: find.byType(ProductImageGrow), matching: find.byType(Opacity)).first).opacity;
        expect(start, lessThan(1));

        await tester.pumpAndSettle();
        // ...y al terminar sí.
        final end = tester.widget<Opacity>(find.descendant(of: find.byType(ProductImageGrow), matching: find.byType(Opacity)).first).opacity;
        expect(end, 1);
        expect(find.bySemanticsLabel('Imagen de Producto 1'), findsOneWidget);
      });

      testWidgets('el detalle de un producto sin imagen no trae el bloque de imagen', (tester) async {
        await pump(tester, const {}, existing: sinImagen);

        await tester.tap(find.text('Producto 2'));
        await tester.pumpAndSettle();

        expect(find.byType(ProductImageGrow), findsNothing);
        expect(find.text('U. de medida'), findsOneWidget);
      });

      testWidgets('con "quitar animaciones" la imagen sale directa', (tester) async {
        tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(
          disableAnimations: true,
        );
        addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
        await pump(tester, const {}, existing: conImagen);

        await tester.tap(find.text('Producto 1'));
        await tester.pump();

        expect(find.byType(ProductImageGrow), findsOneWidget);
        expect(find.descendant(of: find.byType(ProductImageGrow), matching: find.byType(Transform)), findsNothing);
      });

      testWidgets('en tablet la imagen grande sale en el panel de detalle', (tester) async {
        await pump(tester, const {}, existing: conImagen, size: const Size(1100, 800));

        await tester.tap(find.text('Producto 1').first);
        await tester.pumpAndSettle();

        expect(find.byType(ProductImageGrow), findsOneWidget);
        expect(find.byType(Dialog), findsNothing);
      });

      test('la dirección de la imagen: la ruta del servidor o la URL completa', () {
        expect(
          ProductImage.urlOf('/storage/images/products/a.jpg'),
          '${ApiConstants.baseDomain}/storage/images/products/a.jpg',
        );
        expect(ProductImage.urlOf('https://cdn.test/a.jpg'), 'https://cdn.test/a.jpg');
      });
    });

    group('en tablet: lista a la izquierda y detalle a la derecha', () {
      const tablet = Size(1100, 800);
      const producto = ProductEntity(
        id: 1,
        codigo: 'P1',
        name: 'Producto 1',
        sku: 'SKU-1',
        marcaId: 1,
        categoriaId: 1,
        proveedorId: 1,
        canalId: 1,
        giroNegocioId: 1,
      );

      testWidgets('sin selección el panel pide elegir un producto', (tester) async {
        await pump(tester, const {'productos.update'}, existing: producto, size: tablet);
        expect(find.text('Selecciona un producto'), findsOneWidget);
      });

      testWidgets('tocar un producto muestra su detalle a la derecha, sin modal', (tester) async {
        await pump(tester, const {'productos.update'}, existing: producto, size: tablet);

        await tester.tap(find.text('Producto 1').first);
        await tester.pumpAndSettle();

        expect(find.text('Selecciona un producto'), findsNothing);
        expect(find.text('U. de medida'), findsOneWidget);
        expect(find.byType(Dialog), findsNothing);
        expect(find.byType(BottomSheet), findsNothing);
        expect(
          tester.getTopLeft(find.text('U. de medida')).dx,
          greaterThan(tester.getTopLeft(find.text('Producto 1').first).dx + 300),
        );
        expect(tester.widget<AppListCard>(find.byType(AppListCard)).selected, isTrue);
      });

      testWidgets('"Editar" del panel abre el formulario y el detalle sigue a la vista', (tester) async {
        await pump(tester, const {'productos.update'}, existing: producto, size: tablet);
        await tester.tap(find.text('Producto 1').first);
        await tester.pumpAndSettle();

        await tester.tap(find.widgetWithText(FilledButton, 'Editar'));
        await tester.pumpAndSettle();

        expect(find.widgetWithText(FilledButton, 'Guardar cambios'), findsOneWidget);
        // El detalle no se vació: está debajo del formulario.
        expect(find.text('U. de medida'), findsOneWidget);
        expect(find.text('Selecciona un producto'), findsNothing);
      });

      testWidgets('si se cancela la edición el panel conserva el detalle y "Editar" sigue disponible', (
        tester,
      ) async {
        await pump(tester, const {'productos.update'}, existing: producto, size: tablet);
        await tester.tap(find.text('Producto 1').first);
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(FilledButton, 'Editar'));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Cancelar'));
        await tester.pumpAndSettle();

        expect(find.widgetWithText(FilledButton, 'Guardar cambios'), findsNothing);
        expect(find.text('U. de medida'), findsOneWidget);
        expect(find.text('Selecciona un producto'), findsNothing);
        final edit = tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Editar'));
        expect(edit.onPressed, isNotNull, reason: 'el botón no se queda cargando');
        expect(tester.widget<AppListCard>(find.byType(AppListCard)).selected, isTrue);
      });

      testWidgets('al guardar la edición el panel vuelve con el detalle actualizado', (tester) async {
        final repo = await pump(tester, const {'productos.update'}, existing: producto, size: tablet);
        await tester.tap(find.text('Producto 1').first);
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(FilledButton, 'Editar'));
        await tester.pumpAndSettle();

        // Lo que devuelve el servidor al recargar la lista después de guardar.
        repo.next = Either.right(
          ProductPageEntity(
            items: [
              ProductEntity(
                id: 1,
                codigo: 'P1',
                name: 'Producto editado',
                sku: 'SKU-1',
                marcaId: 1,
                categoriaId: 1,
                proveedorId: 1,
                canalId: 1,
                giroNegocioId: 1,
              ),
            ],
            currentPage: 1,
            lastPage: 1,
            total: 1,
          ),
        );
        await tester.ensureVisible(find.widgetWithText(FilledButton, 'Guardar cambios'));
        await tester.tap(find.widgetWithText(FilledButton, 'Guardar cambios'));
        await tester.pumpAndSettle();

        expect(repo.saves.single, (7, 1));
        expect(find.widgetWithText(FilledButton, 'Guardar cambios'), findsNothing);
        // El detalle del panel muestra el nombre nuevo, con la tarjeta resaltada.
        expect(find.text('Selecciona un producto'), findsNothing);
        expect(find.text('U. de medida'), findsOneWidget);
        expect(find.text('Producto editado'), findsWidgets);
        expect(find.text('Producto 1'), findsNothing);
        expect(tester.widget<AppListCard>(find.byType(AppListCard)).selected, isTrue);
      });

      testWidgets('si con los filtros el producto editado ya no sale en la lista, el panel se vacía', (
        tester,
      ) async {
        final repo = await pump(tester, const {'productos.update'}, existing: producto, size: tablet);
        await tester.tap(find.text('Producto 1').first);
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(FilledButton, 'Editar'));
        await tester.pumpAndSettle();

        repo.next = Either.right(
          ProductPageEntity(items: const [], currentPage: 1, lastPage: 1, total: 0),
        );
        await tester.ensureVisible(find.widgetWithText(FilledButton, 'Guardar cambios'));
        await tester.tap(find.widgetWithText(FilledButton, 'Guardar cambios'));
        await tester.pumpAndSettle();

        expect(find.text('U. de medida'), findsNothing);
      });

      testWidgets('sin el permiso de editar el panel no ofrece "Editar"', (tester) async {
        await pump(tester, const {}, existing: producto, size: tablet);
        await tester.tap(find.text('Producto 1').first);
        await tester.pumpAndSettle();

        expect(find.text('U. de medida'), findsOneWidget);
        expect(find.widgetWithText(FilledButton, 'Editar'), findsNothing);
      });

      testWidgets('el botón "Acciones" queda en la lista y no tapa el detalle', (tester) async {
        await pump(tester, todo, existing: producto, size: tablet);
        await tester.tap(find.text('Producto 1').first);
        await tester.pumpAndSettle();

        final dial = tester.getTopLeft(find.text('Acciones'));
        expect(dial.dx, lessThan(420), reason: 'dentro de la columna de la lista');
      });

      testWidgets('en celular nada cambia: el detalle abre como modal', (tester) async {
        await pump(tester, const {'productos.update'}, existing: producto);

        await tester.tap(find.text('Producto 1'));
        await tester.pumpAndSettle();

        expect(find.text('Selecciona un producto'), findsNothing);
        expect(find.byType(BottomSheet), findsOneWidget);
      });
    });
  });
  group('Productos: estado, contadores y términos de búsqueda', () {
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
        createCatalogItemUseCase: CreateCatalogItemUseCase(repository: repo),
      )..syncCompany(7);
    });

    test('la respuesta trae los contadores de productos y servicios', () {
      final page = ProductPageModel.fromJson({
        'current_page': 1,
        'last_page': 1,
        'total': 9,
        'total_productos': 6,
        'total_servicios': 3,
        'data': [],
      });

      expect(page.total, 9);
      expect(page.totalProductos, 6);
      expect(page.totalServicios, 3);
    });

    test('sin contadores en la respuesta quedan en 0', () {
      final page = ProductPageModel.fromJson({'current_page': 1, 'last_page': 1, 'total': 0, 'data': []});

      expect(page.totalProductos, 0);
      expect(page.totalServicios, 0);
    });

    test('el provider guarda los contadores de la última página', () async {
      repo.next = Either.right(const ProductPageEntity(
        items: [],
        currentPage: 1,
        lastPage: 1,
        total: 9,
        totalProductos: 6,
        totalServicios: 3,
      ));
      await provider.refresh();

      expect(provider.total, 9);
      expect(provider.totalProductos, 6);
      expect(provider.totalServicios, 3);
    });

    test('el filtro de estado se manda al repositorio y activa el indicador de filtros', () async {
      await provider.refresh();
      expect(provider.filtersActive, isFalse);

      await provider.setActivo(false);

      expect(repo.activos.last, isFalse);
      expect(provider.filtersActive, isTrue);
      expect(repo.calls.last.$2, 1);

      await provider.setActivo(null);
      expect(repo.activos.last, isNull);
      expect(provider.filtersActive, isFalse);
    });

    test('setFilters cambia tipo y estado con un solo pedido', () async {
      await provider.refresh();
      final before = repo.calls.length;

      await provider.setFilters(tipo: 's', activo: true);

      expect(repo.calls.length, before + 1);
      expect(repo.calls.last.$4, 's');
      expect(repo.activos.last, isTrue);
    });

    test('un término confirmado se suma a lo que se está escribiendo', () async {
      await provider.refresh();
      await provider.addSearchTerm('  tubo pvc  ');
      await provider.setSearch('azul marino');

      expect(provider.searchTerms, ['tubo pvc']);
      expect(repo.calls.last.$3, ['tubo pvc', 'azul', 'marino']);
    });

    test('confirmar un término limpia lo que se estaba escribiendo y no repite ni acepta vacíos', () async {
      await provider.refresh();
      await provider.setSearch('subwoofer');
      await provider.addSearchTerm('subwoofer');
      await provider.addSearchTerm('subwoofer');
      await provider.addSearchTerm('   ');

      expect(provider.searchTerms, ['subwoofer']);
      expect(provider.search, isEmpty);
      expect(repo.calls.last.$3, ['subwoofer']);
    });

    test('quitar un término o limpiarlos todos vuelve a pedir la lista', () async {
      await provider.addSearchTerm('uno');
      await provider.addSearchTerm('dos');

      await provider.removeSearchTerm('uno');
      expect(provider.searchTerms, ['dos']);
      expect(repo.calls.last.$3, ['dos']);

      await provider.clearSearchTerms();
      expect(provider.searchTerms, isEmpty);
      expect(repo.calls.last.$3, isEmpty);
    });

    test('cambiar de empresa limpia términos y filtros', () async {
      await provider.addSearchTerm('uno');
      await provider.setFilters(tipo: 'p', activo: false);

      provider.syncCompany(8);

      expect(provider.searchTerms, isEmpty);
      expect(provider.tipo, isNull);
      expect(provider.activo, isNull);
    });

    test('GET /productos manda el estado como filters[estado][] y el tipo como tipo_producto', () async {
      late Uri sent;
      final dataSource = ProductRemoteDataSourceImpl(
        client: MockClient((request) async {
          sent = request.url;
          return http.Response(
            jsonEncode({'current_page': 1, 'last_page': 1, 'total': 0, 'data': []}),
            200,
          );
        }),
      );

      await dataSource.getProducts(
        token: 'tok',
        companyId: 7,
        page: 1,
        pageSize: 20,
        search: const ['tubo pvc', 'azul'],
        tipo: 's',
        activo: false,
      );

      expect(sent.queryParametersAll['filters[estado][]'], ['false']);
      expect(sent.queryParametersAll['tipo_producto'], ['s']);
      expect(sent.queryParametersAll['search[]'], ['tubo pvc', 'azul']);
    });

    test('sin estado no se manda el filtro', () async {
      late Uri sent;
      final dataSource = ProductRemoteDataSourceImpl(
        client: MockClient((request) async {
          sent = request.url;
          return http.Response(
            jsonEncode({'current_page': 1, 'last_page': 1, 'total': 0, 'data': []}),
            200,
          );
        }),
      );

      await dataSource.getProducts(token: 'tok', companyId: 7, page: 1, pageSize: 20, search: const []);

      expect(sent.queryParametersAll.keys.any((k) => k.contains('estado')), isFalse);
      expect(sent.queryParametersAll.containsKey('tipo_producto'), isFalse);
    });
  });

  group('ProductsPage: búsqueda, filtros y contadores', () {
    Future<({_FakeProductRepository repo, ProductsProvider products})> pump(WidgetTester tester) async {
      // Las pruebas dibujan con la fuente Ahem (casi el doble de ancha que una real).
      tester.view.physicalSize = const Size(360 * 3, 780 * 3);
      tester.view.devicePixelRatio = 3;
      tester.platformDispatcher.textScaleFactorTestValue = 0.55;
      addTearDown(() {
        tester.view.reset();
        tester.platformDispatcher.clearTextScaleFactorTestValue();
      });

      final repo = _FakeProductRepository();
      repo.next = Either.right(
        ProductPageEntity(
          items: [ProductEntity(id: 1, codigo: 'P1', name: 'Producto 1')],
          currentPage: 1,
          lastPage: 1,
          total: 9,
          totalProductos: 6,
          totalServicios: 3,
        ),
      );
      final products = ProductsProvider(
        getProductsUseCase: GetProductsUseCase(repository: repo),
        getCatalogsUseCase: GetProductCatalogsUseCase(repository: repo),
        saveProductUseCase: SaveProductUseCase(repository: repo),
        exportProductsUseCase: ExportProductsUseCase(repository: repo),
        importCatalogUseCase: ImportCatalogUseCase(repository: repo),
        createCatalogItemUseCase: CreateCatalogItemUseCase(repository: repo),
      )..syncCompany(7);
      final session = SessionContextEntity(
        user: const UserEntity(id: 9, name: 'Ana', usuario: 'ana'),
        company: const CompanyEntity(id: 7, razonSocial: 'ACME'),
        modules: const [],
        permissions: const {},
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
          child: MaterialApp(theme: AppTheme.light, home: const Scaffold(body: ProductsPage())),
        ),
      );
      await tester.pumpAndSettle();
      return (repo: repo, products: products);
    }

    testWidgets('los contadores ya no salen sobre la lista: van en el modal de Totales', (tester) async {
      await pump(tester);

      expect(find.text('Todos: 9'), findsNothing);
      expect(find.byType(ChoiceChip), findsNothing);
    });

    testWidgets('Acciones ofrece Totales y abre Todos / Productos / Servicios con los números del servidor', (
      tester,
    ) async {
      await pump(tester);

      // Sin permisos de crear ni importar, "Totales" es la única acción: el botón flotante es esa acción.
      await tester.tap(find.text('Totales'));
      await tester.pumpAndSettle();

      Finder card(String label, String value) => find.descendant(
        of: find.widgetWithText(AppMetricCard, label),
        matching: find.text(value),
      );
      expect(card('Todos', '9'), findsOneWidget);
      expect(card('Productos', '6'), findsOneWidget);
      expect(card('Servicios', '3'), findsOneWidget);
      expect(find.text('Cerrar'), findsOneWidget);
    });

    testWidgets('Totales trae los números del servidor para la búsqueda y los filtros puestos', (tester) async {
      final env = await pump(tester);
      env.repo.next = Either.right(
        ProductPageEntity(
          items: [ProductEntity(id: 2, codigo: 'S1', name: 'Servicio 1', esServicio: true)],
          currentPage: 1,
          lastPage: 1,
          total: 3,
          totalProductos: 0,
          totalServicios: 3,
        ),
      );
      await env.products.setTipo('s');
      await tester.pumpAndSettle();

      await tester.tap(find.text('Totales'));
      await tester.pumpAndSettle();

      expect(
        find.descendant(of: find.widgetWithText(AppMetricCard, 'Todos'), matching: find.text('3')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: find.widgetWithText(AppMetricCard, 'Productos'), matching: find.text('0')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: find.widgetWithText(AppMetricCard, 'Servicios'), matching: find.text('3')),
        findsOneWidget,
      );
    });

    testWidgets('el tipo se sigue filtrando desde el panel de filtros y sale como chip', (tester) async {
      final env = await pump(tester);

      await tester.tap(find.byTooltip('Filtros'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(DropdownButtonFormField<String?>, 'Tipo'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Servicios').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ver resultados'));
      await tester.pumpAndSettle();

      expect(env.repo.calls.last.$4, 's');
      expect(env.products.tipo, 's');
      expect(find.text('Tipo: Servicios'), findsOneWidget);
    });

    testWidgets('el panel de filtros ofrece el estado y lo aplica', (tester) async {
      final env = await pump(tester);

      await tester.tap(find.byTooltip('Filtros'));
      await tester.pumpAndSettle();
      expect(find.text('Estado'), findsOneWidget);

      await tester.tap(find.widgetWithText(DropdownButtonFormField<String?>, 'Estado'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Inactivos').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ver resultados'));
      await tester.pumpAndSettle();

      expect(env.repo.activos.last, isFalse);
      expect(env.products.filtersActive, isTrue);
    });

    testWidgets('enviar la búsqueda la vuelve un chip que se puede quitar', (tester) async {
      final env = await pump(tester);

      await tester.enterText(find.byType(SearchBar), 'tubo pvc');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('chip-tubo pvc')), findsOneWidget);
      expect(env.repo.calls.last.$3, ['tubo pvc']);
      // El campo queda libre para otro término.
      expect(tester.widget<SearchBar>(find.byType(SearchBar)).controller!.text, isEmpty);

      await tester.tap(find.byTooltip('Quitar "tubo pvc"'));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('chip-tubo pvc')), findsNothing);
      expect(env.repo.calls.last.$3, isEmpty);
    });

    testWidgets('los filtros puestos salen como chips, el botón los cuenta y cada "x" recarga', (tester) async {
      final env = await pump(tester);
      // Sin filtros no hay chips ni cuenta.
      expect(find.byKey(const ValueKey('filtro-tipo')), findsNothing);
      expect(find.byKey(const ValueKey('filtro-estado')), findsNothing);

      await env.products.setFilters(tipo: 's', activo: false);
      await tester.pumpAndSettle();

      expect(find.text('Tipo: Servicios'), findsOneWidget);
      expect(find.text('Estado: Inactivos'), findsOneWidget);
      expect(find.descendant(of: find.byType(Badge), matching: find.text('2')), findsOneWidget);
      expect(find.byKey(const ValueKey('filtros-limpiar')), findsOneWidget);

      // Quitar el estado recarga sin él y deja el tipo.
      // La fila de chips se desplaza hacia el lado: con la fuente ancha de las pruebas el chip queda fuera de vista.
      await tester.ensureVisible(find.byTooltip('Quitar Estado: Inactivos'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Quitar Estado: Inactivos'));
      await tester.pumpAndSettle();
      expect(env.repo.activos.last, isNull);
      expect(env.products.tipo, 's');
      expect(find.text('Estado: Inactivos'), findsNothing);
      expect(find.text('Tipo: Servicios'), findsOneWidget);
      expect(find.descendant(of: find.byType(Badge), matching: find.text('1')), findsOneWidget);
      // Con un solo filtro ya no sale "Limpiar".
      expect(find.byKey(const ValueKey('filtros-limpiar')), findsNothing);
    });

    testWidgets('"Limpiar" quita todos los filtros con un solo pedido', (tester) async {
      final env = await pump(tester);
      await env.products.setFilters(tipo: 'p', activo: true);
      await tester.pumpAndSettle();
      final calls = env.repo.calls.length;

      await tester.tap(find.byKey(const ValueKey('filtros-limpiar')));
      await tester.pumpAndSettle();

      expect(env.repo.calls.length, calls + 1);
      expect(env.repo.calls.last.$4, isNull);
      expect(env.repo.activos.last, isNull);
      expect(find.byKey(const ValueKey('filtro-tipo')), findsNothing);
      expect(find.byType(Badge), findsOneWidget);
      expect(tester.widget<Badge>(find.byType(Badge)).isLabelVisible, isFalse);
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

