import 'dart:typed_data';
import '../../core/errors/failures.dart';
import '../../core/utils/either.dart';
import '../../domain/entities/client_record_entity.dart';
import '../../domain/repositories/client_record_repository.dart';
import '../datasources/auth_local_datasource.dart';
import '../datasources/client_record_remote_datasource.dart';
import 'token_guard.dart';

class ClientRecordRepositoryImpl with TokenGuard implements ClientRecordRepository {
  final ClientRecordRemoteDataSource remoteDataSource;

  @override
  final AuthLocalDataSource authLocalDataSource;

  ClientRecordRepositoryImpl({
    required this.remoteDataSource,
    required this.authLocalDataSource,
  });

  @override
  Future<Either<Failure, ClientPageEntity>> getClients({
    required int companyId,
    required int page,
    required int pageSize,
    required ClientFiltersEntity filters,
  }) =>
      withToken(
        (token) => remoteDataSource.getClients(
          token,
          companyId: companyId,
          page: page,
          pageSize: pageSize,
          filters: filters,
        ),
      );

  @override
  Future<Either<Failure, ClientFilterCatalogsEntity>> getFilterCatalogs() =>
      withToken(remoteDataSource.getFilterCatalogs);

  @override
  Future<Either<Failure, ClientFormCatalogsEntity>> getFormCatalogs({required int companyId}) =>
      withToken((token) => remoteDataSource.getFormCatalogs(token, companyId: companyId));

  @override
  Future<Either<Failure, ClientRecordEntity>> saveClient({
    required int companyId,
    required ClientFormEntity form,
    int? id,
  }) =>
      withToken(
        (token) => remoteDataSource.saveClient(token, companyId: companyId, form: form, id: id),
      );

  @override
  Future<Either<Failure, Uint8List>> exportClients({
    required int companyId,
    required ClientFiltersEntity filters,
  }) =>
      withToken(
        (token) => remoteDataSource.exportClients(token, companyId: companyId, filters: filters),
      );

  @override
  Future<Either<Failure, CategoriesConfigEntity>> getCategories() =>
      withToken(remoteDataSource.getCategories);

  @override
  Future<Either<Failure, CategoryCalcEntity?>> saveCategories({
    required List<ClientCategoryEntity> categorias,
    required String ciclo,
  }) =>
      withToken(
        (token) => remoteDataSource.saveCategories(token, categorias: categorias, ciclo: ciclo),
      );

  @override
  Future<Either<Failure, CategoryCalcEntity>> calculateCategories({required String ciclo}) =>
      withToken((token) => remoteDataSource.calculateCategories(token, ciclo: ciclo));
}
