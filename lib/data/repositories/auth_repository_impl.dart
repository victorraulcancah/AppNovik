import '../../core/errors/exceptions.dart';
import '../../core/errors/failures.dart';
import '../../core/utils/either.dart';
import '../../domain/entities/user_entity.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/auth_local_datasource.dart';
import '../datasources/auth_remote_datasource.dart';

class AuthRepositoryImpl implements AuthRepository {
  final AuthRemoteDataSource remoteDataSource;
  final AuthLocalDataSource localDataSource;

  AuthRepositoryImpl({
    required this.remoteDataSource,
    required this.localDataSource,
  });

  @override
  Future<Either<Failure, UserEntity>> login(
    String usuario,
    String password,
  ) async {
    try {
      final session = await remoteDataSource.login(usuario, password);
      await localDataSource.saveSession(session.token, session.user);
      return Either.right(session.user);
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
  Future<Either<Failure, void>> logout() async {
    try {
      final token = await localDataSource.getToken();
      if (token != null) {
        try {
          await remoteDataSource.logout(token);
        } on AppException {
          // Sin red o token vencido: igual se cierra la sesión local.
        }
      }
      await localDataSource.clear();
      return Either.rightVoid();
    } on CacheException catch (e) {
      return Either.left(CacheFailure(e.message));
    } catch (e) {
      return Either.left(UnknownFailure('Error inesperado: $e'));
    }
  }

  @override
  Future<Either<Failure, UserEntity?>> getLoggedUser() async {
    try {
      return Either.right(await localDataSource.getUser());
    } on CacheException catch (e) {
      return Either.left(CacheFailure(e.message));
    } catch (e) {
      return Either.left(UnknownFailure('Error inesperado: $e'));
    }
  }

  @override
  Future<String?> getToken() => localDataSource.getToken();
}
