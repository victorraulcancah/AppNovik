import 'dart:convert';

import 'package:app_novik/core/errors/exceptions.dart';
import 'package:app_novik/core/errors/failures.dart';
import 'package:app_novik/core/utils/either.dart';
import 'package:app_novik/data/datasources/account_remote_datasource.dart';
import 'package:app_novik/data/datasources/theme_local_datasource.dart';
import 'package:app_novik/domain/entities/saved_credentials_entity.dart';
import 'package:app_novik/domain/entities/session_context_entity.dart';
import 'package:app_novik/domain/entities/user_entity.dart';
import 'package:app_novik/domain/repositories/account_repository.dart';
import 'package:app_novik/domain/repositories/auth_repository.dart';
import 'package:app_novik/domain/usecases/account_usecases.dart';
import 'package:app_novik/domain/usecases/auth_usecases.dart';
import 'package:app_novik/presentation/components/components.dart';
import 'package:app_novik/presentation/providers/auth_provider.dart';
import 'package:app_novik/presentation/providers/theme_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';

/// Cambiar la contraseña desde el menú de la cuenta, como en la web.
class _FakeAccountRepo implements AccountRepository {
  final List<({String actual, String nueva, String confirmacion})> calls = [];
  Failure? failure;

  @override
  Future<Either<Failure, void>> changePassword({
    required String actual,
    required String nueva,
    required String confirmacion,
  }) async {
    calls.add((actual: actual, nueva: nueva, confirmacion: confirmacion));
    final f = failure;
    return f == null ? Either.rightVoid<Failure>() : Either.left(f);
  }
}

class _FakeThemeStorage implements ThemeLocalDataSource {
  @override
  Future<ThemeMode?> read() async => null;

  @override
  Future<void> write(ThemeMode mode) async {}
}

class _FakeAuthRepository implements AuthRepository {
  final List<({String usuario, String password})> saved = [];

  @override
  Future<Either<Failure, UserEntity>> login(String usuario, String password) async =>
      Either.right(const UserEntity(id: 9, name: 'Ana', usuario: 'ana'));

  @override
  Future<Either<Failure, void>> logout() async => Either.rightVoid();

  @override
  Future<Either<Failure, SessionContextEntity?>> getSessionContext() async => Either.right(null);

  @override
  Future<String?> getToken() async => null;

  @override
  Future<Either<Failure, SavedCredentialsEntity?>> getSavedCredentials() async => Either.right(null);

  @override
  Future<Either<Failure, void>> saveCredentials(String usuario, String password) async {
    saved.add((usuario: usuario, password: password));
    return Either.rightVoid();
  }

  @override
  Future<Either<Failure, void>> clearSavedCredentials() async => Either.rightVoid();
}

AuthProvider _auth(_FakeAuthRepository repo) => AuthProvider(
      loginUseCase: LoginUseCase(repository: repo),
      logoutUseCase: LogoutUseCase(repository: repo),
      getSessionContextUseCase: GetSessionContextUseCase(repository: repo),
      getSavedCredentialsUseCase: GetSavedCredentialsUseCase(repository: repo),
      saveCredentialsUseCase: SaveCredentialsUseCase(repository: repo),
      clearSavedCredentialsUseCase: ClearSavedCredentialsUseCase(repository: repo),
    )..user = const UserEntity(id: 9, name: 'Ana', usuario: 'ana');

void main() {
  group('requisitos y nivel de seguridad', () {
    test('los cuatro primeros son obligatorios y el carácter especial solo suma', () {
      expect(passwordMeetsMandatory('Abcdef12'), isTrue);
      expect(passwordMeetsMandatory('abcdef12'), isFalse); // sin mayúscula
      expect(passwordMeetsMandatory('ABCDEF12'), isFalse); // sin minúscula
      expect(passwordMeetsMandatory('Abcdefgh'), isFalse); // sin número
      expect(passwordMeetsMandatory('Abc12'), isFalse); // corta
    });

    test('Débil, Media y Fuerte con sus puntos (de 0 a 6)', () {
      expect(passwordStrength(''), (points: 0, level: '—'));
      expect(passwordStrength('abc').level, 'Débil');
      // Los 4 obligatorios: Media; con el especial son 5: Fuerte; larga también suma.
      expect(passwordStrength('Abcdef12'), (points: 4, level: 'Media'));
      expect(passwordStrength('Abcdef12!'), (points: 5, level: 'Fuerte'));
      expect(passwordStrength('Abcdefghij12!'), (points: 6, level: 'Fuerte'));
    });
  });

  group('ChangePasswordUseCase', () {
    late _FakeAccountRepo repo;
    late ChangePasswordUseCase useCase;

    setUp(() {
      repo = _FakeAccountRepo();
      useCase = ChangePasswordUseCase(repository: repo);
    });

    Future<PasswordFieldFailure?> run(String actual, String nueva, String confirmacion) async {
      final result = await useCase(actual: actual, nueva: nueva, confirmacion: confirmacion);
      return result.isLeft ? result.left as PasswordFieldFailure : null;
    }

    test('valida lo mismo que la web antes de llamar al servidor', () async {
      expect((await run('', 'Abcdef12', 'Abcdef12'))!.field, 'actual');
      expect((await run('x', '', ''))!.field, 'nueva');
      expect((await run('x', 'abc', 'abc'))!.message, 'Debe tener 8 caracteres, una mayúscula, una minúscula y un número');
      expect((await run('Abcdef12', 'Abcdef12', 'Abcdef12'))!.message, 'La nueva contraseña debe ser distinta de la actual');
      expect((await run('x', 'Abcdef12', ''))!.field, 'nueva_confirmation');
      expect((await run('x', 'Abcdef12', 'Abcdef13'))!.message, 'Las contraseñas no coinciden');
      expect(repo.calls, isEmpty);
    });

    test('con todo en regla llama al servidor', () async {
      expect(await run('vieja', 'Abcdef12', 'Abcdef12'), isNull);
      expect(repo.calls.single, (actual: 'vieja', nueva: 'Abcdef12', confirmacion: 'Abcdef12'));
    });
  });

  group('AccountRemoteDataSource.changePassword', () {
    Future<(AccountFieldError?, http.Request)> call(http.Response Function() response) async {
      late http.Request sent;
      final ds = AccountRemoteDataSourceImpl(
        client: MockClient((r) async {
          sent = r;
          return response();
        }),
      );
      final result = await ds.changePassword('tok', actual: 'vieja', nueva: 'Abcdef12', confirmacion: 'Abcdef12');
      return (result, sent);
    }

    test('manda los mismos campos que la web, con el token', () async {
      final (error, request) = await call(() => http.Response('{"message":"Contraseña actualizada"}', 200));

      expect(error, isNull);
      expect(request.method, 'POST');
      expect(request.url.path, endsWith('/usuarios/cambiar-password'));
      expect(request.headers['Authorization'], 'Bearer tok');
      expect(jsonDecode(request.body), {'actual': 'vieja', 'nueva': 'Abcdef12', 'nueva_confirmation': 'Abcdef12'});
    });

    test('un 422 devuelve el campo y su texto (la contraseña actual incorrecta)', () async {
      final (error, _) = await call(
        () => http.Response(
          jsonEncode({
            'message': 'La contraseña actual no es correcta',
            'errors': {
              'actual': ['La contraseña actual no es correcta'],
            },
          }),
          422,
        ),
      );
      expect(error, (field: 'actual', message: 'La contraseña actual no es correcta'));
    });

    test('demasiados intentos, sesión vencida y errores del servidor', () async {
      await expectLater(call(() => http.Response('{}', 429)), throwsA(isA<ServerException>()));
      await expectLater(call(() => http.Response('{}', 401)), throwsA(isA<AuthException>()));
      await expectLater(call(() => http.Response('{}', 500)), throwsA(isA<ServerException>()));
    });
  });

  group('Cambiar contraseña en el menú de la cuenta', () {
    late _FakeAccountRepo repo;
    late _FakeAuthRepository authRepo;
    late AuthProvider auth;

    Future<void> pump(WidgetTester tester) async {
      tester.view.physicalSize = const Size(400, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      repo = _FakeAccountRepo();
      authRepo = _FakeAuthRepository();
      auth = _auth(authRepo);
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<ThemeProvider>(create: (_) => ThemeProvider(storage: _FakeThemeStorage())),
            ChangeNotifierProvider<AuthProvider>.value(value: auth),
            Provider<ChangePasswordUseCase>.value(value: ChangePasswordUseCase(repository: repo)),
          ],
          child: const MaterialApp(home: Scaffold(body: Center(child: AppAccountMenu()))),
        ),
      );
      await tester.tap(find.byTooltip('Cuenta'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cambiar contraseña'));
      await tester.pumpAndSettle();
    }

    Finder field(String label) => find.widgetWithText(TextFormField, label);

    testWidgets('el menú ofrece Cambiar contraseña y abre el formulario con sus requisitos', (tester) async {
      await pump(tester);

      expect(find.text('Cambiar contraseña'), findsWidgets);
      expect(field('Contraseña actual *'), findsOneWidget);
      expect(field('Nueva contraseña *'), findsOneWidget);
      expect(field('Confirmar nueva contraseña *'), findsOneWidget);
      expect(find.text('Tu nueva contraseña debe tener:'), findsOneWidget);
      expect(find.text('Mínimo 8 caracteres.'), findsOneWidget);
      expect(find.text('Nivel de seguridad: —'), findsOneWidget);
    });

    testWidgets('al escribir la nueva, el nivel de seguridad sube', (tester) async {
      await pump(tester);

      await tester.enterText(field('Nueva contraseña *'), 'abc');
      await tester.pump();
      expect(find.text('Nivel de seguridad: Débil'), findsOneWidget);

      await tester.enterText(field('Nueva contraseña *'), 'Abcdef12');
      await tester.pump();
      expect(find.text('Nivel de seguridad: Media'), findsOneWidget);

      await tester.enterText(field('Nueva contraseña *'), 'Abcdef12!');
      await tester.pump();
      expect(find.text('Nivel de seguridad: Fuerte'), findsOneWidget);
    });

    testWidgets('con campos vacíos o distintos avisa debajo de cada uno y no llama al servidor', (tester) async {
      await pump(tester);

      await tester.tap(find.widgetWithText(FilledButton, 'Cambiar contraseña'));
      await tester.pumpAndSettle();
      expect(find.text('Ingresa tu contraseña actual'), findsOneWidget);
      expect(find.text('Ingresa tu nueva contraseña'), findsOneWidget);
      expect(find.text('Vuelve a ingresar tu nueva contraseña'), findsOneWidget);

      await tester.enterText(field('Contraseña actual *'), 'vieja');
      await tester.enterText(field('Nueva contraseña *'), 'Abcdef12');
      await tester.enterText(field('Confirmar nueva contraseña *'), 'Abcdef13');
      await tester.tap(find.widgetWithText(FilledButton, 'Cambiar contraseña'));
      await tester.pumpAndSettle();
      expect(find.text('Las contraseñas no coinciden'), findsOneWidget);
      expect(repo.calls, isEmpty);
    });

    testWidgets('si el servidor dice que la actual no es correcta, el aviso sale en ese campo y el modal sigue', (tester) async {
      await pump(tester);
      repo.failure = const PasswordFieldFailure('actual', 'La contraseña actual no es correcta');

      await tester.enterText(field('Contraseña actual *'), 'mala');
      await tester.enterText(field('Nueva contraseña *'), 'Abcdef12');
      await tester.enterText(field('Confirmar nueva contraseña *'), 'Abcdef12');
      await tester.tap(find.widgetWithText(FilledButton, 'Cambiar contraseña'));
      await tester.pumpAndSettle();

      expect(find.text('La contraseña actual no es correcta'), findsOneWidget);
      expect(field('Contraseña actual *'), findsOneWidget);

      // Corrige la actual y vuelve a enviar: el aviso viejo no estorba.
      repo.failure = null;
      await tester.enterText(field('Contraseña actual *'), 'buena');
      await tester.tap(find.widgetWithText(FilledButton, 'Cambiar contraseña'));
      await tester.pumpAndSettle();
      expect(repo.calls.length, 2);
      expect(repo.calls.last.actual, 'buena');
    });

    testWidgets('al cambiarla se cierra, avisa y recuerda la nueva si el celular recordaba la anterior', (tester) async {
      await pump(tester);
      auth.savedCredentials = const SavedCredentialsEntity(usuario: 'ana', password: 'vieja');

      await tester.enterText(field('Contraseña actual *'), 'vieja');
      await tester.enterText(field('Nueva contraseña *'), 'Abcdef12');
      await tester.enterText(field('Confirmar nueva contraseña *'), 'Abcdef12');
      await tester.tap(find.widgetWithText(FilledButton, 'Cambiar contraseña'));
      await tester.pumpAndSettle();

      expect(repo.calls.single, (actual: 'vieja', nueva: 'Abcdef12', confirmacion: 'Abcdef12'));
      expect(field('Contraseña actual *'), findsNothing);
      expect(find.text('Contraseña actualizada'), findsOneWidget);
      expect(authRepo.saved.single, (usuario: 'ana', password: 'Abcdef12'));
      expect(auth.savedCredentials!.password, 'Abcdef12');
    });

    testWidgets('sin contraseña recordada no guarda nada', (tester) async {
      await pump(tester);

      await tester.enterText(field('Contraseña actual *'), 'vieja');
      await tester.enterText(field('Nueva contraseña *'), 'Abcdef12');
      await tester.enterText(field('Confirmar nueva contraseña *'), 'Abcdef12');
      await tester.tap(find.widgetWithText(FilledButton, 'Cambiar contraseña'));
      await tester.pumpAndSettle();

      expect(authRepo.saved, isEmpty);
    });
  });
}
