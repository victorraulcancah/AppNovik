import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:app_novik/core/errors/failures.dart';
import 'package:app_novik/core/utils/either.dart';
import 'package:app_novik/data/datasources/report_remote_datasource.dart';
import 'package:app_novik/data/datasources/theme_local_datasource.dart';
import 'package:app_novik/data/models/report_ranking_model.dart';
import 'package:app_novik/domain/entities/company_entity.dart';
import 'package:app_novik/domain/entities/document_entity.dart';
import 'package:app_novik/domain/entities/report_entity.dart';
import 'package:app_novik/domain/entities/report_ranking_entity.dart';
import 'package:app_novik/domain/entities/saved_credentials_entity.dart';
import 'package:app_novik/domain/entities/session_context_entity.dart';
import 'package:app_novik/domain/entities/user_entity.dart';
import 'package:app_novik/domain/repositories/auth_repository.dart';
import 'package:app_novik/domain/repositories/report_repository.dart';
import 'package:app_novik/domain/usecases/auth_usecases.dart';
import 'package:app_novik/domain/usecases/report_usecases.dart';
import 'package:app_novik/presentation/components/components.dart' show AppListCard;
import 'package:app_novik/presentation/pages/reports_page.dart';
import 'package:app_novik/presentation/providers/auth_provider.dart';
import 'package:app_novik/presentation/providers/reports_provider.dart';
import 'package:app_novik/presentation/providers/theme_provider.dart';
import 'package:app_novik/presentation/widgets/report_rankings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';

import 'support/screen_look.dart';

// ---------------------------------------------------------------- datos de ejemplo

/// Forma de `GET /ventas/reporte-marcas-v2` (y de los demás reportes por entidad, con otro nombre).
Map<String, dynamic> _json({
  String nameKey = 'marca',
  bool hasMore = false,
  int total = 4,
  double totalVentas = 1000,
}) => {
  'success': true,
  'data': [
    for (final (i, e) in [('7POWER', 600), ('PIONEER', 300), ('JBL', 90), ('KICKER', 10)].indexed)
      {
        'id': i + 1,
        nameKey: e.$1,
        'n_de_ventas': 5,
        'cantidad': 100,
        'subtotal': e.$2,
        'venta_total': e.$2,
        'margen': 50,
      },
  ],
  'resumen': {'total_ventas': totalVentas, 'unidades_vendidas': 210},
  'pagination': {'current_page': 1, 'per_page': 100, 'total': total, 'last_page': 1, 'has_more': hasMore},
};

RankingReport _report(List<(String, double)> rows, {bool hasMore = false, double? total}) => RankingReport(
  rows: [for (final (i, r) in rows.indexed) RankingRow(id: i + 1, name: r.$1, venta: r.$2, nVentas: 5, subtotal: r.$2, margen: 50)],
  total: total ?? rows.fold<double>(0, (s, r) => s + r.$2),
  totalRows: rows.length,
  hasMore: hasMore,
);

final _marcas = _report([('7POWER', 600), ('PIONEER', 300), ('JBL', 90), ('KICKER', 10)]);

SalesReportEntity _general() => const SalesReportEntity(
  days: [SalesReportDayEntity(name: '31-Octubre', ventasSoles: 100)],
  products: [SalesReportProductEntity(id: 10, name: 'SUBWOOFER 12"', codigo: 'SUB-12', venta: 290, cantidad: 6, subtotal: 300)],
  totalProducts: 1,
  countVentas: 2,
  unidades: 8,
  totalVentas: 330.5,
  totalCostos: 100,
);

// ---------------------------------------------------------------- repositorio falso

typedef _Call = ({ReportKind kind, SalesReportFilters filters, int page, String? search});

class _FakeRepo implements ReportRepository {
  final List<_Call> calls = [];
  int generalCalls = 0;
  final Map<ReportKind, RankingReport> rankings = {
    ReportKind.departamentos: _report([('LIMA', 700), ('AREQUIPA', 300)]),
    ReportKind.vendedores: _report([('GUSTAVO MIRANDA PUN', 500), ('YOSELIN M', 500)]),
    ReportKind.marcas: _marcas,
    ReportKind.categorias: _report([('AMPLIFICADORES', 800), ('PARLANTES', 200)]),
    ReportKind.clientes: _report([('ACME SAC', 900), ('PERÚ SAC', 100)]),
  };
  final Set<ReportKind> failing = {};
  Completer<void>? gate;
  RankingReport? searchResult;
  RankingReport? page2;

  @override
  Future<Either<Failure, RankingReport>> getRanking({
    required ReportKind kind,
    required SalesReportFilters filters,
    required int companyId,
    int page = 1,
    int pageSize = 100,
    String? search,
  }) async {
    calls.add((kind: kind, filters: filters, page: page, search: search));
    final g = gate;
    if (g != null) await g.future;
    if (failing.contains(kind)) return Either.left(const NetworkFailure('Sin conexión a internet'));
    if (search != null && searchResult != null) return Either.right(searchResult!);
    if (page > 1 && page2 != null) return Either.right(page2!);
    return Either.right(rankings[kind] ?? const RankingReport());
  }

  @override
  Future<Either<Failure, SalesReportEntity>> getSalesReport({
    required SalesReportFilters filters,
    int page = 1,
    int pageSize = 15,
    String? sortField,
    bool sortDescending = true,
  }) async {
    generalCalls++;
    return Either.right(_general());
  }

  @override
  Future<Either<Failure, DownloadedFile>> exportSalesReport(SalesReportFilters filters) async =>
      Either.right(DownloadedFile(name: 'x.xlsx', bytes: Uint8List(1)));

  @override
  Future<Either<Failure, SalesReportCatalogs>> getCatalogs({
    required int companyId,
    required int userId,
    required bool soloMiCartera,
  }) async => Either.right(const SalesReportCatalogs());

  @override
  Future<Either<Failure, DocumentEntity>> getSale(int id) async =>
      Either.left(const ValidationFailure('sin venta'));
}

ReportsProvider _provider(_FakeRepo repo, {SessionContextEntity? session}) => ReportsProvider(
  getSalesReportUseCase: GetSalesReportUseCase(repository: repo),
  exportSalesReportUseCase: ExportSalesReportUseCase(repository: repo),
  getCatalogsUseCase: GetReportCatalogsUseCase(repository: repo),
  getSaleUseCase: GetReportSaleUseCase(repository: repo),
  getRankingUseCase: GetRankingReportUseCase(repository: repo),
  now: () => DateTime(2026, 10, 31, 10),
)..syncSession(session ?? _session());

const _allPermissions = {
  'reportes.index',
  'reportes.ventas.index',
  'reportes.sucursal.index',
  'reportes.vendedor.index',
  'reportes.marcas.index',
  'reportes.categorias.index',
  'reportes.cliente_comparativa.index',
};

SessionContextEntity _session({
  Set<String> permissions = _allPermissions,
  List<String> roles = const ['Ceo Empresa'],
  int companyId = 7,
}) => SessionContextEntity(
  user: const UserEntity(id: 9, name: 'Ana', usuario: 'ana'),
  company: CompanyEntity(id: companyId, razonSocial: 'ACME', igv: 0.18, renta: 0.015),
  modules: const [],
  permissions: permissions,
  roles: roles,
  warehouses: const [],
);

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
  Future<Either<Failure, void>> saveCredentials(String usuario, String password) async => Either.rightVoid();

  @override
  Future<Either<Failure, void>> clearSavedCredentials() async => Either.rightVoid();
}

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

/// Deja que corran los pedidos en cadena (las tarjetas se piden una tras otra).
Future<void> _settle() async {
  for (var i = 0; i < 20; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('rankingFromJson', () {
    test('lee el nombre según el reporte, la venta, el total y la paginación', () {
      final marcas = rankingFromJson(ReportKind.marcas, _json());
      expect(marcas.rows.map((r) => r.name), ['7POWER', 'PIONEER', 'JBL', 'KICKER']);
      expect(marcas.rows.first.venta, 600);
      expect(marcas.rows.first.id, 1);
      expect(marcas.total, 1000);
      expect(marcas.totalRows, 4);
      expect(marcas.hasMore, isFalse);

      expect(rankingFromJson(ReportKind.categorias, _json(nameKey: 'categoria')).rows.first.name, '7POWER');
      expect(rankingFromJson(ReportKind.departamentos, _json(nameKey: 'departamento')).rows.first.name, '7POWER');
      expect(rankingFromJson(ReportKind.clientes, _json(nameKey: 'cliente')).rows.first.name, '7POWER');
      // `reporte-vendedores-v2` trae el usuario con `name`.
      expect(rankingFromJson(ReportKind.vendedores, _json(nameKey: 'name')).rows.first.name, '7POWER');
    });

    test('un nombre que no viene queda como "-" y la venta en texto se lee', () {
      final r = rankingFromJson(ReportKind.marcas, {
        'data': [
          {'id': 1, 'venta_total': '12.5'},
          {'id': 2, 'marca': '  ', 'venta_total': 3},
        ],
      });
      expect(r.rows.map((e) => e.name), ['-', '-']);
      expect(r.rows.first.venta, 12.5);
    });

    test('sin ventas el servidor responde solo `data: []`: queda vacío y sin dividir por cero', () {
      final r = rankingFromJson(ReportKind.marcas, {'success': true, 'data': [], 'message': 'ok'});
      expect(r.rows, isEmpty);
      expect(r.total, 0);
      expect(r.hasMore, isFalse);
      expect(r.share(const RankingRow(name: 'x', venta: 5)), 0);
    });

    test('sin `resumen` el total sale de sumar las filas; una respuesta rara no rompe', () {
      final r = rankingFromJson(ReportKind.marcas, {
        'data': [
          {'marca': 'A', 'venta_total': 30},
          {'marca': 'B', 'venta_total': 70},
        ],
      });
      expect(r.total, 100);
      expect(r.share(r.rows.last), 70);
      expect(rankingFromJson(ReportKind.marcas, null).rows, isEmpty);
      expect(rankingFromJson(ReportKind.marcas, [1, 2]).rows, isEmpty);
    });

    test('el % de cada fila es sobre el total del rango', () {
      final r = rankingFromJson(ReportKind.marcas, _json());
      expect(r.share(r.rows[0]), 60);
      expect(r.share(r.rows[3]), 1);
    });

    test('hay más páginas cuando el servidor lo dice', () {
      expect(rankingFromJson(ReportKind.clientes, _json(hasMore: true, total: 250)).hasMore, isTrue);
      expect(rankingFromJson(ReportKind.clientes, _json(hasMore: true, total: 250)).totalRows, 250);
    });
  });

  group('rankingPercent', () {
    test('un decimal, y "<0.1 %" para lo que es poco pero no cero', () {
      expect(rankingPercent(60), '60.0 %');
      expect(rankingPercent(12.345), '12.3 %');
      expect(rankingPercent(0.02), '<0.1 %');
      expect(rankingPercent(0), '0.0 %');
    });
  });

  group('ReportRemoteDataSource.getRanking', () {
    Future<Uri> request(ReportKind kind, SalesReportFilters filters, {String? search, int page = 1}) async {
      late Uri uri;
      final dataSource = ReportRemoteDataSourceImpl(
        client: MockClient((r) async {
          uri = r.url;
          return http.Response(jsonEncode(_json()), 200);
        }),
      );
      final result = await dataSource.getRanking(
        token: 't',
        kind: kind,
        filters: filters,
        companyId: 7,
        page: page,
        pageSize: 100,
        search: search,
      );
      expect(result.rows, isNotEmpty);
      return uri;
    }

    final filters = SalesReportFilters(desde: DateTime(2026, 10), hasta: DateTime(2026, 10, 31));

    test('cada reporte pide su endpoint con el rango, la empresa y la página', () async {
      final expected = {
        ReportKind.departamentos: '/ventas/reporte-departamentos-v2',
        ReportKind.vendedores: '/ventas/reporte-vendedores-v2',
        ReportKind.marcas: '/ventas/reporte-marcas-v2',
        ReportKind.categorias: '/ventas/reporte-categorias-v2',
        ReportKind.clientes: '/ventas/reporte-clientes-v2',
      };
      for (final e in expected.entries) {
        final uri = await request(e.key, filters, page: 2);
        expect(uri.path, endsWith(e.value));
        expect(uri.queryParametersAll['fechas[]'], ['2026-10-01', '2026-10-31']);
        expect(uri.queryParameters['company_id'], '7');
        expect(uri.queryParameters['page'], '2');
        expect(uri.queryParameters['per_page'], '100');
        expect(uri.queryParameters.containsKey('cliente_search'), isFalse);
      }
    });

    test('los filtros avanzados van con los nombres de los reportes v2', () async {
      final uri = await request(
        ReportKind.marcas,
        filters.copyWith(
          sucursales: const ['1'],
          clientes: const ['5'],
          vendedores: const ['9', '10'],
          marcas: const ['3'],
          categorias: const ['4'],
          departamentos: const ['04'],
        ),
      );
      expect(uri.queryParametersAll['sucursales[]'], ['1']);
      expect(uri.queryParametersAll['clientes[]'], ['5']);
      expect(uri.queryParametersAll['vendedores[]'], ['9', '10']);
      expect(uri.queryParametersAll['marcas[]'], ['3']);
      expect(uri.queryParametersAll['tipos_producto[]'], ['4']);
      expect(uri.queryParametersAll['departamentos[]'], ['04']);
      expect(uri.queryParameters.containsKey('warehouse_id[]'), isFalse);
    });

    test('solo Clientes manda la búsqueda al servidor', () async {
      final clientes = await request(ReportKind.clientes, filters, search: '  acme ');
      expect(clientes.queryParameters['cliente_search'], 'acme');
      final marcas = await request(ReportKind.marcas, filters, search: 'acme');
      expect(marcas.queryParameters.containsKey('cliente_search'), isFalse);
    });
  });

  group('ReportKind', () {
    test('cada reporte lleva el permiso de su pestaña de la web', () {
      expect(ReportKind.general.permission, 'reportes.ventas.index');
      expect(ReportKind.departamentos.permission, 'reportes.sucursal.index');
      expect(ReportKind.vendedores.permission, 'reportes.vendedor.index');
      expect(ReportKind.marcas.permission, 'reportes.marcas.index');
      expect(ReportKind.categorias.permission, 'reportes.categorias.index');
      expect(ReportKind.clientes.permission, 'reportes.cliente_comparativa.index');
      expect(ReportKind.values.map((k) => k.chip), [
        'Venta general',
        'Departamentos',
        'Vendedor',
        'Marcas',
        'Categoría',
        'Cliente',
      ]);
    });
  });

  group('ReportsProvider: reportes por entidad', () {
    test('los reportes disponibles salen de los permisos', () {
      final all = _provider(_FakeRepo());
      expect(all.availableKinds, ReportKind.values);
      expect(all.dashboardKinds.length, 5);

      final onlyGeneral = _provider(
        _FakeRepo(),
        session: _session(permissions: const {'reportes.index', 'reportes.ventas.index'}),
      );
      expect(onlyGeneral.availableKinds, [ReportKind.general]);
      expect(onlyGeneral.dashboardKinds, isEmpty);

      final partial = _provider(
        _FakeRepo(),
        session: _session(permissions: const {'reportes.index', 'reportes.ventas.index', 'reportes.marcas.index'}),
      );
      expect(partial.availableKinds, [ReportKind.general, ReportKind.marcas]);

      // Sin `reportes.index` no hay ninguno.
      final none = _provider(_FakeRepo(), session: _session(permissions: const {'reportes.marcas.index'}));
      expect(none.availableKinds, isEmpty);
    });

    test('al cargar Venta general se piden las tarjetas, una tras otra, con los mismos filtros', () async {
      final repo = _FakeRepo();
      final p = _provider(repo);
      await p.ensureLoaded();
      await _settle();

      expect(repo.generalCalls, 1);
      expect(repo.calls.map((c) => c.kind), [
        ReportKind.departamentos,
        ReportKind.vendedores,
        ReportKind.marcas,
        ReportKind.categorias,
        ReportKind.clientes,
      ]);
      expect(repo.calls.every((c) => c.page == 1 && c.search == null), isTrue);
      expect(repo.calls.first.filters.desde, DateTime(2026, 10));
      expect(p.ranking(ReportKind.marcas)!.rows.length, 4);
      expect(p.ranking(ReportKind.marcas)!.share(p.ranking(ReportKind.marcas)!.rows.first), 60);
    });

    test('sin permiso de un reporte no se pide', () async {
      final repo = _FakeRepo();
      final p = _provider(
        repo,
        session: _session(permissions: const {'reportes.index', 'reportes.ventas.index', 'reportes.marcas.index'}),
      );
      await p.ensureLoaded();
      await _settle();

      expect(repo.calls.map((c) => c.kind), [ReportKind.marcas]);
      await p.selectKind(ReportKind.clientes); // sin permiso: no cambia
      expect(p.kind, ReportKind.general);
    });

    test('abrir un reporte reutiliza lo ya pedido y no vuelve a llamar', () async {
      final repo = _FakeRepo();
      final p = _provider(repo);
      await p.ensureLoaded();
      await _settle();
      final before = repo.calls.length;

      await p.selectKind(ReportKind.marcas);

      expect(p.kind, ReportKind.marcas);
      expect(repo.calls.length, before);
      expect(p.ranking(ReportKind.marcas)!.loaded, isTrue);
    });

    test('cambiar el rango descarta lo pedido y vuelve a pedir el reporte abierto', () async {
      final repo = _FakeRepo();
      final p = _provider(repo);
      await p.ensureLoaded();
      await _settle();
      await p.selectKind(ReportKind.marcas);
      repo.calls.clear();

      await p.selectRange(ReportRange.ultimoAnio);
      await _settle();

      expect(repo.calls.single.kind, ReportKind.marcas);
      expect(repo.calls.single.filters.desde, DateTime(2025));
      expect(repo.calls.single.filters.hasta, DateTime(2025, 12, 31));
      expect(p.ranking(ReportKind.departamentos), isNull); // las tarjetas no se piden mientras no se ven
    });

    test('al volver a Venta general se piden las tarjetas que faltan', () async {
      final repo = _FakeRepo();
      final p = _provider(repo);
      await p.ensureLoaded();
      await _settle();
      await p.selectKind(ReportKind.marcas);
      await p.selectRange(ReportRange.ultimoAnio);
      await _settle();
      repo.calls.clear();

      await p.selectKind(ReportKind.general);
      await _settle();

      expect(
        repo.calls.map((c) => c.kind),
        [ReportKind.departamentos, ReportKind.vendedores, ReportKind.categorias, ReportKind.clientes],
      );
    });

    test('un error queda en ese reporte y se puede reintentar', () async {
      final repo = _FakeRepo()..failing.add(ReportKind.marcas);
      final p = _provider(repo);
      await p.ensureLoaded();
      await _settle();

      expect(p.ranking(ReportKind.marcas)!.error, 'Sin conexión a internet');
      expect(p.ranking(ReportKind.vendedores)!.loaded, isTrue); // los demás siguen

      repo.failing.clear();
      await p.retryRanking(ReportKind.marcas);
      expect(p.ranking(ReportKind.marcas)!.loaded, isTrue);
      expect(p.ranking(ReportKind.marcas)!.rows.length, 4);
    });

    test('una respuesta que llega tarde (cambió el rango) se descarta', () async {
      final repo = _FakeRepo()..gate = Completer<void>();
      final p = _provider(repo);
      final first = p.selectKind(ReportKind.marcas);
      await _settle();
      expect(p.ranking(ReportKind.marcas)!.loading, isTrue);

      // Cambia el rango mientras la primera respuesta sigue en camino.
      final change = p.selectRange(ReportRange.ultimoAnio);
      repo.gate!.complete();
      await first;
      await change;
      await _settle();

      expect(repo.calls.where((c) => c.kind == ReportKind.marcas).length, 2);
      expect(p.ranking(ReportKind.marcas)!.loaded, isTrue);
      expect(p.ranking(ReportKind.marcas)!.rows.length, 4);
    });

    test('la búsqueda filtra por nombre, sin importar mayúsculas ni tildes, y el % no cambia', () async {
      final repo = _FakeRepo();
      final p = _provider(repo);
      await p.ensureLoaded();
      await _settle();
      await p.selectKind(ReportKind.clientes);

      p.setRankingSearch(ReportKind.clientes, 'peru');
      final state = p.ranking(ReportKind.clientes)!;
      expect(state.visible.map((r) => r.name), ['PERÚ SAC']);
      expect(state.share(state.visible.single), 10); // sobre el total del rango, no sobre lo buscado

      p.setRankingSearch(ReportKind.clientes, '  sac ');
      expect(state.visible.length, 2);
      p.setRankingSearch(ReportKind.clientes, 'zzz');
      expect(state.visible, isEmpty);
      p.setRankingSearch(ReportKind.clientes, '');
      expect(state.visible.length, 2);
    });

    test('en Clientes, si faltan páginas, la búsqueda también va al servidor', () async {
      final repo = _FakeRepo();
      repo.rankings[ReportKind.clientes] = _report([('ACME SAC', 900), ('PERÚ SAC', 100)], hasMore: true, total: 5000);
      repo.searchResult = _report([('ZETA SRL', 40)], total: 40);
      final p = _provider(repo);
      await p.selectKind(ReportKind.clientes);
      repo.calls.clear();

      p.setRankingSearch(ReportKind.clientes, 'zeta');
      expect(repo.calls, isEmpty); // espera a que se deje de escribir
      await Future<void>.delayed(const Duration(milliseconds: 600));
      await _settle();

      expect(repo.calls.single.search, 'zeta');
      final state = p.ranking(ReportKind.clientes)!;
      expect(state.visible.map((r) => r.name), ['ZETA SRL']);
      expect(state.total, 5000); // el % sigue siendo sobre todo el rango
    });

    test('las demás listas se buscan solo en lo ya pedido (no hay búsqueda en el servidor)', () async {
      final repo = _FakeRepo();
      repo.rankings[ReportKind.marcas] = _report([('7POWER', 600), ('PIONEER', 300)], hasMore: true);
      final p = _provider(repo);
      await p.selectKind(ReportKind.marcas);
      repo.calls.clear();

      p.setRankingSearch(ReportKind.marcas, 'pio');
      await Future<void>.delayed(const Duration(milliseconds: 600));

      expect(repo.calls, isEmpty);
      expect(p.ranking(ReportKind.marcas)!.visible.map((r) => r.name), ['PIONEER']);
    });

    test('con más de 100 filas se pide la página siguiente y se agrega', () async {
      final repo = _FakeRepo();
      repo.rankings[ReportKind.clientes] = _report([('A', 60), ('B', 40)], hasMore: true, total: 130);
      repo.page2 = _report([('C', 30)], total: 130);
      final p = _provider(repo);
      await p.selectKind(ReportKind.clientes);

      await p.loadMoreRanking(ReportKind.clientes);

      final state = p.ranking(ReportKind.clientes)!;
      expect(repo.calls.last.page, 2);
      expect(state.rows.map((r) => r.name), ['A', 'B', 'C']);
      expect(state.hasMore, isFalse);

      repo.calls.clear();
      await p.loadMoreRanking(ReportKind.clientes); // ya no hay más
      expect(repo.calls, isEmpty);
    });

    test('sin Venta general (solo reportes por entidad) abre en el primero y no pide Venta general', () async {
      final repo = _FakeRepo();
      final p = _provider(
        repo,
        session: _session(permissions: const {'reportes.index', 'reportes.marcas.index'}),
      );
      await p.ensureLoaded();
      await _settle();

      expect(p.kind, ReportKind.marcas);
      expect(repo.generalCalls, 0);
      expect(p.ranking(ReportKind.marcas)!.loaded, isTrue);
      expect(p.loading, isFalse);
    });

    test('al cambiar de empresa se descarta todo y vuelve a Venta general', () async {
      final repo = _FakeRepo();
      final p = _provider(repo);
      await p.ensureLoaded();
      await _settle();
      await p.selectKind(ReportKind.marcas);

      p.syncSession(_session(companyId: 8));

      expect(p.kind, ReportKind.general);
      expect(p.ranking(ReportKind.marcas), isNull);
    });
  });

  group('ReportsPage: reportes por entidad', () {
    Future<_FakeRepo> pump(
      WidgetTester tester, {
      SessionContextEntity? session,
      ScreenLook? look,
      void Function(_FakeRepo repo)? setup,
      Size size = const Size(360, 2400),
    }) async {
      if (look != null) {
        await prepareLook(tester, look);
      } else {
        tester.view.physicalSize = Size(size.width * 3, size.height * 3);
        tester.view.devicePixelRatio = 3;
        tester.platformDispatcher.textScaleFactorTestValue = 0.55;
        addTearDown(() {
          tester.view.reset();
          tester.platformDispatcher.clearTextScaleFactorTestValue();
        });
      }
      final repo = _FakeRepo();
      setup?.call(repo);
      final s = session ?? _session();
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<ThemeProvider>(create: (_) => ThemeProvider(storage: _FakeThemeStorage())),
            ChangeNotifierProvider<AuthProvider>.value(value: _auth(s)),
            ChangeNotifierProvider<ReportsProvider>.value(value: _provider(repo, session: s)),
          ],
          child: lookApp(look, home: const Scaffold(body: ReportsPage())),
        ),
      );
      await tester.pumpAndSettle();
      return repo;
    }

    /// Abre un reporte tocando su tarjeta de Venta general; "Venta general" vuelve con la flecha.
    Future<void> choose(WidgetTester tester, String label) async {
      if (label == 'Venta general') {
        await tester.tap(find.byTooltip('Volver a Venta general'));
        await tester.pumpAndSettle();
        return;
      }
      final title = {
        'Departamentos': 'Ventas por departamentos',
        'Vendedor': 'Ventas por vendedores',
        'Marcas': 'Ventas por marcas',
        'Categoría': 'Ventas por categorías',
        'Cliente': 'Ventas por clientes',
      }[label]!;
      await tester.ensureVisible(find.text(title));
      await tester.pumpAndSettle();
      await tester.tap(find.text(title));
      await tester.pumpAndSettle();
    }

    testWidgets('con un solo reporte no sale el selector ni las tarjetas', (tester) async {
      await pump(
        tester,
        session: _session(permissions: const {'reportes.index', 'reportes.ventas.index'}),
      );

      expect(find.text('Departamentos'), findsNothing);
      expect(find.text('Ventas por marcas'), findsNothing);
      expect(find.byType(ReportKindSelector), findsNothing);
      expect(find.text('Venta Total'), findsOneWidget);
    });

    testWidgets('no hay fichas de reportes arriba: se entra por las tarjetas de Venta general', (tester) async {
      await pump(tester, size: const Size(1100, 1600));

      expect(find.byType(ReportKindSelector), findsNothing);
      expect(find.widgetWithText(ChoiceChip, 'Departamentos'), findsNothing);
      expect(find.widgetWithText(ChoiceChip, 'Vendedor'), findsNothing);
      expect(find.text('Ventas por departamentos'), findsOneWidget);
    });

    testWidgets('sin Venta general queda el selector para pasar de un reporte a otro', (tester) async {
      await pump(
        tester,
        size: const Size(1100, 1600),
        session: _session(permissions: const {'reportes.index', 'reportes.marcas.index', 'reportes.vendedor.index'}),
      );

      expect(find.byType(ReportKindSelector), findsOneWidget);
      expect(find.widgetWithText(ChoiceChip, 'Marcas'), findsOneWidget);
      expect(find.widgetWithText(ChoiceChip, 'Vendedor'), findsOneWidget);
      expect(find.byTooltip('Volver a Venta general'), findsNothing);
    });

    testWidgets('Venta general trae las tarjetas con el top 3, el monto, la barra y el %', (tester) async {
      await pump(tester);

      for (final title in [
        'Ventas por departamentos',
        'Ventas por vendedores',
        'Ventas por marcas',
        'Ventas por categorías',
        'Ventas por clientes',
      ]) {
        expect(find.text(title), findsOneWidget);
      }
      // Marcas: el top 3 (no el cuarto), con su monto y su % del total.
      expect(find.text('1. 7POWER'), findsOneWidget);
      expect(find.text('2. PIONEER'), findsOneWidget);
      expect(find.text('3. JBL'), findsOneWidget);
      expect(find.textContaining('KICKER'), findsNothing);
      expect(find.text('S/. 600.00'), findsOneWidget);
      expect(find.text('60.0 %'), findsOneWidget);
      expect(find.text('30.0 %'), findsWidgets); // PIONEER y AREQUIPA (departamentos)
      expect(find.text('9.0 %'), findsOneWidget);
      // El nombre del vendedor sale completo, no abreviado ni cortado.
      expect(find.text('1. GUSTAVO MIRANDA PUN'), findsOneWidget);
      expect(find.byType(RankingBar), findsWidgets);
    });

    testWidgets('nada habla de unidades en los reportes por entidad', (tester) async {
      await pump(tester);
      expect(find.textContaining('unidades'), findsNothing);

      await tester.tap(find.text('Ventas por marcas'));
      await tester.pumpAndSettle();
      expect(find.textContaining(RegExp('unidad', caseSensitive: false)), findsNothing);
    });

    testWidgets('tocar la tarjeta abre la lista completa: título, total, todas las filas y su %', (tester) async {
      await pump(tester);

      await tester.tap(find.text('Ventas por marcas'));
      await tester.pumpAndSettle();

      expect(find.text('Ventas por marcas'), findsOneWidget); // ahora es el título de la lista
      expect(find.text('Total S/. 1,000.00 · 4 marcas'), findsOneWidget);
      expect(find.text('7POWER'), findsOneWidget);
      expect(find.text('KICKER'), findsOneWidget);
      expect(find.text('S/. 10.00'), findsOneWidget);
      expect(find.text('1.0 %'), findsOneWidget);
      // El encabezado de la pantalla dice qué reporte es.
      expect(find.text('Marcas'), findsWidgets);
      expect(tester.element(find.byType(RankingView)).read<ReportsProvider>().kind, ReportKind.marcas);
    });

    testWidgets('abrir un reporte y volver con la flecha no vuelve a pedir lo ya pedido', (tester) async {
      final repo = await pump(tester);
      final before = repo.calls.length;

      await choose(tester, 'Cliente');

      expect(find.text('Total S/. 1,000.00 · 2 clientes'), findsOneWidget);
      expect(find.text('ACME SAC'), findsOneWidget);
      expect(find.text('90.0 %'), findsOneWidget);
      expect(repo.calls.length, before);

      await choose(tester, 'Venta general');
      expect(find.text('Venta Total'), findsOneWidget);
    });

    testWidgets('cada fila trae más detalles: ventas, ticket, subtotal, descuento y margen', (tester) async {
      await pump(tester);
      await choose(tester, 'Marcas');

      // Con el margen tapado (como en Venta general) se ve "S/. *******"; el ojo lo destapa.
      expect(find.textContaining('Subtotal'), findsWidgets);
      expect(find.textContaining('Desc.'), findsWidgets);
      expect(find.textContaining('ventas · Ticket prom.'), findsWidgets);
      expect(find.text('Margen S/. *******'), findsWidgets);

      await tester.tap(find.byTooltip('Ver el margen'));
      await tester.pumpAndSettle();
      expect(find.text('Margen S/. *******'), findsNothing);
      expect(find.textContaining('Margen S/.'), findsWidgets);
      expect(find.textContaining(RegExp('unidad', caseSensitive: false)), findsNothing);
    });

    testWidgets('los reportes por entidad no ofrecen comparar el año anterior ni el Excel', (tester) async {
      await pump(tester);
      // En Venta general, "Comparar año anterior" está dentro de los filtros y el Excel en la fila.
      expect(find.byTooltip('Descargar Excel'), findsOneWidget);
      await tester.tap(find.byTooltip('Filtros avanzados'));
      await tester.pumpAndSettle();
      expect(find.text('Comparar año anterior'), findsOneWidget);
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();

      await choose(tester, 'Marcas');

      expect(find.byTooltip('Descargar Excel'), findsNothing);
      // En los reportes por entidad tampoco se ofrece comparar dentro de los filtros.
      await tester.tap(find.byTooltip('Filtros'));
      await tester.pumpAndSettle();
      expect(find.text('Comparar año anterior'), findsNothing);
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();
      // El filtro va en la misma fila que el buscador (no en la fila de la comparación).
      expect(find.byTooltip('Filtros avanzados'), findsNothing);
      final bar = tester.getRect(find.byType(SearchBar));
      final filtro = tester.getRect(find.byTooltip('Filtros'));
      expect((filtro.center.dy - bar.center.dy).abs(), lessThan(bar.height / 2));
      expect(filtro.left, greaterThan(bar.right - 1));
    });

    testWidgets('buscar por nombre filtra la lista y avisa si no hay resultados', (tester) async {
      await pump(tester);
      await choose(tester, 'Marcas');

      await tester.enterText(find.byType(SearchBar), 'pio');
      await tester.pumpAndSettle();
      expect(find.text('PIONEER'), findsOneWidget);
      expect(find.text('7POWER'), findsNothing);
      expect(find.text('30.0 %'), findsOneWidget); // el % no cambia al buscar

      await tester.enterText(find.byType(SearchBar), 'zzz');
      await tester.pumpAndSettle();
      expect(find.text('Sin resultados'), findsOneWidget);
    });

    testWidgets('sin importes (jefe de almacén) solo se ve el %, nunca un monto', (tester) async {
      await pump(tester, session: _session(roles: const ['jefe de almacén']));

      // Las tarjetas: nombre y %, sin montos.
      expect(find.text('1. 7POWER'), findsOneWidget);
      expect(find.text('60.0 %'), findsOneWidget);
      expect(find.textContaining('S/.'), findsNothing);

      await choose(tester, 'Marcas');
      expect(find.text('4 marcas'), findsOneWidget); // sin "Total S/. ..."
      expect(find.text('60.0 %'), findsOneWidget);
      expect(find.textContaining('S/.'), findsNothing);
    });

    testWidgets('si una tarjeta falla lo dice y deja reintentar; las demás siguen', (tester) async {
      final repo = await pump(tester, setup: (r) => r.failing.add(ReportKind.marcas));

      expect(find.text('No se pudo cargar'), findsOneWidget);
      expect(find.text('1. ACME SAC'), findsOneWidget);

      repo.failing.clear();
      await tester.tap(find.text('Reintentar'));
      await tester.pumpAndSettle();
      expect(find.text('No se pudo cargar'), findsNothing);
      expect(find.text('1. 7POWER'), findsOneWidget);
    });

    testWidgets('si la lista completa falla muestra el error y reintenta', (tester) async {
      final repo = await pump(tester, setup: (r) => r.failing.add(ReportKind.categorias));

      await choose(tester, 'Categoría');
      expect(find.text('No se pudo cargar el reporte'), findsOneWidget);
      expect(find.text('Sin conexión a internet'), findsOneWidget);

      repo.failing.clear();
      await tester.tap(find.text('Reintentar'));
      await tester.pumpAndSettle();
      expect(find.text('AMPLIFICADORES'), findsOneWidget);
      expect(find.text('80.0 %'), findsOneWidget);
    });

    testWidgets('un reporte sin ventas: la tarjeta lo dice y la lista también', (tester) async {
      await pump(tester, setup: (r) => r.rankings[ReportKind.departamentos] = const RankingReport());

      expect(find.text('Sin ventas en el rango'), findsOneWidget);

      await choose(tester, 'Departamentos');
      expect(find.text('No hay ventas'), findsOneWidget);
    });

    testWidgets('en tablet la lista queda centrada con el ancho de siempre', (tester) async {
      await pump(tester, size: const Size(1100, 1600));

      await tester.tap(find.text('Ventas por marcas'));
      await tester.pumpAndSettle();

      final card = tester.getSize(find.byType(AppListCard).first);
      expect(card.width, lessThanOrEqualTo(720));
      expect(tester.takeException(), isNull);
    });

    group('modo oscuro y letra grande', () {
      for (final base in screenLooks) {
        final look = base.tall();

        testWidgets('Venta general con las tarjetas: ${base.label}', (tester) async {
          final handle = tester.ensureSemantics();
          await pump(tester, look: look);

          expect(find.text('Ventas por marcas'), findsOneWidget);
          await expectLooksRight(tester, look);
          handle.dispose();
        });

        testWidgets('la lista completa de un reporte: ${base.label}', (tester) async {
          final handle = tester.ensureSemantics();
          await pump(tester, look: look);
          await tester.tap(find.text('Ventas por marcas'));
          await tester.pumpAndSettle();

          expect(find.text('KICKER'), findsOneWidget);
          await expectLooksRight(tester, look);
          handle.dispose();
        });

        testWidgets('la lista sin importes: ${base.label}', (tester) async {
          await pump(tester, look: look, session: _session(roles: const ['jefe de almacén']));
          await tester.tap(find.text('Ventas por vendedores'));
          await tester.pumpAndSettle();

          await expectLooksRight(tester, look, contrast: false);
        });
      }
    });
  });
}

