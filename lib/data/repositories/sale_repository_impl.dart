import '../../core/errors/failures.dart';
import '../../core/utils/either.dart';
import '../../domain/entities/sale_entity.dart';
import '../../domain/repositories/sale_repository.dart';
import '../datasources/auth_local_datasource.dart';
import '../datasources/sale_remote_datasource.dart';
import 'token_guard.dart';

class SaleRepositoryImpl with TokenGuard implements SaleRepository {
  final SaleRemoteDataSource remoteDataSource;

  @override
  final AuthLocalDataSource authLocalDataSource;

  SaleRepositoryImpl({
    required this.remoteDataSource,
    required this.authLocalDataSource,
  });

  @override
  Future<Either<Failure, List<ClientEntity>>> searchClients({
    required int companyId,
    required String search,
  }) =>
      withToken((token) => remoteDataSource.searchClients(token, companyId, search));

  @override
  Future<Either<Failure, List<SaleProductEntity>>> searchProducts({
    required int companyId,
    required String search,
  }) =>
      withToken((token) => remoteDataSource.searchProducts(token, companyId, search));

  @override
  Future<Either<Failure, ExchangeRateEntity>> getExchangeRate() =>
      withToken(remoteDataSource.getExchangeRate);

  @override
  Future<Either<Failure, ClientEntity>> getWalkInClient(int companyId) =>
      withToken((token) => remoteDataSource.getWalkInClient(token, companyId));

  @override
  Future<Either<Failure, SaleProductFiltersEntity>> getProductFilters() =>
      withToken(remoteDataSource.getProductFilters);

  @override
  Future<Either<Failure, List<PaymentMethodEntity>>> getPaymentMethods() =>
      withToken(remoteDataSource.getPaymentMethods);

  @override
  Future<Either<Failure, SaleResultEntity>> createSale({
    required int companyId,
    required int userId,
    required SaleFormEntity form,
  }) =>
      withToken(
        (token) => remoteDataSource.createSale(
          token: token,
          companyId: companyId,
          userId: userId,
          form: form,
        ),
      );
}
