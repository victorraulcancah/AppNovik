import 'package:app_novik/core/errors/failures.dart';
import 'package:app_novik/core/utils/either.dart';
import 'package:app_novik/core/utils/format.dart';
import 'package:app_novik/data/datasources/theme_local_datasource.dart';
import 'package:app_novik/data/models/report_model.dart';
import 'package:app_novik/domain/entities/company_entity.dart';
import 'package:app_novik/domain/entities/report_entity.dart';
import 'package:app_novik/domain/entities/saved_credentials_entity.dart';
import 'package:app_novik/domain/entities/session_context_entity.dart';
import 'package:app_novik/domain/entities/user_entity.dart';
import 'package:app_novik/domain/repositories/auth_repository.dart';
import 'package:app_novik/domain/repositories/report_repository.dart';
import 'package:app_novik/domain/usecases/auth_usecases.dart';
import 'package:app_novik/domain/usecases/report_usecases.dart';
import 'package:app_novik/presentation/pages/reports_page.dart';
import 'package:app_novik/presentation/providers/auth_provider.dart';
import 'package:app_novik/presentation/providers/reports_provider.dart';
import 'package:app_novik/presentation/providers/theme_provider.dart';
import 'package:app_novik/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

/// Forma de `GET /ventas/resumen-ejecutivo` (con bloques que la app ignora).
Map<String, dynamic> _json({bool conMeta = true}) => {
      'success': true,
      'vendedor': 'ANA PÉREZ',
      'desde': '2026-10-01',
      'hasta': '2026-10-27',
      'desde_anterior': '2025-10-01',
      'hasta_anterior': '2025-10-27',
      'ventas': {
        'total': 12500.5,
        'total_anterior': 10000,
        'variacion_pct': 25.0,
        'numero': 40,
        'numero_anterior': 50,
        'numero_variacion_pct': -20.0,
        'ticket': 312.51,
        'ticket_anterior': 200,
        'ticket_variacion_pct': null,
      },
      'por_almacen': [
        {'id': 1, 'nombre': 'LIMA', 'monto': 9000},
        {'id': 2, 'nombre': 'AREQUIPA', 'monto': '3500.50'},
      ],
      'meta': conMeta
          ? {
              'aplica': true,
              'anio': 2026,
              'mes': 10,
              'monto': 20000,
              'venta': 12500.5,
              'falta': 7499.5,
              'avance': 62.5,
              'semaforo': 'ambar',
            }
          : {'aplica': false, 'monto': 0, 'venta': 0, 'falta': 0, 'avance': null, 'semaforo': 'gris'},
      'cotizaciones': {'cantidad': 2, 'monto': 900},
      'cotizaciones_lista': [
        {'id': 5, 'documento': 12, 'cliente': 'ACME SAC', 'monto': 600, 'dias': 9, 'prioridad': 'alta'},
        {'id': 6, 'documento': '13', 'cliente': 'BETA EIRL', 'monto': 300, 'dias': 1, 'prioridad': 'baja'},
      ],
      'evolucion': {
        'anio_actual': 2026,
        'anio_anterior': 2025,
        'meses': [
          {'mes': 1, 'anterior': 100, 'actual': 150},
          {'mes': 10, 'anterior': 10000, 'actual': 12500.5},
        ],
      },
      'top_productos': [
        {'id': 1, 'codigo': 'SUB-12', 'nombre': 'SUBWOOFER 12"', 'monto': 5000},
      ],
      'top_clientes': [
        {'id': 7, 'nombre': ' ACME SAC ', 'monto': 4000},
      ],
      'departamentos': [
        {'id': null, 'nombre': '', 'monto': 100},
      ],
      // Bloques que la app no usa:
      'tareas': [],
      'cumpleanos': [],
      'atencion': {'con_caida': {'total': 0, 'filas': []}},
    };

class _FakeReportRepository implements ReportRepository {
  final List<({DateTime desde, DateTime hasta})> calls = [];
  Either<Failure, ExecutiveSummaryEntity>? result;

  @override
  Future<Either<Failure, ExecutiveSummaryEntity>> getExecutiveSummary({
    required DateTime desde,
    required DateTime hasta,
  }) async {
    calls.add((desde: desde, hasta: hasta));
    return result ?? Either.right(executiveSummaryFromJson(_json()));
  }
}

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

SessionContextEntity _session({int companyId = 1, Set<String> permissions = const {'reportes.index'}}) =>
    SessionContextEntity(
      user: const UserEntity(id: 9, name: 'Ana', usuario: 'ana'),
      company: CompanyEntity(id: companyId, razonSocial: 'ACME'),
      modules: const [],
      permissions: permissions,
      roles: const [],
      warehouses: const [],
    );

AuthProvider _auth(SessionContextEntity session) {
  final repo = _FakeAuthRepository();
  return AuthProvider(
    loginUseCase: LoginUseCase(repository: repo),
    logoutUseCase: LogoutUseCase(repository: repo),
    getSessionContextUseCase: GetSessionContextUseCase(repository: repo),
    getSavedCredentialsUseCase: GetSavedCredentialsUseCase(repository: repo),
    saveCredentialsUseCase: SaveCredentialsUseCase(repository: repo),
    clearSavedCredentialsUseCase: ClearSavedCredentialsUseCase(repository: repo),
  )..session = session;
}

ReportsProvider _provider(_FakeReportRepository repo, {DateTime? now}) => ReportsProvider(
      getExecutiveSummaryUseCase: GetExecutiveSummaryUseCase(repository: repo),
      now: () => now ?? DateTime(2026, 10, 27, 15, 30),
    );

/// Las pruebas dibujan con la fuente Ahem (casi el doble de ancha que una real);
/// el factor de texto la acerca al ancho real para detectar desbordes reales.
void _phoneScreen(WidgetTester tester) {
  tester.view.physicalSize = const Size(360 * 3, 780 * 3);
  tester.view.devicePixelRatio = 3;
  tester.platformDispatcher.textScaleFactorTestValue = 0.55;
  addTearDown(() {
    tester.view.reset();
    tester.platformDispatcher.clearTextScaleFactorTestValue();
  });
}

void main() {
  group('executiveSummaryFromJson', () {
    test('lee ventas, meta, cotizaciones, evolución y rankings', () {
      final s = executiveSummaryFromJson(_json());

      expect(s.vendedor, 'ANA PÉREZ');
      expect(s.desde, DateTime(2026, 10, 1));
      expect(s.hastaAnterior, DateTime(2025, 10, 27));
      expect(s.unSoloMes, isTrue);

      expect(s.ventas.total, 12500.5);
      expect(s.ventas.totalVariacion, 25.0);
      expect(s.ventas.numero, 40);
      expect(s.ventas.numeroVariacion, -20.0);
      expect(s.ventas.ticketVariacion, isNull);

      expect(s.porAlmacen.map((a) => a.nombre), ['LIMA', 'AREQUIPA']);
      expect(s.porAlmacen.last.monto, 3500.5);

      expect(s.meta.conMeta, isTrue);
      expect(s.meta.avance, 62.5);
      expect(s.meta.semaforo, GoalLight.ambar);

      expect(s.cotizacionesCantidad, 2);
      expect(s.cotizaciones.first.prioridad, QuotePriority.alta);
      expect(s.cotizaciones.last.documento, '13');

      expect(s.evolucion.anioAnterior, 2025);
      expect(s.evolucion.meses.last.actual, 12500.5);

      expect(s.topProductos.single.codigo, 'SUB-12');
      expect(s.topClientes.single.nombre, 'ACME SAC');
      expect(s.departamentos.single.nombre, 'Sin nombre');
    });

    test('sin meta del mes no hay barra de avance', () {
      final s = executiveSummaryFromJson(_json(conMeta: false));
      expect(s.meta.conMeta, isFalse);
      expect(s.meta.aplica, isFalse);
      expect(s.meta.avance, isNull);
      expect(s.meta.semaforo, GoalLight.gris);
    });

    test('tolera una respuesta casi vacía', () {
      final s = executiveSummaryFromJson({'vendedor': 'X'});
      expect(s.ventas.total, 0);
      expect(s.topClientes, isEmpty);
      expect(s.cotizaciones, isEmpty);
      expect(s.evolucion.meses, isEmpty);
    });
  });

  group('formato', () {
    test('montos compactos para los ejes', () {
      expect(formatCompactMoney(0), 'S/ 0');
      expect(formatCompactMoney(80), 'S/ 80');
      expect(formatCompactMoney(500000), 'S/ 500K');
      expect(formatCompactMoney(1500000), 'S/ 1.5M');
    });
  });

  group('GetExecutiveSummaryUseCase', () {
    test('rechaza un rango invertido sin llamar a la API', () async {
      final repo = _FakeReportRepository();
      final result = await GetExecutiveSummaryUseCase(repository: repo)(
        desde: DateTime(2026, 10, 10),
        hasta: DateTime(2026, 10, 1),
      );
      expect(result.isLeft, isTrue);
      expect(repo.calls, isEmpty);
    });
  });

  group('ReportsProvider', () {
    test('arranca con el mes en curso hasta hoy', () async {
      final repo = _FakeReportRepository();
      final p = _provider(repo)..syncCompany(1);
      await p.ensureLoaded();

      expect(repo.calls.single.desde, DateTime(2026, 10, 1));
      expect(repo.calls.single.hasta, DateTime(2026, 10, 27));
      expect(p.summary!.ventas.total, 12500.5);
      expect(p.loading, isFalse);

      // No vuelve a pedir si ya cargó.
      await p.ensureLoaded();
      expect(repo.calls, hasLength(1));
    });

    test('cada rango calcula sus fechas', () {
      final p = _provider(_FakeReportRepository())..syncCompany(1);

      p.range = ReportRange.hoy;
      expect(p.dates.start, DateTime(2026, 10, 27));
      expect(p.dates.end, DateTime(2026, 10, 27));

      p.range = ReportRange.mesPasado;
      expect(p.dates.start, DateTime(2026, 9, 1));
      expect(p.dates.end, DateTime(2026, 9, 30));

      p.range = ReportRange.esteAnio;
      expect(p.dates.start, DateTime(2026, 1, 1));
      expect(p.dates.end, DateTime(2026, 10, 27));
    });

    test('el mes pasado de enero es diciembre del año anterior', () {
      final p = _provider(_FakeReportRepository(), now: DateTime(2026, 1, 15))..syncCompany(1);
      p.range = ReportRange.mesPasado;
      expect(p.dates.start, DateTime(2025, 12, 1));
      expect(p.dates.end, DateTime(2025, 12, 31));
    });

    test('elegir un rango vuelve a pedir el resumen', () async {
      final repo = _FakeReportRepository();
      final p = _provider(repo)..syncCompany(1);
      await p.ensureLoaded();

      await p.selectRange(ReportRange.mesPasado);
      expect(repo.calls.last.desde, DateTime(2026, 9, 1));

      await p.selectCustom(DateTimeRange(start: DateTime(2026, 3, 5), end: DateTime(2026, 3, 20)));
      expect(p.range, ReportRange.personalizado);
      expect(repo.calls.last.desde, DateTime(2026, 3, 5));
      expect(repo.calls.last.hasta, DateTime(2026, 3, 20));
    });

    test('si falla deja el error y sin resumen', () async {
      final repo = _FakeReportRepository()
        ..result = Either.left(const ServerFailure('No tienes permiso para esta acción'));
      final p = _provider(repo)..syncCompany(1);
      await p.ensureLoaded();

      expect(p.summary, isNull);
      expect(p.error, 'No tienes permiso para esta acción');
    });

    test('al cambiar de empresa descarta el resumen y vuelve al mes en curso', () async {
      final p = _provider(_FakeReportRepository())..syncCompany(1);
      await p.ensureLoaded();
      await p.selectRange(ReportRange.esteAnio);

      p.syncCompany(2);
      expect(p.summary, isNull);
      expect(p.range, ReportRange.esteMes);
      await p.ensureLoaded();
      expect(p.summary, isNotNull);
    });
  });

  group('ReportsPage', () {
    Future<_FakeReportRepository> pump(
      WidgetTester tester, {
      SessionContextEntity? session,
      _FakeReportRepository? repo,
    }) async {
      _phoneScreen(tester);
      final fake = repo ?? _FakeReportRepository();
      final s = session ?? _session();
      final reports = _provider(fake)..syncCompany(s.company.id);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<ThemeProvider>(
              create: (_) => ThemeProvider(storage: _FakeThemeStorage()),
            ),
            ChangeNotifierProvider<AuthProvider>.value(value: _auth(s)),
            ChangeNotifierProvider<ReportsProvider>.value(value: reports),
          ],
          child: MaterialApp(
            theme: AppTheme.light,
            home: const Scaffold(body: ReportsPage()),
          ),
        ),
      );
      await tester.pumpAndSettle();
      return fake;
    }

    testWidgets('muestra el resumen con ventas, meta, evolución y rankings', (tester) async {
      await pump(tester);

      expect(find.text('Este mes'), findsOneWidget);
      expect(find.text('S/ 12,500.50'), findsWidgets);
      expect(find.text('+25.0 % ↑'), findsOneWidget);
      expect(find.text('-20.0 % ↓'), findsOneWidget);
      expect(find.text('Meta del mes: S/ 20,000.00'), findsOneWidget);
      expect(find.text('62.5 %'), findsOneWidget);
      expect(find.text('Faltan S/ 7,499.50'), findsOneWidget);
      expect(find.text('Evolución de mis ventas'), findsOneWidget);

      // Los rankings y las cotizaciones quedan más abajo.
      await tester.scrollUntilVisible(
        find.text('Cotizaciones pendientes'),
        300,
        scrollable: find.descendant(
          of: find.byType(RefreshIndicator),
          matching: find.byType(Scrollable),
        ),
      );
      expect(find.text('ACME SAC'), findsWidgets);
      expect(find.text('C001-0012 · 9 días'), findsOneWidget);
      expect(find.text('Alta'), findsOneWidget);
    });

    testWidgets('cambiar de rango pide el resumen de ese rango', (tester) async {
      final repo = await pump(tester);
      expect(repo.calls, hasLength(1));

      await tester.tap(find.text('Mes pasado'));
      await tester.pumpAndSettle();
      expect(repo.calls, hasLength(2));
      expect(repo.calls.last.desde, DateTime(2026, 9, 1));
      expect(repo.calls.last.hasta, DateTime(2026, 9, 30));
    });

    testWidgets('si el servidor rechaza el reporte muestra el error y deja reintentar', (tester) async {
      final repo = _FakeReportRepository()
        ..result = Either.left(const ServerFailure('No tienes permiso para esta acción'));
      await pump(tester, repo: repo);

      expect(find.text('No se pudo cargar el reporte'), findsOneWidget);
      expect(find.text('No tienes permiso para esta acción'), findsOneWidget);
      expect(find.text('Reintentar'), findsOneWidget);
    });

    testWidgets('sin permiso reportes.index no pide nada', (tester) async {
      final repo = await pump(tester, session: _session(permissions: const {}));

      expect(find.text('Sin acceso'), findsOneWidget);
      expect(find.text('Este mes'), findsNothing);
      expect(repo.calls, isEmpty);
    });
  });
}
