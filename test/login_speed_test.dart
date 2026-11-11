import 'dart:async';

import 'package:app_novik/core/errors/failures.dart';
import 'package:app_novik/core/utils/either.dart';
import 'package:app_novik/data/datasources/auth_local_datasource.dart';
import 'package:app_novik/data/datasources/auth_remote_datasource.dart';
import 'package:app_novik/data/models/auth_session_model.dart';
import 'package:app_novik/data/models/session_context_model.dart';
import 'package:app_novik/data/models/user_model.dart';
import 'package:app_novik/data/repositories/auth_repository_impl.dart';
import 'package:app_novik/domain/entities/company_entity.dart';
import 'package:app_novik/domain/entities/saved_credentials_entity.dart';
import 'package:app_novik/domain/entities/session_context_entity.dart';
import 'package:app_novik/domain/entities/user_entity.dart';
import 'package:app_novik/domain/repositories/auth_repository.dart';
import 'package:app_novik/domain/usecases/auth_usecases.dart';
import 'package:app_novik/presentation/providers/auth_provider.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_secure_storage.dart';

const _loginUser = UserEntity(id: 9, name: 'Ana', usuario: 'ana', roles: ['Vendedor'], companyId: 7);

SessionContextEntity _session() => SessionContextEntity(
  user: const UserEntity(id: 9, name: 'Ana', usuario: 'ana'),
  company: CompanyEntity(id: 7, razonSocial: 'ACME', igv: 0.18, renta: 0.015),
  modules: const [],
  permissions: const {},
  roles: const ['Vendedor'],
  warehouses: const [],
);

/// Repositorio de auth cuyas esperas se controlan desde la prueba.
class _Repo implements AuthRepository {
  /// Mientras exista y no se complete, `/auth` no responde.
  Completer<void>? contextGate;

  /// Lo mismo para guardar o borrar las credenciales recordadas.
  Completer<void>? credentialsGate;
  bool credentialsFail = false;
  bool contextFails = false;

  final calls = <String>[];

  @override
  Future<Either<Failure, UserEntity>> login(String usuario, String password) async {
    calls.add('login');
    return Either.right(_loginUser);
  }

  @override
  Future<Either<Failure, void>> logout() async {
    calls.add('logout');
    return Either.rightVoid();
  }

  @override
  Future<Either<Failure, SessionContextEntity?>> getSessionContext() async {
    calls.add('context');
    await contextGate?.future;
    if (contextFails) return Either.left(const NetworkFailure('Sin conexión a internet'));
    return Either.right(_session());
  }

  @override
  Future<String?> getToken() async => 'tok';

  @override
  Future<Either<Failure, SavedCredentialsEntity?>> getSavedCredentials() async => Either.right(null);

  @override
  Future<Either<Failure, void>> saveCredentials(String usuario, String password) async {
    calls.add('saveCredentials');
    await credentialsGate?.future;
    return credentialsFail ? Either.left(const CacheFailure('sin espacio')) : Either.rightVoid();
  }

  @override
  Future<Either<Failure, void>> clearSavedCredentials() async {
    calls.add('clearCredentials');
    await credentialsGate?.future;
    return credentialsFail ? Either.left(const CacheFailure('sin espacio')) : Either.rightVoid();
  }
}

AuthProvider _auth(_Repo repo) => AuthProvider(
  loginUseCase: LoginUseCase(repository: repo),
  logoutUseCase: LogoutUseCase(repository: repo),
  getSessionContextUseCase: GetSessionContextUseCase(repository: repo),
  getSavedCredentialsUseCase: GetSavedCredentialsUseCase(repository: repo),
  saveCredentialsUseCase: SaveCredentialsUseCase(repository: repo),
  clearSavedCredentialsUseCase: ClearSavedCredentialsUseCase(repository: repo),
);

/// Lo que devuelve el login del backend, con la forma real (`roles` como lista de objetos).
Map<String, dynamic> _userJson() => {
  'id': 9,
  'name': 'Ana',
  'usuario': 'ana',
  'company_id': 7,
  'roles': [
    {
      'id': 3,
      'name': 'Vendedor',
      'pivot': {'model_id': 9},
    },
    {'id': 4, 'name': 'JEFE COMERCIAL'},
  ],
  'company': {'id': 7, 'razon_social': 'ACME'},
};

class _Remote implements AuthRemoteDataSource {
  @override
  Future<AuthSessionModel> login(String usuario, String password) async =>
      AuthSessionModel(token: 'tok-1', user: UserModel.fromJson(_userJson()));

  @override
  Future<void> logout(String token) async {}

  @override
  Future<SessionContextModel> fetchContext(String token) async => throw UnimplementedError();
}

const _timeout = Duration(seconds: 1);

void main() {
  group('Login: no espera lo que no hace falta', () {
    test('guardar las credenciales recordadas no hace esperar al login', () async {
      final repo = _Repo()..credentialsGate = Completer<void>();
      final auth = _auth(repo);

      final ok = await auth.login('ana', 'secreta', remember: true).timeout(_timeout);

      expect(ok, isTrue);
      expect(auth.status, AuthStatus.authenticated);
      expect(auth.session, isNotNull);
      // El guardado ya se pidió, pero sigue en curso: el login no lo esperó.
      await Future<void>.delayed(Duration.zero);
      expect(repo.calls, contains('saveCredentials'));
      expect(repo.credentialsGate!.isCompleted, isFalse);

      repo.credentialsGate!.complete();
      await Future<void>.delayed(Duration.zero);
    });

    test('borrar las credenciales (sin "recordar") tampoco espera, y se ven borradas al instante', () async {
      final repo = _Repo()..credentialsGate = Completer<void>();
      final auth = _auth(repo)..savedCredentials = const SavedCredentialsEntity(usuario: 'ana', password: 'vieja');

      final ok = await auth.login('ana', 'secreta', remember: false).timeout(_timeout);

      expect(ok, isTrue);
      expect(auth.savedCredentials, isNull);
      await Future<void>.delayed(Duration.zero);
      expect(repo.calls, contains('clearCredentials'));

      repo.credentialsGate!.complete();
      await Future<void>.delayed(Duration.zero);
    });

    test('si no se pueden guardar las credenciales, el login sigue valiendo', () async {
      final repo = _Repo()..credentialsFail = true;
      final auth = _auth(repo);

      final ok = await auth.login('ana', 'secreta', remember: true).timeout(_timeout);
      await Future<void>.delayed(Duration.zero);

      expect(ok, isTrue);
      expect(auth.status, AuthStatus.authenticated);
      expect(auth.errorMessage, isNull);
    });

    test('roles y empresa del login se avisan ANTES de que /auth responda', () async {
      final repo = _Repo()..contextGate = Completer<void>();
      final auth = _auth(repo);
      final seen = <UserEntity?>[];
      auth.addListener(() => seen.add(auth.pendingUser));

      final login = auth.login('ana', 'secreta', remember: false);
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      // /auth sigue en camino y ya se conocen los roles y la empresa.
      expect(auth.session, isNull);
      expect(auth.status, AuthStatus.loading);
      expect(auth.pendingUser?.roles, ['Vendedor']);
      expect(auth.pendingUser?.companyId, 7);
      expect(seen.last, isNotNull, reason: 'se notificó con el usuario del login ya disponible');

      repo.contextGate!.complete();
      expect(await login, isTrue);
      expect(auth.pendingUser, isNull, reason: 'con la sesión armada ya no hace falta');
      expect(auth.session?.company.id, 7);
    });

    test('si /auth falla, el aviso se retira y se cierra la sesión', () async {
      final repo = _Repo()..contextFails = true;
      final auth = _auth(repo);
      final seen = <UserEntity?>[];
      auth.addListener(() => seen.add(auth.pendingUser));

      final ok = await auth.login('ana', 'secreta', remember: false);

      expect(ok, isFalse);
      expect(auth.pendingUser, isNull);
      expect(seen.last, isNull, reason: 'quien adelantó datos debe enterarse de que no sirven');
      expect(repo.calls, contains('logout'));
      expect(repo.calls, isNot(contains('saveCredentials')));
      expect(auth.status, AuthStatus.error);
    });
  });

  group('UserModel: lo que devuelve el login', () {
    test('lee los roles (lista de objetos) y la empresa', () {
      final user = UserModel.fromJson(_userJson());
      expect(user.roles, ['Vendedor', 'JEFE COMERCIAL']);
      expect(user.companyId, 7);
    });

    test('la empresa se toma de `company` si no viene `company_id`', () {
      final user = UserModel.fromJson({'id': 1, 'name': 'A', 'usuario': 'a', 'company': {'id': 5}});
      expect(user.companyId, 5);
    });

    test('también acepta roles como textos y `company_id` como texto', () {
      final user = UserModel.fromJson({
        'id': 1,
        'name': 'A',
        'usuario': 'a',
        'company_id': '8',
        'roles': ['Vendedor', ''],
      });
      expect(user.roles, ['Vendedor']);
      expect(user.companyId, 8);
    });

    test('sin roles ni empresa (el usuario guardado en el teléfono) quedan vacíos', () {
      final user = UserModel.fromJson({'id': 1, 'name': 'A', 'usuario': 'a'});
      expect(user.roles, isEmpty);
      expect(user.companyId, isNull);
    });
  });

  group('AuthLocalDataSource: el token vive en memoria', () {
    late FakeSecureStorage storage;
    late AuthLocalDataSourceImpl local;
    final user = UserModel.fromJson(_userJson());

    setUp(() {
      storage = FakeSecureStorage();
      local = AuthLocalDataSourceImpl(storage: storage);
    });

    test('después de guardar, pedir el token no vuelve al almacenamiento seguro', () async {
      await local.saveSession('tok', user);
      storage.reads = 0;

      for (var i = 0; i < 5; i++) {
        expect(await local.getToken(), 'tok');
      }
      expect(storage.reads, 0, reason: 'cada petición a la API pedía el token: antes costaba una lectura cifrada cada una');
    });

    test('si el token ya estaba guardado de otra vez, se lee una sola vez', () async {
      storage.values['auth_token_v1'] = 'guardado';

      expect(await local.getToken(), 'guardado');
      expect(await local.getToken(), 'guardado');
      expect(await local.getToken(), 'guardado');
      expect(storage.reads, 1);
    });

    test('el token nuevo ya sirve aunque el disco no haya terminado de escribir', () async {
      storage.writeGate = Completer<void>();

      final saving = local.saveSession('tok', user);
      expect(await local.getToken(), 'tok');

      // Las dos escrituras (token y usuario) salen juntas, no una detrás de la otra.
      await Future<void>.delayed(Duration.zero);
      expect(storage.writesStarted, hasLength(2));

      storage.writeGate!.complete();
      await saving;
      expect(storage.values['auth_token_v1'], 'tok');
      expect(storage.values.containsKey('auth_user_v1'), isTrue);
    });

    test('cerrar sesión borra el token en memoria y en disco, y espera a un guardado en curso', () async {
      storage.writeGate = Completer<void>();
      final saving = local.saveSession('tok', user);
      final clearing = local.clear();

      expect(await local.getToken(), isNull, reason: 'en memoria ya no hay token');

      storage.writeGate!.complete();
      await saving;
      await clearing;

      // El borrado fue después de la escritura: no queda un token guardado tras cerrar sesión.
      expect(storage.values.containsKey('auth_token_v1'), isFalse);
      expect(storage.values.containsKey('auth_user_v1'), isFalse);
      expect(await local.getToken(), isNull);
    });
  });

  group('AuthRepository.login: no espera al disco', () {
    test('devuelve el usuario aunque el almacenamiento tarde, y el token ya se usa', () async {
      final storage = FakeSecureStorage()..writeGate = Completer<void>();
      final repo = AuthRepositoryImpl(
        remoteDataSource: _Remote(),
        localDataSource: AuthLocalDataSourceImpl(storage: storage),
      );

      final result = await repo.login('ana', 'secreta').timeout(_timeout);

      expect(result.isRight, isTrue);
      expect(result.right.roles, ['Vendedor', 'JEFE COMERCIAL']);
      expect(result.right.companyId, 7);
      expect(await repo.getToken(), 'tok-1', reason: '/auth y las demás peticiones ya pueden usarlo');
      expect(storage.values, isEmpty, reason: 'el disco todavía no terminó');

      storage.writeGate!.complete();
      await Future<void>.delayed(Duration.zero);
      expect(storage.values['auth_token_v1'], 'tok-1');
    });

    test('si el disco falla, el login igual vale (solo habría que entrar de nuevo al reabrir)', () async {
      final storage = FakeSecureStorage()..failWrites = true;
      final repo = AuthRepositoryImpl(
        remoteDataSource: _Remote(),
        localDataSource: AuthLocalDataSourceImpl(storage: storage),
      );

      final result = await repo.login('ana', 'secreta');
      await Future<void>.delayed(Duration.zero);

      expect(result.isRight, isTrue);
      expect(await repo.getToken(), 'tok-1');
    });
  });
}
