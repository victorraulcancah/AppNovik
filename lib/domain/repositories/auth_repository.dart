import '../../core/errors/failures.dart';
import '../../core/utils/either.dart';
import '../entities/saved_credentials_entity.dart';
import '../entities/session_context_entity.dart';
import '../entities/user_entity.dart';

abstract class AuthRepository {
  Future<Either<Failure, UserEntity>> login(String usuario, String password);
  Future<Either<Failure, void>> logout();

  /// Pide al backend el contexto del usuario (empresa, módulos, permisos).
  /// `null` si no hay sesión guardada. Con token vencido devuelve
  /// [AuthenticationFailure] y borra la sesión local.
  Future<Either<Failure, SessionContextEntity?>> getSessionContext();

  /// Token de la sesión actual; `null` si no hay sesión.
  Future<String?> getToken();

  /// "Recordar credenciales": sobreviven al cierre de sesión.
  Future<Either<Failure, SavedCredentialsEntity?>> getSavedCredentials();
  Future<Either<Failure, void>> saveCredentials(String usuario, String password);
  Future<Either<Failure, void>> clearSavedCredentials();
}
