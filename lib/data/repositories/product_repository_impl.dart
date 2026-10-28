import '../../core/errors/exceptions.dart';
import '../../core/errors/failures.dart';
import '../../core/utils/either.dart';
import '../../domain/entities/product_entity.dart';
import '../../domain/repositories/product_repository.dart';
import '../datasources/auth_local_datasource.dart';
import '../datasources/product_remote_datasource.dart';

class ProductRepositoryImpl implements ProductRepository {
  final ProductRemoteDataSource remoteDataSource;
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
  }) async {
    try {
      final token = await authLocalDataSource.getToken();
      if (token == null) {
        return Either.left(const AuthenticationFailure('Sesión expirada'));
      }
      final result = await remoteDataSource.getProducts(
        token: token,
        companyId: companyId,
        page: page,
        pageSize: pageSize,
        search: search,
        tipo: tipo,
      );
      return Either.right(result);
    } on AuthException catch (e) {
      return Either.left(AuthenticationFailure(e.message));
    } on NetworkException catch (e) {
      return Either.left(NetworkFailure(e.message));
    } on ServerException catch (e) {
      return Either.left(ServerFailure(e.message));
    } on CacheException catch (e) {
      return Either.left(CacheFailure(e.message));
    } catch (e) {
      return Either.left(UnknownFailure('Error inesperado: $e'));
    }
  }
}
