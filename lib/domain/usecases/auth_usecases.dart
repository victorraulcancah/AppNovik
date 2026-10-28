import '../../core/errors/failures.dart';
import '../../core/utils/either.dart';
import '../../core/utils/validators.dart';
import '../entities/user_entity.dart';
import '../repositories/auth_repository.dart';

class LoginUseCase {
  final AuthRepository repository;
  LoginUseCase({required this.repository});

  Future<Either<Failure, UserEntity>> call(
    String usuario,
    String password,
  ) async {
    final error = Validators.validateRequired(usuario, 'El usuario') ??
        Validators.validatePassword(password);
    if (error != null) {
      return Either.left(ValidationFailure(error));
    }
    return repository.login(usuario.trim(), password);
  }
}

class LogoutUseCase {
  final AuthRepository repository;
  LogoutUseCase({required this.repository});

  Future<Either<Failure, void>> call() => repository.logout();
}

class GetLoggedUserUseCase {
  final AuthRepository repository;
  GetLoggedUserUseCase({required this.repository});

  Future<Either<Failure, UserEntity?>> call() => repository.getLoggedUser();
}
