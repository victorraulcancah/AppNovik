import '../../core/errors/failures.dart';
import '../../core/utils/either.dart';
import '../entities/product_form_entity.dart';
import '../entities/stock_entity.dart';
import '../repositories/stock_repository.dart';

class GetWarehousesUseCase {
  final StockRepository repository;
  GetWarehousesUseCase({required this.repository});

  Future<Either<Failure, List<CatalogItemEntity>>> call(int companyId) =>
      repository.getWarehouses(companyId);
}

class GetPriceListsUseCase {
  final StockRepository repository;
  GetPriceListsUseCase({required this.repository});

  Future<Either<Failure, List<PriceListEntity>>> call(int companyId) =>
      repository.getPriceLists(companyId);
}

class GetStockUseCase {
  final StockRepository repository;
  GetStockUseCase({required this.repository});

  Future<Either<Failure, StockPageEntity>> call({
    required int companyId,
    required int warehouseId,
    int? priceListId,
    List<String> search = const [],
    bool includeZero = false,
    int page = 1,
    int pageSize = 20,
  }) =>
      repository.getStock(
        companyId: companyId,
        warehouseId: warehouseId,
        priceListId: priceListId,
        search: search,
        includeZero: includeZero,
        page: page,
        pageSize: pageSize,
      );
}
