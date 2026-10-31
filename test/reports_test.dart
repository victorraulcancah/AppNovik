import 'dart:convert';
import 'dart:typed_data';

import 'package:app_novik/core/errors/failures.dart';
import 'package:app_novik/core/utils/either.dart';
import 'package:app_novik/data/datasources/report_remote_datasource.dart';
import 'package:app_novik/data/datasources/theme_local_datasource.dart';
import 'package:app_novik/data/models/report_model.dart';
import 'package:app_novik/domain/entities/company_entity.dart';
import 'package:app_novik/domain/entities/document_entity.dart';
import 'package:app_novik/domain/entities/report_entity.dart';
import 'package:app_novik/domain/entities/saved_credentials_entity.dart';
import 'package:app_novik/domain/entities/session_context_entity.dart';
import 'package:app_novik/domain/entities/user_entity.dart';
import 'package:app_novik/domain/repositories/auth_repository.dart';
import 'package:app_novik/domain/repositories/report_repository.dart';
import 'package:app_novik/domain/usecases/auth_usecases.dart';
import 'package:app_novik/domain/usecases/report_usecases.dart';
import 'package:app_novik/presentation/components/components.dart' show AppVariationBadge;
import 'package:app_novik/presentation/pages/reports_page.dart';
import 'package:app_novik/presentation/providers/auth_provider.dart';
import 'package:app_novik/presentation/providers/reports_provider.dart';
import 'package:app_novik/presentation/providers/theme_provider.dart';
import 'package:app_novik/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';

// ---------------------------------------------------------------- datos de ejemplo

/// Forma de `GET /ventas/reporte`.
Map<String, dynamic> _json({int total = 2}) => {
      'ventas': [
        {
          'name': '30-Octubre',
          'ventas_soles': 100,
          'ventas_dolares': 0,
          'ventas_dolares_a_soles': 0,
          'unidades': 5,
        },
        {
          'name': '31-Octubre',
          'ventas_soles': 50.5,
          'ventas_dolares': 20,
          'ventas_dolares_a_soles': 70,
          'unidades': 3,
        },
      ],
      'sales': [
        {
          'id': 1,
          'nro_documento': 5,
          'nro_documento_raw': 5,
          'boleta': {'id': 8, 'tipo': 'b', 'serie': 1, 'numero': 12},
          'products': [
            {'id': 10},
            {'id': 11},
          ],
        },
        {
          'id': 2,
          'nro_documento': 6,
          'nro_documento_raw': 6,
          'boleta': null,
          'products': [
            {'id': 10},
          ],
        },
      ],
      'data': [
        {
          'id': 10,
          'name': 'SUBWOOFER 12"',
          'codigo': 'SUB-12',
          'brand': {'name': 'PIONEER'},
          'img': null,
          'cantidad': 6,
          'subtotal': 300,
          'descuento': 10,
          'venta': 290,
          'costo': '100',
        },
        {
          'id': 11,
          'name': 'CABLE RCA',
          'codigo': 'CAB-1',
          'brand': null,
          'cantidad': 2,
          'subtotal': 40.5,
          'descuento': 0,
          'venta': 40.5,
          'costo': '10.25',
        },
      ],
      'total': total,
      'countVentas': 2,
      'unidadesVendidas': 8,
      'totalVentas': 330.5,
      'totalCostos': 620.5,
    };

SalesReportEntity _report({double ventas = 330.5}) => SalesReportEntity(
      days: const [SalesReportDayEntity(name: '31-Octubre', ventasSoles: 100)],
      products: const [
        SalesReportProductEntity(
          id: 10,
          name: 'SUBWOOFER 12"',
          codigo: 'SUB-12',
          marca: 'PIONEER',
          cantidad: 6,
          subtotal: 300,
          venta: 290,
          costo: 100,
        ),
      ],
      totalProducts: 2,
      countVentas: 2,
      unidades: 8,
      totalVentas: ventas,
      totalCostos: 100,
    );

// ---------------------------------------------------------------- repositorio falso

class _FakeRepo implements ReportRepository {
  final List<({SalesReportFilters filters, int page, String? sortField, bool desc})> calls = [];
  final List<SalesReportFilters> exports = [];
  Either<Failure, SalesReportEntity>? next;
  SalesReportEntity Function(SalesReportFilters filters, int page)? build;
  int catalogCalls = 0;
  final List<int> sales = [];

  @override
  Future<Either<Failure, SalesReportEntity>> getSalesReport({
    required SalesReportFilters filters,
    int page = 1,
    int pageSize = 15,
    String? sortField,
    bool sortDescending = true,
  }) async {
    calls.add((filters: filters, page: page, sortField: sortField, desc: sortDescending));
    if (next != null) return next!;
    if (build != null) return Either.right(build!(filters, page));
    return Either.right(salesReportFromJson(_json()));
  }

  @override
  Future<Either<Failure, DownloadedFile>> exportSalesReport(SalesReportFilters filters) async {
    exports.add(filters);
    return Either.right(DownloadedFile(name: 'Reporte de Ventas.xlsx', bytes: Uint8List.fromList([1])));
  }

  @override
  Future<Either<Failure, SalesReportCatalogs>> getCatalogs({
    required int companyId,
    required int userId,
    required bool soloMiCartera,
  }) async {
    catalogCalls++;
    return Either.right(const SalesReportCatalogs(
      sucursales: [(id: '1', name: 'LIMA')],
      marcas: [(id: '3', name: 'PIONEER')],
      departamentos: [(id: '04', name: 'AREQUIPA')],
    ));
  }

  @override
  Future<Either<Failure, DocumentEntity>> getSale(int id) async {
    sales.add(id);
    return Either.left(const ValidationFailure('sin venta en la prueba'));
  }
}

ReportsProvider _provider(_FakeRepo repo, {SessionContextEntity? session}) => ReportsProvider(
      getSalesReportUseCase: GetSalesReportUseCase(repository: repo),
      exportSalesReportUseCase: ExportSalesReportUseCase(repository: repo),
      getCatalogsUseCase: GetReportCatalogsUseCase(repository: repo),
      getSaleUseCase: GetReportSaleUseCase(repository: repo),
      now: () => DateTime(2026, 10, 31, 10), // sábado
    )..syncSession(session ?? _session());

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

SessionContextEntity _session({
  Set<String> permissions = const {'reportes.index', 'reportes.ventas.index'},
  List<String> roles = const ['Ceo Empresa'],
  int companyId = 7,
}) =>
    SessionContextEntity(
      user: const UserEntity(id: 9, name: 'Ana', usuario: 'ana'),
      company: CompanyEntity(id: companyId, razonSocial: 'ACME', igv: 0.18, renta: 0.015),
      modules: const [],
      permissions: permissions,
      roles: roles,
      warehouses: const [],
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('salesReportFromJson', () {
    test('lee las cifras, la serie por día, las ventas y los productos', () {
      final r = salesReportFromJson(_json());

      expect(r.countVentas, 2);
      expect(r.unidades, 8);
      expect(r.totalVentas, 330.5);
      expect(r.totalCostos, 620.5);
      expect(r.totalProducts, 2);

      expect(r.days.map((d) => d.name), ['30-Octubre', '31-Octubre']);
      expect(r.days.last.ventasDolares, 20);
      expect(r.days.last.ventasDolaresASoles, 70);
      expect(r.days.last.unidades, 3);

      final p = r.products.first;
      expect(p.name, 'SUBWOOFER 12"');
      expect(p.marca, 'PIONEER');
      expect(p.costo, 100); // viene como texto
      expect(p.costoTotal, 600);
      expect(p.margen, -300); // subtotal 300 - costo 600
      expect(r.products.last.marca, isNull);
    });

    test('las ventas se rotulan como la web: boleta, factura o venta', () {
      final docs = salesReportFromJson(_json()).documents;

      expect(docs.first.tipo, 'Boleta');
      expect(docs.first.numero, 'B001-0012');
      expect(docs.first.productIds, [10, 11]);
      expect(docs.last.tipo, 'Venta');
      expect(docs.last.numero, 'V001-0006');
    });

    test('una factura y una venta con número de texto', () {
      final r = salesReportFromJson({
        'sales': [
          {
            'id': 1,
            'boleta': {'tipo': 'f', 'serie': 2, 'numero': 45},
            'products': [],
          },
          {'id': 2, 'nro_documento_raw': 'v001-0009', 'products': []},
        ],
      });

      expect(r.documents.first.numero, 'F002-0045');
      expect(r.documents.first.tipo, 'Factura');
      expect(r.documents.last.numero, 'V001-0009');
    });

    test('el ticket promedio es lo vendido en el rango entre el número de ventas', () {
      final r = salesReportFromJson(_json());

      // (100 + 0) + (50.5 + 70) = 220.5 entre 2 ventas.
      expect(r.ventasDelRango, 220.5);
      expect(r.ticketPromedio, 110.25);
    });

    test('sin ventas el ticket promedio no divide por cero', () {
      expect(const SalesReportEntity().ticketPromedio, 0);
    });

    test('las opciones de un filtro usan el nombre que traiga cada catálogo', () {
      final options = reportOptionsFromJson([
        {'id': 1, 'name': 'LIMA'},
        {'id': 2, 'display_label': 'ACME SAC', 'name': 'x'},
        {'id': '04', 'name': 'AREQUIPA'},
        {'id': 5, 'first_name': 'ANA', 'last_name': 'PÉREZ'},
        {'name': 'sin id'},
      ]);

      expect(options.map((o) => (o.id, o.name)), [
        ('1', 'LIMA'),
        ('2', 'ACME SAC'),
        ('04', 'AREQUIPA'),
        ('5', 'ANA PÉREZ'),
      ]);
    });
  });

  group('MarginFigures', () {
    test('el margen bruto es venta menos costo', () {
      final m = MarginFigures.of(1000, 600);

      expect(m.bruto, 400);
      expect(m.brutoPct, 40);
      expect(m.neto, 400); // sin IGV ni renta
    });

    test('el margen neto descuenta el IGV del margen y la renta de la venta sin IGV', () {
      final m = MarginFigures.of(1180, 590, igv: 0.18, renta: 0.015);

      // venta sin IGV 1000, costo sin IGV 500: margen 500; IGV del margen 90; renta 15.
      expect(m.bruto, 590);
      expect(m.neto, closeTo(590 - (500 * 0.18 + 1000 * 0.015), 1e-9));
      expect(m.netoPct, closeTo(m.neto / 1180 * 100, 1e-9));
    });

    test('sin ventas todo es cero', () {
      final m = MarginFigures.of(0, 0, igv: 0.18);
      expect(m.brutoPct, 0);
      expect(m.netoPct, 0);
    });
  });

  group('SalesReportFilters', () {
    test('el año anterior es el mismo rango un año antes', () {
      final f = SalesReportFilters(desde: DateTime(2026, 10, 1), hasta: DateTime(2026, 10, 31));

      expect(f.yearBefore.desde, DateTime(2025, 10, 1));
      expect(f.yearBefore.hasta, DateTime(2025, 10, 31));
    });

    test('el 29 de febrero pasa al 28 del año anterior', () {
      final f = SalesReportFilters(desde: DateTime(2024, 2, 1), hasta: DateTime(2024, 2, 29));

      expect(f.yearBefore.hasta, DateTime(2023, 2, 28));
    });

    test('cuenta solo los filtros avanzados puestos', () {
      final f = SalesReportFilters(
        desde: DateTime(2026),
        hasta: DateTime(2026),
        marcas: const ['1'],
        departamentos: const ['04'],
      );

      expect(f.advancedCount, 2);
    });
  });

  group('datos', () {
    late List<http.BaseRequest> requests;
    late ReportRemoteDataSourceImpl dataSource;
    String body = jsonEncode(_json());

    setUp(() {
      requests = [];
      body = jsonEncode(_json());
      dataSource = ReportRemoteDataSourceImpl(
        client: MockClient((request) async {
          requests.add(request);
          return http.Response(body, 200, headers: {'content-type': 'application/json'});
        }),
      );
    });

    final filters = SalesReportFilters(
      desde: DateTime(2026, 10, 1),
      hasta: DateTime(2026, 10, 31),
      sucursales: const ['1', '2'],
      clientes: const ['7'],
      vendedores: const ['9'],
      marcas: const ['3'],
      categorias: const ['5'],
      departamentos: const ['04'],
    );

    test('pide /ventas/reporte con los mismos parámetros que la web', () async {
      await dataSource.getSalesReport(
        token: 'tok',
        filters: filters,
        page: 2,
        pageSize: 15,
        sortField: 'cantidad',
        sortDescending: false,
      );

      final q = requests.last.url.queryParametersAll;
      expect(requests.last.url.path, endsWith('/ventas/reporte'));
      expect(requests.last.method, 'GET');
      expect(q['fechas[]'], ['2026-10-01', '2026-10-31']);
      expect(q['warehouse_id[]'], ['1', '2']);
      expect(q['clientes[]'], ['7']);
      expect(q['vendedores[]'], ['9']);
      expect(q['marcas[]'], ['3']);
      expect(q['tipos_producto[]'], ['5']);
      expect(q['departamentos[]'], ['04']);
      expect(q['page'], ['2']);
      expect(q['results'], ['15']);
      expect(q['sortField'], ['cantidad']);
      expect(q['sortOrder'], ['ascend']);
      expect(requests.last.headers['Authorization'], 'Bearer tok');
    });

    test('sin filtros avanzados solo manda las fechas', () async {
      await dataSource.getSalesReport(
        token: 'tok',
        filters: SalesReportFilters(desde: DateTime(2026, 10, 1), hasta: DateTime(2026, 10, 31)),
        page: 1,
        pageSize: 15,
        sortDescending: true,
      );

      final q = requests.last.url.queryParametersAll;
      expect(q.keys.toSet(), {'fechas[]', 'page', 'results'});
    });

    test('exportar hace POST a /ventas/export/reporte con los filtros', () async {
      body = 'xlsx';
      final bytes = await dataSource.exportSalesReport('tok', filters);

      expect(requests.last.method, 'POST');
      expect(requests.last.url.path, endsWith('/ventas/export/reporte'));
      expect(requests.last.url.queryParametersAll['fechas[]'], ['2026-10-01', '2026-10-31']);
      expect(requests.last.url.queryParametersAll['marcas[]'], ['3']);
      expect(utf8.decode(bytes), 'xlsx');
    });

    test('los catálogos: un vendedor sin permiso solo se ofrece a sí mismo', () async {
      body = jsonEncode([
        {'id': 9, 'name': 'ANA'},
        {'id': 10, 'name': 'LUIS'},
      ]);

      final solo =
          await dataSource.getCatalogs(token: 'tok', companyId: 7, userId: 9, soloMiCartera: true);
      final todos =
          await dataSource.getCatalogs(token: 'tok', companyId: 7, userId: 9, soloMiCartera: false);

      expect(solo.vendedores.map((v) => v.name), ['ANA']);
      expect(todos.vendedores.map((v) => v.name), ['ANA', 'LUIS']);
      expect(todos.departamentos.map((d) => d.id), ['9', '10']);
      final paths = requests.map((r) => r.url.path).toSet();
      expect(paths.any((p) => p.endsWith('/almacenes/list')), isTrue);
      expect(paths.any((p) => p.endsWith('/usuarios/list')), isTrue);
      expect(paths.any((p) => p.endsWith('/marcas')), isTrue);
      expect(paths.any((p) => p.endsWith('/categorias')), isTrue);
      expect(paths.any((p) => p.endsWith('/ubigeo/search/departments')), isTrue);
    });

    test('una venta suelta o dentro de data se lee igual', () async {
      final sale = {
        'id': 30,
        'nro_documento': 5,
        'total_soles': '100',
        'total_dolares': 0,
        'client': {'razon_social': 'ACME SAC'},
        'products': [],
      };

      body = jsonEncode(sale);
      final a = await dataSource.getSale('tok', 30);
      body = jsonEncode({'success': true, 'data': sale});
      final b = await dataSource.getSale('tok', 30);

      expect(a.cliente, 'ACME SAC');
      expect(b.numero, a.numero);
      expect(requests.last.url.path, endsWith('/ventas/30'));
    });
  });

  group('GetSalesReportUseCase', () {
    test('la fecha inicial no puede ser posterior a la final', () async {
      final repo = _FakeRepo();
      final result = await GetSalesReportUseCase(repository: repo)(
        filters: SalesReportFilters(desde: DateTime(2026, 10, 31), hasta: DateTime(2026, 10, 1)),
      );

      expect(result.left, isA<ValidationFailure>());
      expect(repo.calls, isEmpty);
    });
  });

  group('ReportsProvider', () {
    test('los rangos son los mismos atajos de la web', () {
      final p = _provider(_FakeRepo());
      DateTimeRange of(ReportRange r) {
        p.range = r;
        return p.dates;
      }

      // Hoy es sábado 31 de octubre de 2026.
      expect(
        of(ReportRange.ultimaSemana),
        DateTimeRange(start: DateTime(2026, 10, 19), end: DateTime(2026, 10, 25)),
      );
      expect(
        of(ReportRange.estaSemana),
        DateTimeRange(start: DateTime(2026, 10, 26), end: DateTime(2026, 10, 31)),
      );
      expect(of(ReportRange.ultimoMes), DateTimeRange(start: DateTime(2026, 9), end: DateTime(2026, 9, 30)));
      expect(of(ReportRange.esteMes), DateTimeRange(start: DateTime(2026, 10), end: DateTime(2026, 10, 31)));
      expect(of(ReportRange.ultimoAnio), DateTimeRange(start: DateTime(2025), end: DateTime(2025, 12, 31)));
      expect(of(ReportRange.esteAnio), DateTimeRange(start: DateTime(2026), end: DateTime(2026, 10, 31)));
    });

    test('arranca en este mes y pide la primera página ordenada por venta', () async {
      final repo = _FakeRepo();
      final p = _provider(repo);

      await p.ensureLoaded();
      await p.ensureLoaded(); // no repite

      expect(repo.calls, hasLength(1));
      expect(repo.calls.single.filters.desde, DateTime(2026, 10));
      expect(repo.calls.single.filters.hasta, DateTime(2026, 10, 31));
      expect(repo.calls.single.page, 1);
      expect(repo.calls.single.sortField, 'venta');
      expect(repo.calls.single.desc, isTrue);
      expect(p.report!.products, hasLength(2));
      expect(p.hasMore, isFalse);
    });

    test('loadMore añade la página siguiente y se detiene al final', () async {
      final repo = _FakeRepo()
        ..build = (f, page) => SalesReportEntity(
              days: const [SalesReportDayEntity(name: 'x')],
              products: [SalesReportProductEntity(id: page, name: 'P$page')],
              totalProducts: 3,
              countVentas: 4,
              totalVentas: 100,
            );
      final p = _provider(repo);

      await p.refresh();
      expect(p.hasMore, isTrue);
      await p.loadMore();
      await p.loadMore();
      await p.loadMore(); // ya no hay más

      expect(p.report!.products.map((e) => e.id), [1, 2, 3]);
      expect(repo.calls.map((c) => c.page), [1, 2, 3]);
      expect(p.report!.countVentas, 4); // lo demás no cambia al paginar
      expect(p.hasMore, isFalse);
    });

    test('ordenar por otro campo vuelve a la primera página; el mismo campo invierte el sentido', () async {
      final repo = _FakeRepo();
      final p = _provider(repo);
      await p.refresh();

      await p.selectSort(ReportSort.cantidad);
      expect((repo.calls.last.sortField, repo.calls.last.desc, repo.calls.last.page), ('cantidad', true, 1));

      await p.selectSort(ReportSort.cantidad);
      expect(repo.calls.last.desc, isFalse);
    });

    test('comparar pide el mismo rango del año anterior; apagarlo lo descarta', () async {
      final repo = _FakeRepo();
      final p = _provider(repo);
      await p.refresh();

      await p.setCompare(true);

      expect(repo.calls.last.filters.desde, DateTime(2025, 10));
      expect(repo.calls.last.filters.hasta, DateTime(2025, 10, 31));
      expect(p.previous, isNotNull);

      await p.setCompare(false);
      expect(p.previous, isNull);
    });

    test('con la comparación encendida, cambiar de rango vuelve a pedir el año anterior', () async {
      final repo = _FakeRepo();
      final p = _provider(repo);
      await p.refresh();
      await p.setCompare(true);
      repo.calls.clear();

      await p.selectRange(ReportRange.esteAnio);

      expect(repo.calls, hasLength(2));
      expect(repo.calls.first.filters.desde, DateTime(2026));
      expect(repo.calls.last.filters.desde, DateTime(2025));
    });

    test('aplicar filtros avanzados los manda y cambia el rango a personalizado', () async {
      final repo = _FakeRepo();
      final p = _provider(repo);

      await p.applyFilters(SalesReportFilters(
        desde: DateTime(2026, 9, 1),
        hasta: DateTime(2026, 9, 15),
        marcas: const ['3'],
      ));

      expect(p.range, ReportRange.personalizado);
      expect(repo.calls.last.filters.desde, DateTime(2026, 9));
      expect(repo.calls.last.filters.marcas, ['3']);
      expect(p.advancedCount, 1);

      await p.clearAdvancedFilters();
      expect(p.advancedCount, 0);
    });

    test('los catálogos se piden una sola vez', () async {
      final repo = _FakeRepo();
      final p = _provider(repo);

      await p.ensureCatalogs();
      await p.ensureCatalogs();

      expect(repo.catalogCalls, 1);
      expect(p.catalogs.marcas.single.name, 'PIONEER');
    });

    test('un error en el reporte queda en error', () async {
      final repo = _FakeRepo()..next = Either.left(const NetworkFailure('Sin conexión a internet'));
      final p = _provider(repo);

      await p.refresh();

      expect(p.error, 'Sin conexión a internet');
      expect(p.report, isNull);
    });

    test('cambiar de empresa descarta todo y vuelve a empezar en este mes', () async {
      final repo = _FakeRepo();
      final p = _provider(repo);
      await p.selectRange(ReportRange.esteAnio);

      p.syncSession(_session(companyId: 8));

      expect(p.report, isNull);
      expect(p.range, ReportRange.esteMes);
      await p.ensureLoaded();
      expect(repo.calls.last.filters.desde, DateTime(2026, 10));
    });

    test('exportar pide el Excel con los filtros actuales', () async {
      final repo = _FakeRepo();
      final p = _provider(repo);
      await p.selectRange(ReportRange.ultimoMes);

      final result = await p.exportCurrent();

      expect(result.right.name, 'Reporte de Ventas.xlsx');
      expect(repo.exports.single.desde, DateTime(2026, 9));
    });

    test('lo que se ve depende del rol, como en la web', () {
      ReportsProvider as(List<String> roles, {Set<String> permissions = const {}}) =>
          _provider(_FakeRepo(), session: _session(roles: roles, permissions: permissions));

      final ceo = as(['Ceo Empresa']);
      expect((ceo.ocultarImportes, ceo.ocultarMargen), (false, false));

      final vendedor = as(['Vendedor']);
      expect((vendedor.ocultarImportes, vendedor.ocultarMargen), (false, true));
      expect(vendedor.soloMiCartera, isTrue);

      final jefeAlmacen = as(['jefe de almacén']);
      expect((jefeAlmacen.ocultarImportes, jefeAlmacen.ocultarMargen), (true, true));

      final jefeComercial = as(['JEFE COMERCIAL']);
      expect((jefeComercial.ocultarImportes, jefeComercial.ocultarMargen), (false, true));

      // Un CEO que además es Vendedor sigue viendo el margen.
      final ceoVendedor = as(['Ceo Empresa', 'Vendedor']);
      expect(ceoVendedor.ocultarMargen, isFalse);

      // Un Vendedor con permiso para ver a los demás ya no se limita a su cartera.
      final vendedorTodos = as(['Vendedor'], permissions: {'reportes.ventas.ver-otros-vendedores'});
      expect(vendedorTodos.soloMiCartera, isFalse);
    });
  });

  group('ReportsPage', () {
    Future<_FakeRepo> pump(
      WidgetTester tester, {
      SessionContextEntity? session,
      SalesReportEntity Function(SalesReportFilters, int)? build,
    }) async {
      // Las pruebas dibujan con la fuente Ahem (casi el doble de ancha que una real). La pantalla es
      // alta para que la lista de productos, que se arma a medida que se baja, esté toda dibujada.
      tester.view.physicalSize = const Size(360 * 3, 2400 * 3);
      tester.view.devicePixelRatio = 3;
      tester.platformDispatcher.textScaleFactorTestValue = 0.55;
      addTearDown(() {
        tester.view.reset();
        tester.platformDispatcher.clearTextScaleFactorTestValue();
      });

      final repo = _FakeRepo()..build = build;
      final s = session ?? _session();
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<ThemeProvider>(
              create: (_) => ThemeProvider(storage: _FakeThemeStorage()),
            ),
            ChangeNotifierProvider<AuthProvider>.value(value: _auth(s)),
            ChangeNotifierProvider<ReportsProvider>.value(value: _provider(repo, session: s)),
          ],
          child: MaterialApp(theme: AppTheme.light, home: const Scaffold(body: ReportsPage())),
        ),
      );
      await tester.pumpAndSettle();
      return repo;
    }

    testWidgets('muestra Ventas General: las cinco cifras, la gráfica y los productos', (tester) async {
      await pump(tester);

      expect(find.text('Ventas General'), findsOneWidget);
      expect(find.text('Venta Total'), findsOneWidget);
      expect(find.text('S/. 330.50'), findsOneWidget);
      expect(find.text('Unidades Vendidas'), findsOneWidget);
      expect(find.text('8'), findsOneWidget);
      expect(find.text('N° de Ventas'), findsOneWidget);
      expect(find.text('Ticket Promedio'), findsOneWidget);
      expect(find.text('S/. 110.25'), findsOneWidget);
      expect(find.text('Margen Bruto'), findsOneWidget);
      expect(find.text('S/. *******'), findsWidgets); // el margen sale oculto
      expect(find.text('Ventas'), findsOneWidget); // título de la gráfica
      expect(find.text('Productos y servicios · 2'), findsOneWidget);
      expect(find.text('SUBWOOFER 12"'), findsOneWidget);
      expect(find.text('SUB-12 · PIONEER'), findsOneWidget);
      expect(find.text('S/. 290.00'), findsOneWidget);
    });

    testWidgets('los atajos de fecha son los de la web, con Este mes elegido', (tester) async {
      await pump(tester);

      for (final label in ['Última semana', 'Esta semana', 'Último mes']) {
        expect(find.text(label), findsOneWidget, reason: label);
      }
      // Los demás atajos quedan a la derecha: se desliza la fila.
      await tester.drag(find.byType(ListView).first, const Offset(-400, 0));
      await tester.pumpAndSettle();
      for (final label in ['Este mes', 'Último año', 'Este año']) {
        expect(find.text(label), findsOneWidget, reason: label);
      }
      expect(
        tester.widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Este mes')).selected,
        isTrue,
      );
    });

    testWidgets('elegir otro atajo pide ese rango', (tester) async {
      final repo = await pump(tester);

      await tester.tap(find.text('Último mes'));
      await tester.pumpAndSettle();

      expect(repo.calls.last.filters.desde, DateTime(2026, 9));
      expect(repo.calls.last.filters.hasta, DateTime(2026, 9, 30));
    });

    testWidgets('el ojo del margen lo muestra y lo oculta', (tester) async {
      await pump(tester);
      expect(find.text('S/. -290.00'), findsNothing);

      await tester.tap(find.byIcon(Icons.visibility_off_outlined));
      await tester.pumpAndSettle();

      // Margen bruto de la tarjeta: 330.50 - 620.50. El del producto: subtotal 300 - costo 600.
      expect(find.text('S/. -290.00'), findsOneWidget);
      expect(find.text('Margen S/. -300.00'), findsOneWidget);
      expect(find.text('S/. *******'), findsNothing);
    });

    testWidgets('comparar año anterior muestra la variación de cada cifra', (tester) async {
      final repo = await pump(
        tester,
        build: (f, page) => f.desde.year == 2025 ? _report(ventas: 165.25) : salesReportFromJson(_json()),
      );
      expect(find.byType(AppVariationBadge), findsNothing);

      await tester.tap(find.byType(CheckboxListTile));
      await tester.pumpAndSettle();

      expect(repo.calls.last.filters.desde, DateTime(2025, 10));
      // 330.5 contra 165.25 es el doble: +100 %.
      expect(find.text('+100.0 % ↑'), findsWidgets);
    });

    testWidgets('el jefe de almacén no ve importes ni margen, solo unidades', (tester) async {
      await pump(tester, session: _session(roles: const ['jefe de almacén']));

      expect(find.text('Venta Total'), findsNothing);
      expect(find.text('Ticket Promedio'), findsNothing);
      expect(find.text('Margen Bruto'), findsNothing);
      expect(find.text('Unidades Vendidas'), findsOneWidget);
      expect(find.text('N° de Ventas'), findsOneWidget);
      expect(find.text('Unidades vendidas'), findsOneWidget); // la gráfica es de unidades
      expect(find.text('S/. 290.00'), findsNothing);
      expect(find.text('6 uds.'), findsOneWidget);
    });

    testWidgets('el vendedor ve los importes pero no el margen', (tester) async {
      await pump(tester, session: _session(roles: const ['Vendedor']));

      expect(find.text('Venta Total'), findsOneWidget);
      expect(find.text('Margen Bruto'), findsNothing);
      expect(find.textContaining('Margen S/.'), findsNothing);
    });

    testWidgets('Ver documentos lista las ventas que incluyen ese producto', (tester) async {
      await pump(tester);

      await tester.tap(find.byTooltip('Ver documentos').first);
      await tester.pumpAndSettle();

      expect(find.text('Documentos'), findsOneWidget);
      expect(find.text('Boleta Nro: B001-0012'), findsOneWidget);
      expect(find.text('Venta Nro: V001-0006'), findsOneWidget);
    });

    testWidgets('si el servidor rechaza el reporte muestra el error y deja reintentar', (tester) async {
      final repo = _FakeRepo()..next = Either.left(const NetworkFailure('Sin conexión a internet'));
      tester.view.physicalSize = const Size(360 * 3, 780 * 3);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      final s = _session();
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<ThemeProvider>(
              create: (_) => ThemeProvider(storage: _FakeThemeStorage()),
            ),
            ChangeNotifierProvider<AuthProvider>.value(value: _auth(s)),
            ChangeNotifierProvider<ReportsProvider>.value(value: _provider(repo, session: s)),
          ],
          child: MaterialApp(theme: AppTheme.light, home: const Scaffold(body: ReportsPage())),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('No se pudo cargar el reporte'), findsOneWidget);
      expect(find.text('Sin conexión a internet'), findsOneWidget);

      repo.next = null;
      await tester.tap(find.text('Reintentar'));
      await tester.pumpAndSettle();
      expect(find.text('Venta Total'), findsOneWidget);
    });

    testWidgets('sin el permiso del reporte no pide nada', (tester) async {
      final repo = await pump(tester, session: _session(permissions: const {'reportes.index'}));

      expect(find.text('Sin acceso'), findsOneWidget);
      expect(repo.calls, isEmpty);
    });

    testWidgets('Descargar Excel pide el reporte con los filtros actuales', (tester) async {
      final repo = await pump(tester);

      await tester.tap(find.byTooltip('Descargar Excel'));
      await tester.pumpAndSettle();

      expect(repo.exports, hasLength(1));
      expect(repo.exports.single.desde, DateTime(2026, 10));
    });

    testWidgets('el panel de filtros avanzados pide los catálogos y aplica lo elegido', (tester) async {
      final repo = await pump(tester);

      await tester.tap(find.byTooltip('Filtros avanzados'));
      await tester.pumpAndSettle();
      expect(repo.catalogCalls, 1);
      for (final label in [
        'Fechas',
        'Sucursales',
        'Clientes',
        'Vendedores',
        'Marcas',
        'Categoría',
        'Departamentos',
      ]) {
        expect(find.text(label), findsOneWidget, reason: label);
      }

      // Elige la marca PIONEER.
      await tester.ensureVisible(find.text('Marcas'));
      await tester.tap(find.text('Marcas'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('PIONEER'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Aplicar').last);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Aplicar filtros'));
      await tester.pumpAndSettle();

      expect(repo.calls.last.filters.marcas, ['3']);
    });
  });
}
