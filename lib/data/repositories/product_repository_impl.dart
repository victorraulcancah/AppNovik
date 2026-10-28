import '../../core/errors/exceptions.dart';
import '../../core/errors/failures.dart';
import '../../core/utils/either.dart';
import '../../domain/entities/product_entity.dart';
import '../../domain/entities/product_form_entity.dart';
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

  /// Ejecuta [action] con el token de la sesión y traduce las excepciones.
  Future<Either<Failure, T>> _withToken<T>(
    Future<T> Function(String token) action,
  ) async {
    try {
      final token = await authLocalDataSource.getToken();
      if (token == null) {
        return Either.left(const AuthenticationFailure('Sesión expirada'));
      }
      return Either.right(await action(token));
    } on AuthException catch (e) {
      return Either.left(AuthenticationFailure(e.message));
    } on ValidationException catch (e) {
      return Either.left(ValidationFailure(e.message));
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

  @override
  Future<Either<Failure, ProductPageEntity>> getProducts({
    required int companyId,
    int page = 1,
    int pageSize = 20,
    List<String> search = const [],
    String? tipo,
  }) =>
      _withToken(
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
      _withToken(remoteDataSource.getCatalogs);

  @override
  Future<Either<Failure, ProductEntity>> saveProduct({
    required int companyId,
    required ProductFormEntity form,
    int? id,
  }) =>
      _withToken(
        (token) => remoteDataSource.saveProduct(
          token: token,
          companyId: companyId,
          form: form,
          id: id,
        ),
      );
}
