import 'dart:typed_data';

import '../../core/errors/failures.dart';
import '../../core/utils/either.dart';
import '../../domain/entities/import_entity.dart';
import '../../domain/entities/price_list_entity.dart';
import '../../domain/repositories/price_list_repository.dart';
import '../datasources/auth_local_datasource.dart';
import '../datasources/price_list_remote_datasource.dart';
import 'token_guard.dart';

class PriceListRepositoryImpl with TokenGuard implements PriceListRepository {
  final PriceListRemoteDataSource remoteDataSource;

  @override
  final AuthLocalDataSource authLocalDataSource;

  PriceListRepositoryImpl({
    required this.remoteDataSource,
    required this.authLocalDataSource,
  });

  @override
  Future<Either<Failure, PriceListPageEntity>> getPriceLists({
    required int companyId,
    required int page,
    required int pageSize,
    required PriceListFiltersEntity filters,
  }) => withToken(
    (token) => remoteDataSource.getPriceLists(
      token,
      companyId: companyId,
      page: page,
      pageSize: pageSize,
      filters: filters,
    ),
  );

  @override
  Future<Either<Failure, PriceListEntity>> savePriceList({
    required int companyId,
    required PriceListFormEntity form,
    int? id,
  }) => withToken(
    (token) => remoteDataSource.savePriceList(
      token,
      companyId: companyId,
      form: form,
      id: id,
    ),
  );

  @override
  Future<Either<Failure, PriceListProductPageEntity>> getProducts({
    required int listPriceId,
    required int page,
    required int pageSize,
    required PriceListProductFiltersEntity filters,
  }) => withToken(
    (token) => remoteDataSource.getProducts(
      token,
      listPriceId: listPriceId,
      page: page,
      pageSize: pageSize,
      filters: filters,
    ),
  );

  @override
  Future<Either<Failure, PriceListProductEntity>> updatePrice({
    required int listPriceId,
    required int productId,
    required double precio,
  }) => withToken(
    (token) => remoteDataSource.updatePrice(
      token,
      listPriceId: listPriceId,
      productId: productId,
      precio: precio,
    ),
  );

  @override
  Future<Either<Failure, Uint8List>> exportTemplate({
    required int listPriceId,
  }) => withToken(
    (token) => remoteDataSource.exportTemplate(token, listPriceId: listPriceId),
  );

  @override
  Future<Either<Failure, ImportResultEntity>> importPrices({
    required int listPriceId,
    required int companyId,
    required String fileName,
    required Uint8List bytes,
  }) => withToken(
    (token) => remoteDataSource.importPrices(
      token,
      listPriceId: listPriceId,
      companyId: companyId,
      fileName: fileName,
      bytes: bytes,
    ),
  );
}
