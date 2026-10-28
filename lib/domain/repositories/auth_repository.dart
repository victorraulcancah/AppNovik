import '../../core/errors/failures.dart';
import '../../core/utils/either.dart';
import '../entities/user_entity.dart';

abstract class AuthRepository {
  Future<Either<Failure, UserEntity>> login(String usuario, String password);
  Future<Either<Failure, void>> logout();

  /// Usuario guardado en el dispositivo; `null` si no hay sesión.
  Future<Either<Failure, UserEntity?>> getLoggedUser();

  /// Token de la sesión actual; `null` si no hay sesión.
  Future<String?> getToken();
}
