import '../../core/errors/failures.dart';
import '../../core/utils/either.dart';
import '../../domain/entities/document_entity.dart' show DownloadedFile;
import '../../domain/entities/product_form_entity.dart';
import '../../domain/entities/stock_entity.dart';
import '../../domain/repositories/stock_repository.dart';
import '../datasources/auth_local_datasource.dart';
import '../datasources/stock_remote_datasource.dart';
import 'token_guard.dart';

class StockRepositoryImpl with TokenGuard implements StockRepository {
  final StockRemoteDataSource remoteDataSource;

  @override
  final AuthLocalDataSource authLocalDataSource;

  StockRepositoryImpl({
    required this.remoteDataSource,
    required this.authLocalDataSource,
  });

  @override
  Future<Either<Failure, List<CatalogItemEntity>>> getWarehouses(int companyId) =>
      withToken((token) => remoteDataSource.getWarehouses(token, companyId));

  @override
  Future<Either<Failure, List<PriceListEntity>>> getPriceLists(int companyId) =>
      withToken((token) => remoteDataSource.getPriceLists(token, companyId));

  @override
  Future<Either<Failure, DownloadedFile>> exportStock({
    required int warehouseId,
    int? priceListId,
    List<String> search = const [],
    required String name,
  }) =>
      withToken((token) async => DownloadedFile(
            name: name,
            bytes: await remoteDataSource.exportStock(
              token: token,
              warehouseId: warehouseId,
              priceListId: priceListId,
              search: search,
            ),
          ));

  @override
  Future<Either<Failure, StockPageEntity>> getStock({
    required int companyId,
    required int warehouseId,
    int? priceListId,
    List<String> search = const [],
    bool includeZero = false,
    int page = 1,
    int pageSize = 20,
  }) =>
      withToken(
        (token) => remoteDataSource.getStock(
          token: token,
          companyId: companyId,
          warehouseId: warehouseId,
          priceListId: priceListId,
          search: search,
          includeZero: includeZero,
          page: page,
          pageSize: pageSize,
        ),
      );
}
