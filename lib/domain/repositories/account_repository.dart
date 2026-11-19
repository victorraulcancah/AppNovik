import '../../core/errors/failures.dart';
import '../../core/utils/either.dart';

/// Lo que cada usuario hace con su propia cuenta.
abstract class AccountRepository {
  /// Cambia la contraseña del usuario con sesión. Si el servidor rechaza un campo devuelve un
  /// [PasswordFieldFailure] con el campo.
  Future<Either<Failure, void>> changePassword({
    required String actual,
    required String nueva,
    required String confirmacion,
  });
}

/// Un campo del cambio de contraseña que no se aceptó: [field] es `actual`, `nueva` o
/// `nueva_confirmation` (vacío si el servidor no dijo cuál).
class PasswordFieldFailure extends ValidationFailure {
  final String field;
  const PasswordFieldFailure(this.field, super.message);
}
