import 'dart:typed_data';
import '../../core/errors/failures.dart';
import '../../core/utils/either.dart';
import '../../domain/entities/debt_entity.dart';
import '../../domain/repositories/debt_repository.dart';
import '../datasources/auth_local_datasource.dart';
import '../datasources/debt_remote_datasource.dart';
import 'token_guard.dart';

class DebtRepositoryImpl with TokenGuard implements DebtRepository {
  final DebtRemoteDataSource remoteDataSource;

  @override
  final AuthLocalDataSource authLocalDataSource;

  DebtRepositoryImpl({
    required this.remoteDataSource,
    required this.authLocalDataSource,
  });

  @override
  Future<Either<Failure, DebtPageEntity>> getDebts({
    required int page,
    required int pageSize,
    required DebtFiltersEntity filters,
  }) =>
      withToken(
        (token) => remoteDataSource.getDebts(token, page: page, pageSize: pageSize, filters: filters),
      );

  @override
  Future<Either<Failure, List<DebtOption>>> searchClients({
    required int companyId,
    required String search,
    required bool onlyMine,
  }) =>
      withToken(
        (token) => remoteDataSource.searchClients(
          token,
          companyId: companyId,
          search: search,
          onlyMine: onlyMine,
        ),
      );

  @override
  Future<Either<Failure, List<DebtOption>>> getSellers({required int companyId}) =>
      withToken((token) => remoteDataSource.getSellers(token, companyId: companyId));

  @override
  Future<Either<Failure, Uint8List>> exportDebts({required DebtFiltersEntity filters}) =>
      withToken((token) => remoteDataSource.exportDebts(token, filters: filters));
}
