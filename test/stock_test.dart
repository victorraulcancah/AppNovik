import 'package:app_novik/core/errors/failures.dart';
import 'package:app_novik/core/utils/either.dart';
import 'package:app_novik/core/utils/format.dart';
import 'package:app_novik/data/models/stock_model.dart';
import 'package:app_novik/domain/entities/product_form_entity.dart';
import 'package:app_novik/domain/entities/stock_entity.dart';
import 'package:app_novik/domain/repositories/stock_repository.dart';
import 'package:app_novik/domain/usecases/stock_usecases.dart';
import 'package:app_novik/presentation/providers/stock_provider.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeStockRepository implements StockRepository {
  final List<({int warehouseId, int? priceListId, bool includeZero, List<String> search, int page})>
      calls = [];
  Either<Failure, List<CatalogItemEntity>>? warehouses;

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
    );

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
}
