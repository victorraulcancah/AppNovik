import 'package:app_novik/core/errors/failures.dart';
import 'package:app_novik/core/utils/either.dart';
import 'package:app_novik/domain/entities/user_entity.dart';
import 'package:app_novik/domain/repositories/auth_repository.dart';
import 'package:app_novik/domain/usecases/auth_usecases.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeAuthRepository implements AuthRepository {
  int loginCalls = 0;

  @override
  Future<Either<Failure, UserEntity>> login(String usuario, String password) async {
    loginCalls++;
    return Either.right(
      const UserEntity(id: 1, name: 'Test', usuario: 'TEST'),
    );
  }

  @override
  Future<Either<Failure, void>> logout() async => Either.rightVoid();

  @override
  Future<Either<Failure, UserEntity?>> getLoggedUser() async => Either.right(null);

  @override
  Future<String?> getToken() async => null;
}

void main() {
  group('LoginUseCase', () {
    test('rechaza usuario vacío sin llamar al repositorio', () async {
      final repo = _FakeAuthRepository();
      final result = await LoginUseCase(repository: repo)('', '123456');

      expect(result.isLeft, isTrue);
      expect(result.left, isA<ValidationFailure>());
      expect(repo.loginCalls, 0);
    });

    test('delega en el repositorio con datos válidos', () async {
      final repo = _FakeAuthRepository();
      final result = await LoginUseCase(repository: repo)(' admin ', '123456');

      expect(result.isRight, isTrue);
      expect(repo.loginCalls, 1);
    });
  });
}
