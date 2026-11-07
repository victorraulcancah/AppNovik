import 'package:app_novik/core/errors/failures.dart';
import 'package:app_novik/core/utils/either.dart';
import 'package:app_novik/data/datasources/theme_local_datasource.dart';
import 'package:app_novik/domain/entities/company_entity.dart';
import 'package:app_novik/domain/entities/module_entity.dart';
import 'package:app_novik/domain/entities/saved_credentials_entity.dart';
import 'package:app_novik/domain/entities/session_context_entity.dart';
import 'package:app_novik/domain/entities/user_entity.dart';
import 'package:app_novik/domain/repositories/auth_repository.dart';
import 'package:app_novik/domain/usecases/auth_usecases.dart';
import 'package:app_novik/presentation/pages/login_page.dart';
import 'package:app_novik/presentation/pages/main_shell_page.dart';
import 'package:app_novik/presentation/providers/auth_provider.dart';
import 'package:app_novik/presentation/providers/shell_navigation.dart';
import 'package:app_novik/presentation/providers/theme_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'support/screen_look.dart';

/// Pantallas completas del acceso y del menú, en modo claro y oscuro, con letra 1.3x y a 360 y
/// 320 px: sin desbordes y con el contraste de texto suficiente.

class _FakeThemeStorage implements ThemeLocalDataSource {
  @override
  Future<ThemeMode?> read() async => null;

  @override
  Future<void> write(ThemeMode mode) async {}
}

class _FakeAuthRepository implements AuthRepository {
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
  Future<Either<Failure, void>> saveCredentials(String usuario, String password) async =>
      Either.rightVoid();

  @override
  Future<Either<Failure, void>> clearSavedCredentials() async => Either.rightVoid();
}

AuthProvider _auth({List<String> modules = const [], AuthStatus? status, String? error}) {
  final repo = _FakeAuthRepository();
  final auth = AuthProvider(
    loginUseCase: LoginUseCase(repository: repo),
    logoutUseCase: LogoutUseCase(repository: repo),
    getSessionContextUseCase: GetSessionContextUseCase(repository: repo),
    getSavedCredentialsUseCase: GetSavedCredentialsUseCase(repository: repo),
    saveCredentialsUseCase: SaveCredentialsUseCase(repository: repo),
    clearSavedCredentialsUseCase: ClearSavedCredentialsUseCase(repository: repo),
  );
  if (modules.isNotEmpty) {
    auth.session = SessionContextEntity(
      user: const UserEntity(id: 9, name: 'Ana', usuario: 'ana'),
      company: const CompanyEntity(id: 7, razonSocial: 'ACME', igv: 0.18, renta: 0.015),
      modules: [for (var i = 0; i < modules.length; i++) ModuleEntity(id: i + 1, name: modules[i])],
      permissions: const {},
      roles: const [],
      warehouses: const [],
    );
  }
  if (status != null) auth.status = status;
  auth.errorMessage = error;
  return auth;
}

Future<void> _pump(
  WidgetTester tester,
  ScreenLook look,
  Widget home, {
  required AuthProvider auth,
}) async {
  await prepareLook(tester, look);
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthProvider>.value(value: auth),
        ChangeNotifierProvider<ShellNavigation>.value(value: ShellNavigation()),
        ChangeNotifierProvider<ThemeProvider>(create: (_) => ThemeProvider(storage: _FakeThemeStorage())),
      ],
      child: lookApp(look, home: home),
    ),
  );
  await tester.pumpAndSettle();
}

const _modulos = ['Ventas', 'Reportes', 'Stock', 'Documentos', 'Productos'];

void main() {
  group('Inicio de sesión', () {
    for (final look in screenLooks) {
      testWidgets('formulario: ${look.label}', (tester) async {
        final handle = tester.ensureSemantics();
        await _pump(tester, look, const LoginPage(), auth: _auth());

        expect(find.text('Iniciar sesión'), findsOneWidget);
        await expectLooksRight(tester, look);
        handle.dispose();
      });

      testWidgets('con un error de acceso: ${look.label}', (tester) async {
        final handle = tester.ensureSemantics();
        await _pump(
          tester,
          look,
          const LoginPage(),
          auth: _auth(status: AuthStatus.error, error: 'Usuario o contraseña incorrectos. Revisa tus datos.'),
        );

        expect(find.textContaining('incorrectos'), findsOneWidget);
        await expectLooksRight(tester, look);
        handle.dispose();
      });
    }

    testWidgets('en una pantalla de tablet (login en tarjeta) también se lee en modo oscuro', (tester) async {
      final handle = tester.ensureSemantics();
      const look = ScreenLook(dark: true, size: Size(900, 700));
      await _pump(tester, look, const LoginPage(), auth: _auth());

      await expectLooksRight(tester, look);
      handle.dispose();
    });
  });

  group('Menú "Más"', () {
    for (final look in screenLooks) {
      testWidgets('cuadrícula de módulos: ${look.label}', (tester) async {
        final handle = tester.ensureSemantics();
        await _pump(
          tester,
          look,
          MainShellPage(pageBuilder: (slug) => Center(child: Text('pantalla $slug'))),
          auth: _auth(modules: _modulos),
        );
        await tester.tap(find.descendant(of: find.byType(NavigationBar), matching: find.text('Más')));
        await tester.pumpAndSettle();

        expect(find.byType(GridView), findsOneWidget);
        expect(find.text('Documentos'), findsOneWidget);
        await expectLooksRight(tester, look);
        handle.dispose();
      });

      testWidgets('barra inferior con "Más": ${look.label}', (tester) async {
        final handle = tester.ensureSemantics();
        await _pump(
          tester,
          look,
          MainShellPage(pageBuilder: (slug) => Center(child: Text('pantalla $slug'))),
          auth: _auth(modules: _modulos),
        );

        expect(find.byType(NavigationBar), findsOneWidget);
        await expectLooksRight(tester, look);
        handle.dispose();
      });
    }
  });
}
