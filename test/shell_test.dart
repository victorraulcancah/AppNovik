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
import 'package:app_novik/presentation/pages/main_shell_page.dart';
import 'package:app_novik/presentation/providers/auth_provider.dart';
import 'package:app_novik/presentation/providers/shell_navigation.dart';
import 'package:app_novik/presentation/providers/theme_provider.dart';
import 'package:app_novik/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

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

AuthProvider _auth(List<String> modules, {Set<String> permissions = const {}}) {
  final repo = _FakeAuthRepository();
  return AuthProvider(
    loginUseCase: LoginUseCase(repository: repo),
    logoutUseCase: LogoutUseCase(repository: repo),
    getSessionContextUseCase: GetSessionContextUseCase(repository: repo),
    getSavedCredentialsUseCase: GetSavedCredentialsUseCase(repository: repo),
    saveCredentialsUseCase: SaveCredentialsUseCase(repository: repo),
    clearSavedCredentialsUseCase: ClearSavedCredentialsUseCase(repository: repo),
  )..session = SessionContextEntity(
      user: const UserEntity(id: 9, name: 'Ana', usuario: 'ana'),
      company: const CompanyEntity(id: 7, razonSocial: 'ACME', igv: 0.18, renta: 0.015),
      modules: [
        for (var i = 0; i < modules.length; i++) ModuleEntity(id: i + 1, name: modules[i]),
      ],
      permissions: permissions,
      roles: const [],
      warehouses: const [],
    );
}

Future<ShellNavigation> _pump(
  WidgetTester tester,
  List<String> modules, {
  Size size = const Size(400, 800),
  Set<String> permissions = const {},
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final navigation = ShellNavigation();
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthProvider>.value(value: _auth(modules, permissions: permissions)),
        ChangeNotifierProvider<ShellNavigation>.value(value: navigation),
        ChangeNotifierProvider<ThemeProvider>(
          create: (_) => ThemeProvider(storage: _FakeThemeStorage()),
        ),
      ],
      child: MaterialApp(
        theme: AppTheme.light,
        home: MainShellPage(pageBuilder: (slug) => Center(child: Text('pantalla $slug'))),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return navigation;
}

const _todos = ['Ventas', 'Reportes', 'Stock', 'Documentos', 'Productos', 'Clientes'];

void main() {
  testWidgets('Inicio siempre aparece primero, aunque la empresa no tenga módulos', (tester) async {
    await _pump(tester, const []);
    expect(find.text('pantalla inicio'), findsOneWidget);
  });

  testWidgets('con cinco módulos o menos la barra los muestra todos, sin "Más"', (tester) async {
    await _pump(tester, const ['Ventas', 'Stock', 'Productos', 'Documentos']);
    for (final t in ['Inicio', 'Ventas', 'Stock', 'Productos', 'Documentos']) {
      expect(find.descendant(of: find.byType(NavigationBar), matching: find.text(t)), findsOneWidget);
    }
    expect(find.text('Más'), findsNothing);
  });

  testWidgets('con más de cinco, la barra muestra cuatro y "Más" con el resto', (tester) async {
    await _pump(tester, _todos);
    final bar = find.byType(NavigationBar);
    for (final t in ['Inicio', 'Ventas', 'Reportes', 'Stock', 'Más']) {
      expect(find.descendant(of: bar, matching: find.text(t)), findsOneWidget);
    }
    expect(find.descendant(of: bar, matching: find.text('Documentos')), findsNothing);
    expect(tester.widget<NavigationBar>(bar).destinations.length, 5);
  });

  testWidgets('"Más" lista los módulos restantes y al tocar uno lo abre', (tester) async {
    await _pump(tester, _todos);
    await tester.tap(find.descendant(of: find.byType(NavigationBar), matching: find.text('Más')));
    await tester.pumpAndSettle();

    // Los módulos restantes salen como cuadrícula de íconos.
    expect(find.byType(GridView), findsOneWidget);
    expect(find.byIcon(Icons.description_outlined), findsOneWidget);
    expect(find.text('Documentos'), findsOneWidget);
    expect(find.text('Productos'), findsOneWidget);
    expect(find.text('Clientes'), findsOneWidget);
    expect(find.text('pantalla inicio'), findsNothing);

    await tester.tap(find.text('Productos'));
    await tester.pumpAndSettle();
    expect(find.text('pantalla productos'), findsOneWidget);
    // Sigue marcado "Más" porque Productos no cabe en la barra.
    final bar = tester.widget<NavigationBar>(find.byType(NavigationBar));
    expect(bar.selectedIndex, 4);
  });

  testWidgets('volver a un módulo de la barra sale de "Más"', (tester) async {
    await _pump(tester, _todos);
    final bar = find.byType(NavigationBar);
    await tester.tap(find.descendant(of: bar, matching: find.text('Más')));
    await tester.pumpAndSettle();
    await tester.tap(find.descendant(of: bar, matching: find.text('Ventas')));
    await tester.pumpAndSettle();
    expect(find.text('pantalla ventas'), findsOneWidget);
    expect(tester.widget<NavigationBar>(bar).selectedIndex, 1);
  });

  testWidgets('un pedido de navegación a un módulo guardado en "Más" lo abre', (tester) async {
    final navigation = await _pump(tester, _todos);
    navigation.goTo('documentos');
    await tester.pumpAndSettle();
    expect(find.text('pantalla documentos'), findsOneWidget);
  });

  testWidgets('en tablet el riel lateral muestra todos los módulos, sin "Más"', (tester) async {
    await _pump(tester, _todos, size: const Size(1100, 800));
    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
    for (final t in ['Inicio', 'Ventas', 'Reportes', 'Stock', 'Documentos', 'Productos', 'Clientes']) {
      expect(find.descendant(of: find.byType(NavigationRail), matching: find.text(t)), findsOneWidget);
    }
    expect(find.text('Más'), findsNothing);
  });

  testWidgets('Clientes, Deudas y Estado de cuenta aparecen cuando la empresa los tiene', (tester) async {
    await _pump(tester, const ['Ventas', 'Clientes', 'Pagos', 'Estado de Cuenta'], size: const Size(1100, 800));
    for (final t in ['Ventas', 'Clientes', 'Deudas', 'Estado de cuenta']) {
      expect(find.descendant(of: find.byType(NavigationRail), matching: find.text(t)), findsOneWidget);
    }
  });

  testWidgets('el vendedor que solo puede ver stock (stock.show) tiene Stock aunque no tenga el módulo', (tester) async {
    await _pump(tester, const ['Ventas', 'Clientes'], size: const Size(1100, 800), permissions: const {'stock.show'});
    expect(find.descendant(of: find.byType(NavigationRail), matching: find.text('Stock')), findsOneWidget);
  });

  testWidgets('sin el módulo ni stock.show, Stock no aparece', (tester) async {
    await _pump(tester, const ['Ventas', 'Clientes'], size: const Size(1100, 800));
    expect(find.text('Stock'), findsNothing);
  });

  testWidgets('sin el módulo, Deudas y Estado de cuenta no aparecen', (tester) async {
    await _pump(tester, const ['Ventas', 'Clientes'], size: const Size(1100, 800));
    expect(find.text('Deudas'), findsNothing);
    expect(find.text('Estado de cuenta'), findsNothing);
  });
}
