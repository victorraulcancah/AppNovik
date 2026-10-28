import 'package:app_novik/core/errors/failures.dart';
import 'package:app_novik/core/utils/either.dart';
import 'package:app_novik/data/models/product_model.dart';
import 'package:app_novik/domain/entities/product_entity.dart';
import 'package:app_novik/domain/repositories/product_repository.dart';
import 'package:app_novik/domain/usecases/product_usecases.dart';
import 'package:app_novik/presentation/providers/products_provider.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeProductRepository implements ProductRepository {
  final List<(int companyId, int page, List<String> search, String? tipo)> calls = [];
  Either<Failure, ProductPageEntity>? next;

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
}

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
            'measure': {'id': 3, 'name': 'UND'},
            'warehouses': [
              {'id': 1, 'name': 'A1', 'pivot': {'stock': '10.00'}},
              {'id': 2, 'name': 'A2', 'pivot': {'stock': 14}},
            ],
          },
          {'id': 11, 'codigo': 'SRV-1', 'name': 'INSTALACION', 'tipo': 's', 'estado': 0},
        ],
      });

      expect(page.total, 57);
      expect(page.hasMore, isTrue);
      final first = page.items.first;
      expect(first.marca, 'PIONEER');
      expect(first.categoria, 'PARLANTES');
      expect(first.stockTotal, 24);
      expect(first.esServicio, isFalse);
      final servicio = page.items.last;
      expect(servicio.esServicio, isTrue);
      expect(servicio.activo, isFalse);
      expect(servicio.stockTotal, isNull);
    });
  });

  group('ProductsProvider', () {
    late _FakeProductRepository repo;
    late ProductsProvider provider;

    setUp(() {
      repo = _FakeProductRepository();
      provider = ProductsProvider(
        getProductsUseCase: GetProductsUseCase(repository: repo),
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
  });
}
