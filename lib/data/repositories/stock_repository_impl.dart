import 'dart:typed_data';

import '../../core/errors/failures.dart';
import '../../core/utils/either.dart';
import '../../domain/entities/document_entity.dart' show DownloadedFile;
import '../../domain/entities/other_document_entity.dart';
import '../../domain/entities/product_form_entity.dart';
import '../../domain/entities/stock_entity.dart';
import '../../domain/entities/stock_manage_entity.dart';
import '../../domain/repositories/stock_management_repository.dart';
import '../datasources/auth_local_datasource.dart';
import '../datasources/stock_remote_datasource.dart';
import 'token_guard.dart';

class StockRepositoryImpl with TokenGuard implements StockManagementRepository {
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
    String? tipo,
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
          tipo: tipo,
        ),
      );

  @override
  Future<Either<Failure, List<StockProductEntity>>> searchProducts({
    required int companyId,
    required String search,
  }) =>
      withToken((token) => remoteDataSource.searchProducts(token, companyId, search));

  @override
  Future<Either<Failure, void>> addStock({
    required int warehouseId,
    required List<({int productId, double? costo, int stock})> items,
  }) =>
      withToken(
        (token) => remoteDataSource.addStock(token: token, warehouseId: warehouseId, items: items),
      );

  @override
  Future<Either<Failure, DownloadedFile>> downloadStockTemplate() =>
      withToken((token) async => DownloadedFile(
            name: 'Plantilla de Productos(Stock).xlsx',
            bytes: await remoteDataSource.downloadStockTemplate(token),
          ));

  @override
  Future<Either<Failure, StockImportResultEntity>> importStock({
    required int companyId,
    required int warehouseId,
    required String fileName,
    required Uint8List bytes,
  }) =>
      withToken(
        (token) => remoteDataSource.importStock(
          token: token,
          companyId: companyId,
          warehouseId: warehouseId,
          fileName: fileName,
          bytes: bytes,
        ),
      );

  @override
  Future<Either<Failure, OtherDocumentEntity>> transferStock({
    required int companyId,
    required int userId,
    required int from,
    required int to,
    required List<({int productId, double cantidad})> items,
  }) =>
      withToken(
        (token) => remoteDataSource.transferStock(
          token: token,
          companyId: companyId,
          userId: userId,
          from: from,
          to: to,
          items: items,
        ),
      );
}
