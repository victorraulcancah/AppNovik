import '../../core/errors/failures.dart';
import '../../core/utils/either.dart';
import '../repositories/account_repository.dart';

/// Los requisitos de la contraseña nueva, los mismos de la web: los cuatro primeros son obligatorios y el
/// carácter especial solo suma al nivel de seguridad.
class PasswordRequirement {
  final String text;
  final bool mandatory;
  final bool Function(String) met;

  const PasswordRequirement(this.text, this.met, {this.mandatory = true});
}

final passwordRequirements = <PasswordRequirement>[
  PasswordRequirement('Mínimo 8 caracteres.', (c) => c.length >= 8),
  PasswordRequirement('Al menos una letra mayúscula (A–Z).', (c) => RegExp('[A-Z]').hasMatch(c)),
  PasswordRequirement('Al menos una letra minúscula (a–z).', (c) => RegExp('[a-z]').hasMatch(c)),
  PasswordRequirement('Al menos un número (0–9).', (c) => RegExp('[0-9]').hasMatch(c)),
  PasswordRequirement(
    'Opcional: un carácter especial (! @ # \$ %).',
    (c) => RegExp('[^A-Za-z0-9]').hasMatch(c),
    mandatory: false,
  ),
];

bool passwordMeetsMandatory(String password) =>
    passwordRequirements.every((r) => !r.mandatory || r.met(password));

/// Qué tan segura es una contraseña, de 0 a 6 puntos (los requisitos cumplidos y uno más por tener 12
/// o más caracteres), con su nivel: Débil, Media o Fuerte.
({int points, String level}) passwordStrength(String password) {
  if (password.isEmpty) return (points: 0, level: '—');
  final points = passwordRequirements.where((r) => r.met(password)).length + (password.length >= 12 ? 1 : 0);
  if (!passwordMeetsMandatory(password)) return (points: points, level: 'Débil');
  return (points: points, level: points < 5 ? 'Media' : 'Fuerte');
}

const _weakMessage = 'Debe tener 8 caracteres, una mayúscula, una minúscula y un número';

/// Cambiar la propia contraseña (pide la actual). Valida lo mismo que la web antes de llamar al servidor.
class ChangePasswordUseCase {
  final AccountRepository repository;
  ChangePasswordUseCase({required this.repository});

  Future<Either<Failure, void>> call({
    required String actual,
    required String nueva,
    required String confirmacion,
  }) {
    if (actual.isEmpty) {
      return Future.value(Either.left(const PasswordFieldFailure('actual', 'Ingresa tu contraseña actual')));
    }
    if (nueva.isEmpty) {
      return Future.value(Either.left(const PasswordFieldFailure('nueva', 'Ingresa tu nueva contraseña')));
    }
    if (!passwordMeetsMandatory(nueva)) {
      return Future.value(Either.left(const PasswordFieldFailure('nueva', _weakMessage)));
    }
    if (nueva == actual) {
      return Future.value(
        Either.left(const PasswordFieldFailure('nueva', 'La nueva contraseña debe ser distinta de la actual')),
      );
    }
    if (confirmacion.isEmpty) {
      return Future.value(
        Either.left(const PasswordFieldFailure('nueva_confirmation', 'Vuelve a ingresar tu nueva contraseña')),
      );
    }
    if (confirmacion != nueva) {
      return Future.value(
        Either.left(const PasswordFieldFailure('nueva_confirmation', 'Las contraseñas no coinciden')),
      );
    }
    return repository.changePassword(actual: actual, nueva: nueva, confirmacion: confirmacion);
  }
}
