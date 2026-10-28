import 'package:app_novik/core/errors/failures.dart';
import 'package:app_novik/core/utils/either.dart';
import 'package:app_novik/data/models/product_form_model.dart';
import 'package:app_novik/data/models/product_model.dart';
import 'package:app_novik/domain/entities/product_entity.dart';
import 'package:app_novik/domain/entities/product_form_entity.dart';
import 'package:app_novik/domain/repositories/product_repository.dart';
import 'package:app_novik/domain/usecases/product_usecases.dart';
import 'package:app_novik/presentation/providers/products_provider.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeProductRepository implements ProductRepository {
  final List<(int companyId, int page, List<String> search, String? tipo)> calls = [];
  final List<(int companyId, int? id)> saves = [];
  Either<Failure, ProductPageEntity>? next;
  Either<Failure, ProductEntity>? nextSave;

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
  Future<Either<Failure, ProductCatalogsEntity>> getCatalogs() async =>
      Either.right(const ProductCatalogsEntity(
        marcas: [CatalogItemEntity(id: 1, name: 'PIONEER')],
        categorias: [],
        medidas: [],
        proveedores: [],
        canales: [],
        giros: [],
      ));

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
  });
}
