import '../../core/errors/exceptions.dart';
import '../../core/errors/failures.dart';
import '../../core/utils/either.dart';
import '../datasources/auth_local_datasource.dart';

/// Para los repositorios que llaman a la API con el token de la sesión: lo
/// obtiene, ejecuta la llamada y traduce las excepciones a [Failure]s.
mixin TokenGuard {
  AuthLocalDataSource get authLocalDataSource;

  Future<Either<Failure, T>> withToken<T>(
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
}
