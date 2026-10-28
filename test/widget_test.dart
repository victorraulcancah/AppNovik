import 'package:app_novik/core/errors/failures.dart';
import 'package:app_novik/core/utils/either.dart';
import 'package:app_novik/core/utils/slug.dart';
import 'package:app_novik/data/models/session_context_model.dart';
import 'package:app_novik/domain/entities/saved_credentials_entity.dart';
import 'package:app_novik/domain/entities/session_context_entity.dart';
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
  Future<Either<Failure, SessionContextEntity?>> getSessionContext() async =>
      Either.right(null);

  @override
  Future<String?> getToken() async => null;

  @override
  Future<Either<Failure, SavedCredentialsEntity?>> getSavedCredentials() async =>
      Either.right(null);

  @override
  Future<Either<Failure, void>> saveCredentials(String usuario, String password) async =>
      Either.rightVoid();

  @override
  Future<Either<Failure, void>> clearSavedCredentials() async => Either.rightVoid();
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

    test('rechaza contraseña vacía', () async {
      final repo = _FakeAuthRepository();
      final result = await LoginUseCase(repository: repo)('admin', '');

      expect(result.isLeft, isTrue);
      expect(repo.loginCalls, 0);
    });

    test('delega en el repositorio con datos válidos', () async {
      final repo = _FakeAuthRepository();
      final result = await LoginUseCase(repository: repo)(' admin ', '123456');

      expect(result.isRight, isTrue);
      expect(repo.loginCalls, 1);
    });
  });

  group('toSlug', () {
    test('replica convertToSlug del backend', () {
      expect(toSlug('Ventas'), 'ventas');
      expect(toSlug('Estado de Cuenta'), 'estado-de-cuenta');
      expect(toSlug('Métodos de pago'), 'metodos-de-pago');
    });
  });

  group('SessionContextModel', () {
    // Forma de POST /auth (incluye campos sensibles de la empresa que la app ignora).
    final json = {
      'user': {
        'id': 7,
        'name': 'Ana',
        'usuario': 'ANA',
        'email': null,
        'telefono': null,
        'company': {
          'id': 3,
          'razon_social': 'EMPRESA SAC',
          'ruc': '20123456789',
          'clave': 'secreto',
          'igv': '18.00',
          'profile': {
            'name': 'PLAN PRO',
            'documentos_max': 500,
            'almacenes_max': 2,
            'estado_cuenta_clientes': 1,
            'ecommerce': 0,
          },
        },
        'warehouses': [
          {'id': 1, 'name': 'ALMACEN 1', 'codigo': 'ALM001'},
        ],
        'permissions': [
          {'name': 'ventas.index'},
          {'name': 'productos.index'},
        ],
        'roles': [
          {'name': 'vendedor'},
        ],
      },
      'modulos': [
        {'id': 1, 'name': 'Ventas', 'icon': 'fa-shopping-cart'},
        {'id': 2, 'name': 'Productos', 'icon': 'fa-box'},
      ],
    };

    test('lee empresa, plan, módulos y permisos', () {
      final ctx = SessionContextModel.fromJson(json);

      expect(ctx.company.razonSocial, 'EMPRESA SAC');
      expect(ctx.company.igv, 18.0);
      expect(ctx.company.plan?.almacenesMax, 2);
      expect(ctx.company.plan?.estadoCuentaClientes, isTrue);
      expect(ctx.company.plan?.ecommerce, isFalse);
      expect(ctx.hasModule('ventas'), isTrue);
      expect(ctx.hasModule('reportes'), isFalse);
      expect(ctx.can('productos.index'), isTrue);
      expect(ctx.warehouses.single.name, 'ALMACEN 1');
      expect(ctx.roles, ['vendedor']);
    });

    test('falla si el usuario no tiene empresa', () {
      final sinEmpresa = {
        'user': {'id': 1, 'name': 'X', 'usuario': 'X', 'company': null},
        'modulos': [],
      };
      expect(() => SessionContextModel.fromJson(sinEmpresa), throwsFormatException);
    });
  });
}
