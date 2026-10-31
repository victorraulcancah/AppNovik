import 'dart:typed_data';

import '../../core/errors/failures.dart';
import '../../core/utils/either.dart';
import '../../domain/entities/document_entity.dart' show DownloadedFile;
import '../../domain/entities/import_entity.dart';
import '../../domain/entities/product_entity.dart';
import '../../domain/entities/product_form_entity.dart';
import '../../domain/repositories/product_repository.dart';
import '../datasources/auth_local_datasource.dart';
import '../datasources/product_remote_datasource.dart';
import 'token_guard.dart';

class ProductRepositoryImpl with TokenGuard implements ProductRepository {
  final ProductRemoteDataSource remoteDataSource;

  @override
  final AuthLocalDataSource authLocalDataSource;

  ProductRepositoryImpl({
    required this.remoteDataSource,
    required this.authLocalDataSource,
  });

  @override
  Future<Either<Failure, ProductPageEntity>> getProducts({
    required int companyId,
    int page = 1,
    int pageSize = 20,
    List<String> search = const [],
    String? tipo,
  }) =>
      withToken(
        (token) => remoteDataSource.getProducts(
          token: token,
          companyId: companyId,
          page: page,
          pageSize: pageSize,
          search: search,
          tipo: tipo,
        ),
      );

  @override
  Future<Either<Failure, ProductCatalogsEntity>> getCatalogs() =>
      withToken(remoteDataSource.getCatalogs);

  @override
  Future<Either<Failure, CatalogItemEntity>> createCatalogItem({
    required CatalogKind kind,
    required String name,
  }) =>
      withToken(
        (token) => remoteDataSource.createCatalogItem(token: token, kind: kind, name: name),
      );

  @override
  Future<Either<Failure, DownloadedFile>> exportProducts() => withToken(
        (token) async => DownloadedFile(
          name: 'Lista de Productos.xlsx',
          bytes: await remoteDataSource.exportProducts(token),
        ),
      );

  @override
  Future<Either<Failure, ImportResultEntity>> importFile({
    required int companyId,
    required ImportKind kind,
    required String fileName,
    required Uint8List bytes,
  }) =>
      withToken(
        (token) => remoteDataSource.importFile(
          token: token,
          companyId: companyId,
          kind: kind,
          fileName: fileName,
          bytes: bytes,
        ),
      );

  @override
  Future<Either<Failure, ProductEntity>> saveProduct({
    required int companyId,
    required ProductFormEntity form,
    int? id,
  }) =>
      withToken(
        (token) => remoteDataSource.saveProduct(
          token: token,
          companyId: companyId,
          form: form,
          id: id,
        ),
      );
}
