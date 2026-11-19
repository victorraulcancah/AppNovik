import '../../core/errors/failures.dart';
import '../../core/utils/either.dart';
import '../../domain/repositories/account_repository.dart';
import '../datasources/account_remote_datasource.dart';
import '../datasources/auth_local_datasource.dart';
import 'token_guard.dart';

class AccountRepositoryImpl with TokenGuard implements AccountRepository {
  final AccountRemoteDataSource remoteDataSource;

  @override
  final AuthLocalDataSource authLocalDataSource;

  AccountRepositoryImpl({required this.remoteDataSource, required this.authLocalDataSource});

  @override
  Future<Either<Failure, void>> changePassword({
    required String actual,
    required String nueva,
    required String confirmacion,
  }) async {
    final result = await withToken(
      (token) => remoteDataSource.changePassword(
        token,
        actual: actual,
        nueva: nueva,
        confirmacion: confirmacion,
      ),
    );
    return result.fold<Either<Failure, void>>(
      (failure) => Either.left(failure),
      (error) => error == null
          ? Either.rightVoid<Failure>()
          : Either.left(PasswordFieldFailure(error.field, error.message)),
    );
  }
}
