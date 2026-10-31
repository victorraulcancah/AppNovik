import 'dart:convert';

import 'package:app_novik/core/errors/failures.dart';
import 'package:app_novik/core/utils/either.dart';
import 'package:app_novik/data/datasources/other_document_remote_datasource.dart';
import 'package:app_novik/data/datasources/theme_local_datasource.dart';
import 'package:app_novik/data/models/other_document_model.dart';
import 'package:app_novik/domain/entities/company_entity.dart';
import 'package:app_novik/domain/entities/other_document_entity.dart';
import 'package:app_novik/domain/entities/saved_credentials_entity.dart';
import 'package:app_novik/domain/entities/session_context_entity.dart';
import 'package:app_novik/domain/entities/user_entity.dart';
import 'package:app_novik/domain/repositories/auth_repository.dart';
import 'package:app_novik/domain/repositories/other_document_repository.dart';
import 'package:app_novik/domain/usecases/auth_usecases.dart';
import 'package:app_novik/domain/usecases/other_document_usecases.dart';
import 'package:app_novik/presentation/pages/other_documents_view.dart';
import 'package:app_novik/presentation/providers/auth_provider.dart';
import 'package:app_novik/presentation/providers/other_documents_provider.dart';
import 'package:app_novik/presentation/providers/theme_provider.dart';
import 'package:app_novik/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';

// ---------------------------------------------------------------- datos de ejemplo

Map<String, dynamic> _transfer({int id = 1, int nro = 7, bool estado = true, bool aceptado = false}) => {
      'id': id,
      'nro_documento': nro,
      'estado': estado,
      'created_at': '2026-10-31T15:30:00.000000Z',
      'user': {'id': 9, 'name': 'ANA'},
      'from_warehouse': {'id': 1, 'name': 'LIMA'},
      'to_warehouse': {'id': 2, 'name': 'AREQUIPA'},
      'products': [
        {
          'id': 10,
          'codigo': 'SUB-12',
          'name': 'SUBWOOFER 12"',
          'brand': {'name': 'PIONEER'},
          'pivot': {'cantidad': 3, 'aceptado': aceptado, 'confirmado': false},
        },
      ],
    };

Map<String, dynamic> _stockEntry() => {
      'id': 4,
      'nro_documento': 12,
      'created_at': '2026-10-31T15:30:00.000000Z',
      'user': {'name': 'ANA'},
      'warehouse': {'name': 'LIMA'},
      'products': [
        {
          'codigo': 'SUB-12',
          'name': 'SUBWOOFER 12"',
          'brand': {'name': 'PIONEER'},
          'pivot': {'costo': '50.5', 'stock': 4},
        },
        {
          'codigo': 'CAB-1',
          'name': 'CABLE RCA',
          'pivot': {'costo': null, 'stock': 10},
        },
      ],
    };

Map<String, dynamic> _sale() => {
      'id': 30,
      'nro_documento': 5,
      'total_soles': '100.00',
      'total_dolares': 0,
      'estado': true,
      'created_at': '2026-10-31T15:30:00.000000Z',
      'client': {'razon_social': 'ACME SAC', 'dni_ruc': '20123456789'},
      'warehouse': {'name': 'LIMA'},
      'user': {'name': 'ANA'},
      'products': [
        {
          'name': 'SUBWOOFER',
          'codigo': 'SUB-12',
          'pivot': {'cantidad': 2, 'precio': '50', 'subtotal_con_dto': '100', 'monto_dto': 0},
        },
      ],
    };

Map<String, dynamic> _guide({bool withBoleta = true}) => {
      'id': 5,
      'serie': 1,
      'numero': 3,
      'peso_total': '12.5',
      'direccion_salida': 'AV. LIMA 123',
      'direccion_llegada': 'CALLE SOL 45',
      'fecha_emision': '2026-10-30T05:00:00.000000Z',
      'fecha_traslado': '2026-10-31T05:00:00.000000Z',
      'created_at': '2026-10-31T15:30:00.000000Z',
      'tipo_guia': '01',
      'rzn_social_transportista': 'TRANSPORTES SAC',
      'doc_transportista': '20111111111',
      'dni_chofer': '12345678',
      'placa_chofer': 'ABC-123',
      'observaciones': 'Frágil',
      'ubigeo_salida': {
        'name': 'LIMA',
        'province': {'name': 'LIMA'},
        'department': {'name': 'LIMA'},
      },
      'ubigeo_llegada': {
        'name': 'CAYMA',
        'province': {'name': 'AREQUIPA'},
        'department': {'name': 'AREQUIPA'},
      },
      if (withBoleta)
        'boleta': {'id': 8, 'tipo': 'b', 'serie': 1, 'numero': 77, 'sale': _sale()}
      else
        'sale': _sale(),
    };

Map<String, dynamic> _creditNote({String tipo = 'b'}) => {
      'id': 6,
      'serie': 1,
      'numero': 2,
      'fecha_emision': '2026-10-31T05:00:00.000000Z',
      'created_at': '2026-10-31T15:30:00.000000Z',
      'descripcion': 'Error en el precio',
      'boleta': {'id': 8, 'tipo': tipo, 'serie': 1, 'numero': 77, 'sale': _sale()},
    };

Map<String, dynamic> _page(List<Map<String, dynamic>> data, {int current = 1, int last = 1, int? total}) => {
      'current_page': current,
      'last_page': last,
      'total': total ?? data.length,
      'data': data,
    };

// ---------------------------------------------------------------- repositorio falso

class _FakeRepo implements OtherDocumentRepository {
  final List<({OtherDocumentKind kind, int companyId, OtherDocumentFilters filters, int? number, int page})>
      calls = [];
  final List<int> deleted = [];
  Either<Failure, OtherDocumentPageEntity>? next;
  Either<Failure, void>? nextDelete;

  OtherDocumentPageEntity Function(OtherDocumentKind kind, int page)? build;

  @override
  Future<Either<Failure, OtherDocumentPageEntity>> getPage({
    required int companyId,
    required OtherDocumentKind kind,
    required OtherDocumentFilters filters,
    int? number,
    int page = 1,
    int pageSize = 20,
  }) async {
    calls.add((kind: kind, companyId: companyId, filters: filters, number: number, page: page));
    if (next != null) return next!;
    if (build != null) return Either.right(build!(kind, page));
    return Either.right(OtherDocumentPageEntity(
      items: [otherDocumentFromJson(_transfer(id: page), OtherDocumentKind.traslado)],
      currentPage: page,
      lastPage: 2,
      total: 2,
    ));
  }

  @override
  Future<Either<Failure, void>> deleteTransfer(int id) async {
    deleted.add(id);
    return nextDelete ?? Either.rightVoid();
  }
}

OtherDocumentsProvider _provider(_FakeRepo repo) => OtherDocumentsProvider(
      getDocumentsUseCase: GetOtherDocumentsUseCase(repository: repo),
      deleteTransferUseCase: DeleteTransferUseCase(repository: repo),
      now: () => DateTime(2026, 10, 31, 10),
    )..syncCompany(7);

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

SessionContextEntity _session({Set<String> permissions = const {}, List<String> roles = const []}) =>
    SessionContextEntity(
      user: const UserEntity(id: 9, name: 'Ana', usuario: 'ana'),
      company: const CompanyEntity(id: 7, razonSocial: 'ACME'),
      modules: const [],
      permissions: permissions,
      roles: roles,
      warehouses: const [],
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('modelos', () {
    test('un traslado: número T001, usuario, almacenes y productos con su recepción', () {
      final d = otherDocumentFromJson(_transfer(), OtherDocumentKind.traslado);

      expect(d.numero, 'T001-0007');
      expect(d.usuario, 'ANA');
      expect(d.desde, 'LIMA');
      expect(d.hacia, 'AREQUIPA');
      expect(d.activo, isTrue);
      expect(d.lines.single.cantidad, 3);
      expect(d.lines.single.marca, 'PIONEER');
      expect(d.lines.single.aceptado, isFalse);
      expect(d.pendienteRecepcion, isTrue);
      expect(d.sePuedeEliminar, isTrue);
    });

    test('un traslado con productos recibidos ya no se elimina ni está pendiente', () {
      final recibido = otherDocumentFromJson(_transfer(aceptado: true), OtherDocumentKind.traslado);
      final eliminado = otherDocumentFromJson(_transfer(estado: false), OtherDocumentKind.traslado);

      expect(recibido.pendienteRecepcion, isFalse);
      expect(recibido.sePuedeEliminar, isFalse);
      expect(eliminado.activo, isFalse);
      expect(eliminado.sePuedeEliminar, isFalse);
      expect(eliminado.pendienteRecepcion, isFalse);
    });

    test('una entrada de stock suma costo por cantidad, sin costo cuenta como 0', () {
      final d = otherDocumentFromJson(_stockEntry(), OtherDocumentKind.entradaStock);

      expect(d.numero, 'S001-0012');
      expect(d.almacen, 'LIMA');
      expect(d.lines.first.costo, 50.5);
      expect(d.lines.first.total, 202);
      expect(d.monto, 202);
      expect(d.unidades, 14);
    });

    test('una guía: número TG, peso, direcciones con su ubigeo y el comprobante de su boleta', () {
      final d = otherDocumentFromJson(_guide(), OtherDocumentKind.guia);

      expect(d.numero, 'TG01-0003');
      expect(d.guia!.pesoTotal, 12.5);
      expect(d.guia!.direccionLlegada, 'CALLE SOL 45');
      expect(d.guia!.ubigeoLlegada, 'CAYMA, AREQUIPA, AREQUIPA');
      expect(d.guia!.transportista, 'TRANSPORTES SAC');
      expect(d.comprobanteNumero, 'B001-0077');
      expect(d.comprobante, isNotNull);
      expect(d.comprobante!.numero, 'B001-00077');
      expect(d.comprobante!.cliente, 'ACME SAC');
      expect(d.comprobante!.boleta!.id, 8);
    });

    test('una guía sin boleta usa la venta: V001', () {
      final d = otherDocumentFromJson(_guide(withBoleta: false), OtherDocumentKind.guia);

      expect(d.comprobanteNumero, 'V001-0005');
      expect(d.comprobante!.boleta, isNull);
    });

    test('una guía sin serie se numera TGV1, como la web', () {
      expect(guideNumber({'numero': 9}), 'TGV1-0009');
      expect(guideNumber({'serie': 2, 'numero': 9}), 'TG02-0009');
    });

    test('una nota de crédito: BC para boletas, FC para facturas', () {
      final boleta = otherDocumentFromJson(_creditNote(), OtherDocumentKind.notaCredito);
      final factura = otherDocumentFromJson(_creditNote(tipo: 'f'), OtherDocumentKind.notaCredito);

      expect(boleta.numero, 'BC01-0002');
      expect(factura.numero, 'FC01-0002');
      expect(boleta.nota!.descripcion, 'Error en el precio');
      expect(boleta.comprobanteNumero, 'B001-0077');
      expect(factura.comprobanteNumero, 'F001-0077');
      expect(boleta.comprobante, isNotNull);
    });

    test('la página lee el paginado de Laravel', () {
      final page = otherDocumentPageFromJson(
        _page([_transfer(), _transfer(id: 2)], current: 1, last: 3, total: 41),
        OtherDocumentKind.traslado,
      );

      expect(page.items, hasLength(2));
      expect(page.total, 41);
      expect(page.hasMore, isTrue);
    });
  });

  group('datos', () {
    late List<http.BaseRequest> requests;
    late OtherDocumentRemoteDataSourceImpl dataSource;

    setUp(() {
      requests = [];
      dataSource = OtherDocumentRemoteDataSourceImpl(
        client: MockClient((request) async {
          requests.add(request);
          return http.Response(jsonEncode(_page([])), 200, headers: {'content-type': 'application/json'});
        }),
      );
    });

    final today = OtherDocumentFilters(desde: DateTime(2026, 10, 31), hasta: DateTime(2026, 10, 31));

    test('cada lista pide su ruta, con el rango "Creado" de la web (05:00 a 04:59:59)', () async {
      for (final (kind, path) in [
        (OtherDocumentKind.traslado, '/stock-transfer'),
        (OtherDocumentKind.guia, '/guia-remision'),
        (OtherDocumentKind.notaCredito, '/nota-credito'),
        (OtherDocumentKind.entradaStock, '/stock'),
      ]) {
        await dataSource.getPage(
          token: 'tok',
          companyId: 7,
          kind: kind,
          filters: today,
          page: 2,
          pageSize: 20,
        );
        final uri = requests.last.url;
        expect(uri.path, endsWith(path), reason: kind.label);
        expect(uri.queryParametersAll['pagination[current]'], ['2']);
        expect(uri.queryParametersAll['pagination[pageSize]'], ['20']);
        expect(uri.queryParametersAll['filters[created_at][]'], [
          '2026-10-31 05:00:00',
          '2026-11-01 04:59:59',
        ]);
      }
    });

    test('solo los traslados mandan la empresa', () async {
      await dataSource.getPage(
        token: 'tok',
        companyId: 7,
        kind: OtherDocumentKind.traslado,
        filters: today,
        page: 1,
        pageSize: 20,
      );
      expect(requests.last.url.queryParameters['company_id'], '7');

      await dataSource.getPage(
        token: 'tok',
        companyId: 7,
        kind: OtherDocumentKind.guia,
        filters: today,
        page: 1,
        pageSize: 20,
      );
      expect(requests.last.url.queryParameters.containsKey('company_id'), isFalse);
      expect(requests.last.headers['Authorization'], 'Bearer tok');
    });

    test('con un número buscado va por su columna y sin rango de fechas', () async {
      await dataSource.getPage(
        token: 'tok',
        companyId: 7,
        kind: OtherDocumentKind.guia,
        filters: today,
        number: 3,
        page: 1,
        pageSize: 20,
      );
      expect(requests.last.url.queryParameters['filters[numero]'], '3');
      expect(requests.last.url.queryParametersAll.containsKey('filters[created_at][]'), isFalse);

      await dataSource.getPage(
        token: 'tok',
        companyId: 7,
        kind: OtherDocumentKind.entradaStock,
        filters: today,
        number: 12,
        page: 1,
        pageSize: 20,
      );
      expect(requests.last.url.queryParameters['filters[nro_documento]'], '12');
    });

    test('sin rango (todas las fechas) no manda filtro de fecha', () async {
      await dataSource.getPage(
        token: 'tok',
        companyId: 7,
        kind: OtherDocumentKind.notaCredito,
        filters: const OtherDocumentFilters(),
        page: 1,
        pageSize: 20,
      );
      expect(requests.last.url.queryParametersAll.containsKey('filters[created_at][]'), isFalse);
    });

    test('eliminar un traslado hace DELETE /stock-transfer/{id}', () async {
      await dataSource.deleteTransfer('tok', 9);
      expect(requests.last.method, 'DELETE');
      expect(requests.last.url.path, endsWith('/stock-transfer/9'));
    });
  });

  group('DeleteTransferUseCase', () {
    test('no elimina un traslado con productos recibidos', () async {
      final repo = _FakeRepo();
      final useCase = DeleteTransferUseCase(repository: repo);

      final result = await useCase(otherDocumentFromJson(_transfer(aceptado: true), OtherDocumentKind.traslado));

      expect(result.left.message, contains('ya se aceptó productos'));
      expect(repo.deleted, isEmpty);
    });

    test('solo elimina traslados', () async {
      final repo = _FakeRepo();
      final useCase = DeleteTransferUseCase(repository: repo);

      final result = await useCase(otherDocumentFromJson(_stockEntry(), OtherDocumentKind.entradaStock));

      expect(result.isLeft, isTrue);
      expect(repo.deleted, isEmpty);
    });
  });

  group('OtherDocumentsProvider', () {
    test('carga cada lista la primera vez, con lo de hoy, y no la repite', () async {
      final repo = _FakeRepo();
      final provider = _provider(repo);

      await provider.ensureLoaded(OtherDocumentKind.traslado);
      await provider.ensureLoaded(OtherDocumentKind.traslado);

      expect(repo.calls, hasLength(1));
      expect(repo.calls.single.companyId, 7);
      expect(repo.calls.single.filters.desde, DateTime(2026, 10, 31));
      expect(repo.calls.single.filters.hasta, DateTime(2026, 10, 31));
      expect(provider.stateOf(OtherDocumentKind.traslado).items, hasLength(1));
      expect(provider.stateOf(OtherDocumentKind.guia).items, isEmpty);
    });

    test('loadMore añade la página siguiente y se detiene al final', () async {
      final repo = _FakeRepo();
      final provider = _provider(repo);

      await provider.refresh(OtherDocumentKind.traslado);
      await provider.loadMore(OtherDocumentKind.traslado);
      await provider.loadMore(OtherDocumentKind.traslado); // ya no hay más

      expect(provider.stateOf(OtherDocumentKind.traslado).items.map((i) => i.id), [1, 2]);
      expect(repo.calls, hasLength(2));
    });

    test('el número buscado es lo que va después del guion, sin ceros', () async {
      final repo = _FakeRepo();
      final provider = _provider(repo);

      await provider.setSearch(OtherDocumentKind.guia, 'TG01-0003');
      expect(repo.calls.last.number, 3);

      await provider.setSearch(OtherDocumentKind.guia, '0012');
      expect(repo.calls.last.number, 12);

      await provider.setSearch(OtherDocumentKind.guia, 'abc');
      expect(repo.calls.last.number, isNull);

      await provider.setSearch(OtherDocumentKind.guia, '');
      expect(repo.calls.last.number, isNull);
    });

    test('cada lista conserva su búsqueda y sus filtros', () async {
      final repo = _FakeRepo();
      final provider = _provider(repo);

      await provider.setSearch(OtherDocumentKind.guia, '5');
      await provider.applyFilters(
        OtherDocumentKind.notaCredito,
        OtherDocumentFilters(desde: DateTime(2026, 10, 1), hasta: DateTime(2026, 10, 31)),
      );

      expect(provider.stateOf(OtherDocumentKind.guia).search, '5');
      expect(provider.stateOf(OtherDocumentKind.notaCredito).search, '');
      expect(provider.filtersActive(OtherDocumentKind.notaCredito), isTrue);
      expect(provider.filtersActive(OtherDocumentKind.guia), isFalse);
      expect(repo.calls.last.filters.desde, DateTime(2026, 10, 1));
    });

    test('cambiar de empresa descarta todo', () async {
      final repo = _FakeRepo();
      final provider = _provider(repo);
      await provider.refresh(OtherDocumentKind.traslado);

      provider.syncCompany(8);

      expect(provider.stateOf(OtherDocumentKind.traslado).items, isEmpty);
      await provider.ensureLoaded(OtherDocumentKind.traslado);
      expect(repo.calls.last.companyId, 8);
    });

    test('un error en la primera página queda en la lista', () async {
      final repo = _FakeRepo()..next = Either.left(const NetworkFailure('Sin conexión a internet'));
      final provider = _provider(repo);

      await provider.refresh(OtherDocumentKind.guia);

      expect(provider.stateOf(OtherDocumentKind.guia).error, 'Sin conexión a internet');
      expect(provider.stateOf(OtherDocumentKind.guia).items, isEmpty);
    });

    test('eliminar un traslado lo saca de la lista', () async {
      final repo = _FakeRepo();
      final provider = _provider(repo);
      await provider.refresh(OtherDocumentKind.traslado);
      final transfer = provider.stateOf(OtherDocumentKind.traslado).items.single;

      final result = await provider.deleteTransfer(transfer);

      expect(result.isRight, isTrue);
      expect(repo.deleted, [1]);
      expect(provider.stateOf(OtherDocumentKind.traslado).items, isEmpty);
    });

    test('si el servidor rechaza eliminar, el traslado se queda', () async {
      final repo = _FakeRepo()..nextDelete = Either.left(const ValidationFailure('No se puede eliminar'));
      final provider = _provider(repo);
      await provider.refresh(OtherDocumentKind.traslado);

      final result = await provider.deleteTransfer(provider.stateOf(OtherDocumentKind.traslado).items.single);

      expect(result.left.message, 'No se puede eliminar');
      expect(provider.stateOf(OtherDocumentKind.traslado).items, hasLength(1));
    });
  });

  group('OtherDocumentsView', () {
    Future<_FakeRepo> pump(
      WidgetTester tester,
      OtherDocumentKind kind, {
      Set<String> permissions = const {},
      List<String> roles = const [],
      OtherDocumentPageEntity Function(OtherDocumentKind, int)? build,
    }) async {
      // Las pruebas dibujan con la fuente Ahem (casi el doble de ancha que una real).
      tester.view.physicalSize = const Size(360 * 3, 780 * 3);
      tester.view.devicePixelRatio = 3;
      tester.platformDispatcher.textScaleFactorTestValue = 0.55;
      addTearDown(() {
        tester.view.reset();
        tester.platformDispatcher.clearTextScaleFactorTestValue();
      });

      final repo = _FakeRepo()..build = build;
      final session = _session(permissions: permissions, roles: roles);
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<ThemeProvider>(
              create: (_) => ThemeProvider(storage: _FakeThemeStorage()),
            ),
            ChangeNotifierProvider<AuthProvider>.value(value: _auth(session)),
            ChangeNotifierProvider<OtherDocumentsProvider>.value(value: _provider(repo)),
          ],
          child: MaterialApp(
            theme: AppTheme.light,
            home: Scaffold(body: OtherDocumentsView(kind: kind)),
          ),
        ),
      );
      await tester.pumpAndSettle();
      return repo;
    }

    OtherDocumentPageEntity one(Map<String, dynamic> json, OtherDocumentKind kind) =>
        OtherDocumentPageEntity(
          items: [otherDocumentFromJson(json, kind)],
          currentPage: 1,
          lastPage: 1,
          total: 1,
        );

    testWidgets('traslados: la tarjeta muestra número, almacenes y que falta recibir', (tester) async {
      await pump(tester, OtherDocumentKind.traslado);

      expect(find.text('T001-0007'), findsOneWidget);
      expect(find.text('ANA'), findsOneWidget);
      expect(find.text('LIMA → AREQUIPA'), findsOneWidget);
      expect(find.text('Falta recibir'), findsOneWidget);
      expect(find.text('2 traslados'), findsOneWidget);
    });

    testWidgets('traslados: ver detalle muestra los datos y cada producto con su recepción', (tester) async {
      await pump(tester, OtherDocumentKind.traslado);

      await tester.tap(find.byTooltip('Ver detalle'));
      await tester.pumpAndSettle();

      expect(find.text('Traslados de Stock'), findsOneWidget);
      expect(find.text('Desde'), findsOneWidget);
      expect(find.text('Hacia'), findsOneWidget);
      expect(find.text('SUBWOOFER 12"'), findsOneWidget);
      expect(find.text('SUB-12 · PIONEER'), findsOneWidget);
      expect(find.text('Pendiente'), findsOneWidget);
      expect(find.text('Cerrar'), findsOneWidget);
      expect(find.text('Ver comprobante'), findsNothing);
    });

    testWidgets('traslados: eliminar pide confirmación y solo con el permiso', (tester) async {
      final repo = await pump(
        tester,
        OtherDocumentKind.traslado,
        permissions: const {'transferir-stock.destroy'},
      );

      await tester.tap(find.byTooltip('Eliminar'));
      await tester.pumpAndSettle();
      expect(repo.deleted, isEmpty);
      await tester.tap(find.widgetWithText(FilledButton, 'Eliminar'));
      await tester.pumpAndSettle();

      expect(repo.deleted, [1]);
      expect(find.text('Transferencia eliminada'), findsOneWidget);
    });

    testWidgets('traslados: sin el permiso de eliminar no sale el botón', (tester) async {
      await pump(tester, OtherDocumentKind.traslado);

      expect(find.byTooltip('Eliminar'), findsNothing);
    });

    testWidgets('traslados ya recibidos no se pueden eliminar', (tester) async {
      await pump(
        tester,
        OtherDocumentKind.traslado,
        permissions: const {'transferir-stock.destroy'},
        build: (kind, page) => one(_transfer(aceptado: true), kind),
      );

      expect(find.text('Recibido'), findsOneWidget);
      expect(find.byTooltip('Eliminar'), findsNothing);
    });

    testWidgets('guías: peso, comprobante, y el PDF de su comprobante', (tester) async {
      await pump(
        tester,
        OtherDocumentKind.guia,
        build: (kind, page) => one(_guide(), kind),
      );

      expect(find.text('TG01-0003'), findsOneWidget);
      expect(find.text('12.50 KG.'), findsOneWidget);
      expect(find.text('Comprobante B001-0077'), findsOneWidget);
      expect(find.byTooltip('Ver comprobante PDF'), findsOneWidget);

      await tester.tap(find.byTooltip('Ver detalle'));
      await tester.pumpAndSettle();
      expect(find.text('Guías de Remisión'), findsOneWidget);
      expect(find.text('AV. LIMA 123 · LIMA, LIMA, LIMA'), findsOneWidget);
      expect(find.text('CALLE SOL 45 · CAYMA, AREQUIPA, AREQUIPA'), findsOneWidget);
      expect(find.text('TRANSPORTES SAC'), findsOneWidget);
      expect(find.text('Frágil'), findsOneWidget);
      expect(find.text('Ver comprobante'), findsOneWidget);
    });

    testWidgets('notas de crédito: número, comprobante y motivo', (tester) async {
      await pump(
        tester,
        OtherDocumentKind.notaCredito,
        build: (kind, page) => one(_creditNote(), kind),
      );

      expect(find.text('BC01-0002'), findsOneWidget);
      expect(find.text('Comprobante B001-0077'), findsOneWidget);
      expect(find.text('Error en el precio'), findsOneWidget);

      await tester.tap(find.byTooltip('Ver detalle'));
      await tester.pumpAndSettle();
      expect(find.text('Motivo'), findsOneWidget);
      expect(find.text('Ver comprobante'), findsOneWidget);
    });

    testWidgets('entradas de stock: monto en la tarjeta y detalle con costos y total', (tester) async {
      await pump(
        tester,
        OtherDocumentKind.entradaStock,
        build: (kind, page) => one(_stockEntry(), kind),
      );

      expect(find.text('S001-0012'), findsOneWidget);
      expect(find.text('S/. 202.00'), findsOneWidget);

      await tester.tap(find.byTooltip('Ver detalle'));
      await tester.pumpAndSettle();
      expect(find.text('Sucursal'), findsOneWidget);
      expect(find.text('Costo S/. 50.50'), findsOneWidget);
      expect(find.text('Nro. de ítems'), findsOneWidget);
      expect(find.text('14'), findsOneWidget);
      expect(find.text('Total'), findsOneWidget);
    });

    testWidgets('el Jefe de Almacén no ve los importes de las entradas de stock', (tester) async {
      await pump(
        tester,
        OtherDocumentKind.entradaStock,
        roles: const ['jefe de almacén'],
        build: (kind, page) => one(_stockEntry(), kind),
      );

      expect(find.text('S/. 202.00'), findsNothing);

      await tester.tap(find.byTooltip('Ver detalle'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Costo S/.'), findsNothing);
      expect(find.text('Total'), findsNothing);
      expect(find.text('Nro. de ítems'), findsOneWidget);
    });

    testWidgets('buscar por número pide ese número', (tester) async {
      final repo = await pump(tester, OtherDocumentKind.guia, build: (kind, page) => one(_guide(), kind));

      await tester.enterText(find.byType(SearchBar), 'TG01-0003');
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pumpAndSettle();

      expect(repo.calls.last.number, 3);
    });

    testWidgets('sin documentos se avisa con el rango de fechas', (tester) async {
      await pump(
        tester,
        OtherDocumentKind.notaCredito,
        build: (kind, page) =>
            const OtherDocumentPageEntity(items: [], currentPage: 1, lastPage: 1, total: 0),
      );

      expect(find.text('No hay documentos'), findsOneWidget);
      expect(find.text('Prueba con otro rango de fechas en los filtros.'), findsOneWidget);
    });

    testWidgets('el filtro cambia el rango de fechas', (tester) async {
      final repo = await pump(tester, OtherDocumentKind.entradaStock);

      await tester.tap(find.byTooltip('Filtros'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Este mes'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Aplicar filtros'));
      await tester.pumpAndSettle();

      expect(repo.calls.last.filters.desde, DateTime(2026, 10));
      expect(repo.calls.last.filters.hasta, DateTime(2026, 10, 31));
    });
  });
}
