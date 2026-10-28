import '../../core/errors/failures.dart';
import '../../core/utils/either.dart';
import '../../core/utils/validators.dart';
import '../entities/saved_credentials_entity.dart';
import '../entities/session_context_entity.dart';
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
        Validators.validateRequired(password, 'La contraseña');
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

class GetSessionContextUseCase {
  final AuthRepository repository;
  GetSessionContextUseCase({required this.repository});

  Future<Either<Failure, SessionContextEntity?>> call() =>
      repository.getSessionContext();
}

class GetSavedCredentialsUseCase {
  final AuthRepository repository;
  GetSavedCredentialsUseCase({required this.repository});

  Future<Either<Failure, SavedCredentialsEntity?>> call() =>
      repository.getSavedCredentials();
}

class SaveCredentialsUseCase {
  final AuthRepository repository;
  SaveCredentialsUseCase({required this.repository});

  Future<Either<Failure, void>> call(String usuario, String password) =>
      repository.saveCredentials(usuario.trim(), password);
}

class ClearSavedCredentialsUseCase {
  final AuthRepository repository;
  ClearSavedCredentialsUseCase({required this.repository});

  Future<Either<Failure, void>> call() => repository.clearSavedCredentials();
}
