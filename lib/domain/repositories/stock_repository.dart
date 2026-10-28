import '../../core/errors/failures.dart';
import '../../core/utils/either.dart';
import '../entities/product_form_entity.dart';
import '../entities/stock_entity.dart';

abstract class StockRepository {
  /// Almacenes de la empresa que el usuario puede ver.
  Future<Either<Failure, List<CatalogItemEntity>>> getWarehouses(int companyId);

  /// Listas de precios que el usuario puede usar.
  Future<Either<Failure, List<PriceListEntity>>> getPriceLists(int companyId);

  /// Existencias de un almacén. [includeZero] suma los productos sin stock.
  Future<Either<Failure, StockPageEntity>> getStock({
    required int companyId,
    required int warehouseId,
    int? priceListId,
    List<String> search = const [],
    bool includeZero = false,
    int page = 1,
    int pageSize = 20,
  });
}
