import 'dart:async';
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
import 'package:app_novik/domain/entities/warehouse_entity.dart';
import 'package:app_novik/domain/repositories/auth_repository.dart';
import 'package:app_novik/domain/repositories/other_document_repository.dart';
import 'package:app_novik/domain/usecases/auth_usecases.dart';
import 'package:app_novik/domain/usecases/other_document_usecases.dart';
import 'package:app_novik/presentation/components/app_list_card.dart' show AppListCard;
import 'support/screen_look.dart';
import 'package:app_novik/presentation/pages/other_documents_view.dart';
import 'package:app_novik/presentation/widgets/other_document_modals.dart' show otherDocumentActiveFilters;
import 'package:app_novik/presentation/pdf/other_document_pdf.dart';
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

Map<String, dynamic> _transfer({
  int id = 1,
  int nro = 7,
  bool estado = true,
  bool aceptado = false,
  bool confirmado = false,
  bool withWarehouses = true,
}) => {
      'id': id,
      'nro_documento': nro,
      'estado': estado,
      'from': 1,
      'to': 2,
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
          'cod_barra': '7750001',
          'pivot': {'cantidad': 3, 'aceptado': aceptado, 'confirmado': confirmado},
          // El PATCH devuelve el traslado sin la relación de almacenes (sin costos).
          if (withWarehouses)
            'warehouses': [
              {'id': 2, 'pivot': {'costo_promedio': '99'}},
              {'id': 1, 'pivot': {'costo_promedio': '45.5'}},
            ],
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
      'cod_traslado': '01',
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

  /// (traslado, producto) de cada PATCH de recibir y de validar.
  final List<(int, int)> received = [];
  final List<(int, int)> confirmed = [];

  /// Si no es `null`, el PATCH espera a este completer (para ver el estado "en curso").
  Completer<void>? hold;
  Either<Failure, OtherDocumentEntity>? nextReceive;
  Either<Failure, OtherDocumentEntity>? nextConfirm;
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

  @override
  Future<Either<Failure, OtherDocumentEntity>> receiveTransferProduct(int id, int productId) async {
    received.add((id, productId));
    await hold?.future;
    return nextReceive ??
        Either.right(
          otherDocumentFromJson(
            _transfer(id: id, aceptado: true, withWarehouses: false),
            OtherDocumentKind.traslado,
          ),
        );
  }

  @override
  Future<Either<Failure, OtherDocumentEntity>> confirmTransferProduct(int id, int productId) async {
    confirmed.add((id, productId));
    await hold?.future;
    return nextConfirm ??
        Either.right(
          otherDocumentFromJson(
            _transfer(id: id, confirmado: true, withWarehouses: false),
            OtherDocumentKind.traslado,
          ),
        );
  }
}

OtherDocumentsProvider _provider(_FakeRepo repo, {VoidCallback? onSessionExpired}) => OtherDocumentsProvider(
      getDocumentsUseCase: GetOtherDocumentsUseCase(repository: repo),
      deleteTransferUseCase: DeleteTransferUseCase(repository: repo),
      receiveTransferProductUseCase: ReceiveTransferProductUseCase(repository: repo),
      confirmTransferProductUseCase: ConfirmTransferProductUseCase(repository: repo),
      onSessionExpired: onSessionExpired,
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

SessionContextEntity _session({
  Set<String> permissions = const {},
  List<String> roles = const [],
  List<WarehouseEntity> warehouses = const [],
}) =>
    SessionContextEntity(
      user: const UserEntity(id: 9, name: 'Ana', usuario: 'ana'),
      company: const CompanyEntity(id: 7, razonSocial: 'ACME'),
      modules: const [],
      permissions: permissions,
      roles: roles,
      warehouses: warehouses,
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

    test('un traslado trae el producto, su código de barras, si se validó y el almacén de destino', () {
      final d = otherDocumentFromJson(_transfer(confirmado: true), OtherDocumentKind.traslado);

      expect(d.haciaId, 2);
      expect(d.lines.single.productId, 10);
      expect(d.lines.single.codBarra, '7750001');
      expect(d.lines.single.confirmado, isTrue);
      expect(d.lines.single.aceptado, isFalse);
    });

    test('las entradas de stock no llevan producto ni código de barras', () {
      final d = otherDocumentFromJson(_stockEntry(), OtherDocumentKind.entradaStock);
      expect(d.lines.first.productId, isNull);
      expect(d.lines.first.codBarra, isNull);
    });

    test('el valor de un producto trasladado es su costo promedio en el almacén de salida', () {
      final d = otherDocumentFromJson(_transfer(), OtherDocumentKind.traslado);

      expect(d.lines.single.costo, 45.5); // el del almacén 1 (salida), no el del 2
      expect(d.lines.single.total, 136.5);
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

    group('recibir y validar productos de un traslado', () {
      late List<http.Request> patches;
      late OtherDocumentRemoteDataSourceImpl patchSource;
      var status = 200;
      var body = '';

      setUp(() {
        patches = [];
        status = 200;
        body = jsonEncode(_transfer(id: 9, aceptado: true, confirmado: true, withWarehouses: false));
        patchSource = OtherDocumentRemoteDataSourceImpl(
          client: MockClient((request) async {
            patches.add(request);
            return http.Response(body, status, headers: {'content-type': 'application/json'});
          }),
        );
      });

      test('recibir hace PATCH /stock-transfer/{id} con el product_id y devuelve el traslado', () async {
        final transfer = await patchSource.receiveTransferProduct('tok', 9, 10);

        final request = patches.single;
        expect(request.method, 'PATCH');
        expect(request.url.path, endsWith('/stock-transfer/9'));
        expect(request.headers['Authorization'], 'Bearer tok');
        expect(jsonDecode(request.body), {'product_id': 10});
        expect(transfer.id, 9);
        expect(transfer.lines.single.aceptado, isTrue);
      });

      test('validar hace PATCH /stock-transfer/{id}/confirm con el product_id', () async {
        final transfer = await patchSource.confirmTransferProduct('tok', 9, 10);

        final request = patches.single;
        expect(request.method, 'PATCH');
        expect(request.url.path, endsWith('/stock-transfer/9/confirm'));
        expect(jsonDecode(request.body), {'product_id': 10});
        expect(transfer.lines.single.confirmado, isTrue);
      });

      test('un 401 (sin el permiso despachos.transferir.update) falla con el mensaje del backend', () async {
        status = 401;
        body = jsonEncode({'message': 'No autorizado'});

        expect(
          () => patchSource.receiveTransferProduct('tok', 9, 10),
          throwsA(isA<Object>()),
        );
      });
    });
  });

  group('PDF', () {
    const company = CompanyEntity(
      id: 7,
      razonSocial: 'MULTISERVICIOS 7POWER S.A.C.',
      ruc: '20612345678',
      direccion: 'AV. PRINCIPAL 123 - LIMA',
      telefono: '999 888 777',
      email: 'ventas@7power.pe',
      web: 'www.7power.pe',
    );

    test('los cuatro documentos tienen su PDF, como en la web', () {
      for (final kind in OtherDocumentKind.values) {
        expect(hasOtherDocumentPdf(kind), isTrue, reason: kind.label);
      }
    });

    test('la guía y la nota de crédito necesitan los productos y el cliente de su venta', () {
      final guia = otherDocumentFromJson(_guide(), OtherDocumentKind.guia);
      final nota = otherDocumentFromJson(_creditNote(), OtherDocumentKind.notaCredito);
      final sinVenta = otherDocumentFromJson(
        {..._guide()..remove('boleta'), 'id': 9},
        OtherDocumentKind.guia,
      );

      expect(otherDocumentPdfAvailable(guia), isTrue);
      expect(otherDocumentPdfAvailable(nota), isTrue);
      expect(otherDocumentPdfAvailable(sinVenta), isFalse);
      expect(otherDocumentPdfNeedsCompany(OtherDocumentKind.guia), isTrue);
      expect(otherDocumentPdfNeedsCompany(OtherDocumentKind.traslado), isFalse);
    });

    test('se genera el PDF de la guía de remisión (privada y pública) y el de la nota de crédito', () async {
      final publica = otherDocumentFromJson(
        {..._guide(), 'matricula_transportista': 'MTC123'},
        OtherDocumentKind.guia,
      );
      final guia = otherDocumentFromJson(
        {..._guide(), 'tipo_guia': '02', 'placa_chofer': 'ABC-123', 'dni_chofer': '12345678'},
        OtherDocumentKind.guia,
      );
      final nota = otherDocumentFromJson(_creditNote(), OtherDocumentKind.notaCredito);
      final factura = otherDocumentFromJson(_creditNote(tipo: 'f'), OtherDocumentKind.notaCredito);

      final pdfs = [
        await buildOtherDocumentPdf(document: guia, company: company),
        await buildOtherDocumentPdf(document: publica, company: company),
        await buildOtherDocumentPdf(document: nota, company: company),
        await buildOtherDocumentPdf(document: factura, company: company),
      ];

      for (final bytes in pdfs) {
        expect(String.fromCharCodes(bytes.sublist(0, 5)), '%PDF-');
        expect(bytes.length, greaterThan(2000));
      }
    });

    test('se genera el PDF del traslado y de la entrada, con y sin importes', () async {
      final transfer = otherDocumentFromJson(_transfer(), OtherDocumentKind.traslado);
      final entry = otherDocumentFromJson(_stockEntry(), OtherDocumentKind.entradaStock);

      final pdfs = [
        await buildOtherDocumentPdf(document: transfer),
        await buildOtherDocumentPdf(document: entry),
        await buildOtherDocumentPdf(document: entry, showAmounts: false),
      ];

      for (final bytes in pdfs) {
        expect(String.fromCharCodes(bytes.sublist(0, 5)), '%PDF-');
        expect(bytes.length, greaterThan(1500));
      }
      // Sin importes el documento es más corto.
      expect(pdfs[2].length, lessThan(pdfs[1].length));
    });
  });

  group('qué se puede hacer con un producto del traslado (como la web)', () {
    final transfer = otherDocumentFromJson(_transfer(), OtherDocumentKind.traslado); // destino: 2
    final line = transfer.lines.single;

    TransferLineAction action(
      OtherDocumentEntity t, {
      bool admin = false,
      List<int> warehouses = const [],
      OtherDocumentLine? l,
    }) =>
        t.actionFor(l ?? t.lines.first, isAdminOrCeo: admin, warehouseIds: warehouses);

    test('Admin Empresa o Ceo Empresa reciben, tengan o no el almacén de destino', () {
      expect(action(transfer, admin: true), TransferLineAction.receive);
      expect(action(transfer, admin: true, warehouses: [1]), TransferLineAction.receive);
    });

    test('quien tiene el almacén de destino recibe', () {
      expect(action(transfer, warehouses: [2]), TransferLineAction.receive);
      expect(action(transfer, warehouses: [1, 2]), TransferLineAction.receive);
    });

    test('quien no es admin ni CEO ni tiene el destino valida con el código de barras', () {
      expect(action(transfer), TransferLineAction.validate);
      expect(action(transfer, warehouses: [1]), TransferLineAction.validate);
    });

    test('un producto ya recibido o un traslado eliminado no se vuelven a recibir', () {
      final recibido = otherDocumentFromJson(_transfer(aceptado: true), OtherDocumentKind.traslado);
      final eliminado = otherDocumentFromJson(_transfer(estado: false), OtherDocumentKind.traslado);

      expect(action(recibido, admin: true), TransferLineAction.none);
      expect(action(recibido, warehouses: [2]), TransferLineAction.none);
      expect(action(eliminado, admin: true), TransferLineAction.none);
    });

    test('la validación sigue disponible aunque el producto ya esté recibido (como la web)', () {
      final recibido = otherDocumentFromJson(_transfer(aceptado: true), OtherDocumentKind.traslado);
      expect(action(recibido), TransferLineAction.validate);
    });

    test('solo los traslados tienen acciones', () {
      final entrada = otherDocumentFromJson(_stockEntry(), OtherDocumentKind.entradaStock);
      expect(action(entrada, admin: true), TransferLineAction.none);
      expect(line.productId, isNotNull);
    });
  });

  group('ReceiveTransferProductUseCase y ConfirmTransferProductUseCase', () {
    final transfer = otherDocumentFromJson(_transfer(), OtherDocumentKind.traslado);

    test('recibir manda el traslado y el producto', () async {
      final repo = _FakeRepo();
      final result = await ReceiveTransferProductUseCase(repository: repo)(transfer, transfer.lines.single);

      expect(result.isRight, isTrue);
      expect(repo.received, [(1, 10)]);
    });

    test('no se recibe dos veces un producto (el backend sumaría el stock otra vez)', () async {
      final repo = _FakeRepo();
      final recibido = otherDocumentFromJson(_transfer(aceptado: true), OtherDocumentKind.traslado);

      final result = await ReceiveTransferProductUseCase(repository: repo)(recibido, recibido.lines.single);

      expect(result.left.message, 'Este producto ya fue recibido');
      expect(repo.received, isEmpty);
    });

    test('no se recibe un traslado eliminado ni algo que no es un traslado', () async {
      final repo = _FakeRepo();
      final useCase = ReceiveTransferProductUseCase(repository: repo);
      final eliminado = otherDocumentFromJson(_transfer(estado: false), OtherDocumentKind.traslado);
      final entrada = otherDocumentFromJson(_stockEntry(), OtherDocumentKind.entradaStock);

      expect((await useCase(eliminado, eliminado.lines.single)).left.message, 'El traslado fue eliminado');
      expect((await useCase(entrada, entrada.lines.first)).isLeft, isTrue);
      expect(repo.received, isEmpty);
    });

    test('validar con el código de barras correcto llama al backend', () async {
      final repo = _FakeRepo();
      final result =
          await ConfirmTransferProductUseCase(repository: repo)(transfer, transfer.lines.single, ' 7750001 ');

      expect(result.isRight, isTrue);
      expect(repo.confirmed, [(1, 10)]);
    });

    test('un código de barras distinto se rechaza sin llamar al backend', () async {
      final repo = _FakeRepo();
      final result = await ConfirmTransferProductUseCase(repository: repo)(transfer, transfer.lines.single, '123');

      expect(result.left.message, 'El código de barras no coincide');
      expect(repo.confirmed, isEmpty);
    });

    test('un producto sin código de barras no se puede validar', () async {
      final repo = _FakeRepo();
      final sinCodigo = otherDocumentFromJson(
        {
          ..._transfer(),
          'products': [
            {
              ...(_transfer()['products'] as List).first as Map<String, dynamic>,
              'cod_barra': null,
            },
          ],
        },
        OtherDocumentKind.traslado,
      );

      final result = await ConfirmTransferProductUseCase(repository: repo)(sinCodigo, sinCodigo.lines.single, '');

      expect(result.left.message, 'Este producto no tiene código de barras');
      expect(repo.confirmed, isEmpty);
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

    test('recibir un producto deja el traslado recibido en la lista y conserva sus costos', () async {
      final repo = _FakeRepo();
      final provider = _provider(repo);
      await provider.refresh(OtherDocumentKind.traslado);
      final transfer = provider.stateOf(OtherDocumentKind.traslado).items.single;
      expect(transfer.pendienteRecepcion, isTrue);

      final result = await provider.receiveProduct(transfer, transfer.lines.single);

      expect(result.isRight, isTrue);
      expect(repo.received, [(1, 10)]);
      final now = provider.stateOf(OtherDocumentKind.traslado).items.single;
      expect(now.lines.single.aceptado, isTrue);
      expect(now.pendienteRecepcion, isFalse);
      expect(now.sePuedeEliminar, isFalse);
      // La respuesta del PATCH no trae los costos: se conserva el que ya se tenía.
      expect(now.lines.single.costo, 45.5);
      expect(provider.currentTransfer(transfer).lines.single.aceptado, isTrue);
    });

    test('validar un producto lo deja confirmado sin tocar lo recibido', () async {
      final repo = _FakeRepo();
      final provider = _provider(repo);
      await provider.refresh(OtherDocumentKind.traslado);
      final transfer = provider.stateOf(OtherDocumentKind.traslado).items.single;

      final result = await provider.confirmProduct(transfer, transfer.lines.single, '7750001');

      expect(result.isRight, isTrue);
      expect(repo.confirmed, [(1, 10)]);
      final now = provider.stateOf(OtherDocumentKind.traslado).items.single;
      expect(now.lines.single.confirmado, isTrue);
      expect(now.lines.single.aceptado, isFalse);
      expect(now.lines.single.costo, 45.5);
    });

    test('un código de barras equivocado no llama al backend y el traslado no cambia', () async {
      final repo = _FakeRepo();
      final provider = _provider(repo);
      await provider.refresh(OtherDocumentKind.traslado);
      final transfer = provider.stateOf(OtherDocumentKind.traslado).items.single;

      final result = await provider.confirmProduct(transfer, transfer.lines.single, '000');

      expect(result.left.message, 'El código de barras no coincide');
      expect(repo.confirmed, isEmpty);
      expect(provider.stateOf(OtherDocumentKind.traslado).items.single.lines.single.confirmado, isFalse);
    });

    test('mientras se recibe un producto está ocupado y un segundo toque se rechaza', () async {
      final repo = _FakeRepo()..hold = Completer<void>();
      final provider = _provider(repo);
      await provider.refresh(OtherDocumentKind.traslado);
      final transfer = provider.stateOf(OtherDocumentKind.traslado).items.single;
      final line = transfer.lines.single;

      final first = provider.receiveProduct(transfer, line);
      await Future<void>.delayed(Duration.zero);
      expect(provider.isLineBusy(transfer, line), isTrue);

      final second = await provider.receiveProduct(transfer, line);
      expect(second.left.message, 'Ya se está procesando este producto');
      expect(repo.received, hasLength(1));

      repo.hold!.complete();
      expect((await first).isRight, isTrue);
      expect(provider.isLineBusy(transfer, line), isFalse);
    });

    test('si el backend rechaza recibir, el producto sigue pendiente y se muestra el motivo', () async {
      final repo = _FakeRepo()..nextReceive = Either.left(const ValidationFailure('No autorizado'));
      final provider = _provider(repo);
      await provider.refresh(OtherDocumentKind.traslado);
      final transfer = provider.stateOf(OtherDocumentKind.traslado).items.single;

      final result = await provider.receiveProduct(transfer, transfer.lines.single);

      expect(result.left.message, 'No autorizado');
      expect(provider.stateOf(OtherDocumentKind.traslado).items.single.lines.single.aceptado, isFalse);
      expect(provider.isLineBusy(transfer, transfer.lines.single), isFalse);
    });

    test('una sesión vencida al recibir avisa para volver a entrar', () async {
      var expired = 0;
      final repo = _FakeRepo()..nextReceive = Either.left(const AuthenticationFailure('Sesión expirada'));
      final provider = _provider(repo, onSessionExpired: () => expired++);
      await provider.refresh(OtherDocumentKind.traslado);
      final transfer = provider.stateOf(OtherDocumentKind.traslado).items.single;

      await provider.receiveProduct(transfer, transfer.lines.single);

      expect(expired, 1);
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

  group('filtros activos (chips) de las otras listas', () {
    test('"hoy" es como se entra y no cuenta como filtro', () {
      final provider = _provider(_FakeRepo());
      expect(otherDocumentActiveFilters(provider, OtherDocumentKind.guia), isEmpty);
    });

    test('otro rango sale como chip y quitarlo vuelve a hoy', () async {
      final repo = _FakeRepo();
      final provider = _provider(repo);
      await provider.applyFilters(
        OtherDocumentKind.guia,
        OtherDocumentFilters(desde: DateTime(2026, 10, 1), hasta: DateTime(2026, 10, 31)),
      );

      final chips = otherDocumentActiveFilters(provider, OtherDocumentKind.guia);
      expect(chips, hasLength(1));
      expect(chips.single.label, '01 oct. 2026 - 31 oct. 2026');
      // Cada lista tiene los suyos: los de las guías no son los de los traslados.
      expect(otherDocumentActiveFilters(provider, OtherDocumentKind.traslado), isEmpty);

      chips.single.onRemove();
      await Future<void>.delayed(Duration.zero);
      final today = OtherDocumentFilters.hoy(provider.now());
      expect(provider.stateOf(OtherDocumentKind.guia).filters.desde, today.desde);
      expect(provider.stateOf(OtherDocumentKind.guia).filters.hasta, today.hasta);
      expect(otherDocumentActiveFilters(provider, OtherDocumentKind.guia), isEmpty);
    });

    test('sin fechas se llama "Todas las fechas"', () async {
      final provider = _provider(_FakeRepo());
      await provider.applyFilters(OtherDocumentKind.traslado, const OtherDocumentFilters());
      expect(otherDocumentActiveFilters(provider, OtherDocumentKind.traslado).single.label, 'Todas las fechas');
    });

    testWidgets('la lista muestra el chip y el botón cuenta el filtro', (tester) async {
      tester.view.physicalSize = const Size(360 * 3, 780 * 3);
      tester.view.devicePixelRatio = 3;
      tester.platformDispatcher.textScaleFactorTestValue = 0.55;
      addTearDown(() {
        tester.view.reset();
        tester.platformDispatcher.clearTextScaleFactorTestValue();
      });
      final repo = _FakeRepo();
      final provider = _provider(repo);
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<ThemeProvider>(create: (_) => ThemeProvider(storage: _FakeThemeStorage())),
            ChangeNotifierProvider<AuthProvider>.value(value: _auth(_session())),
            ChangeNotifierProvider<OtherDocumentsProvider>.value(value: provider),
          ],
          child: MaterialApp(
            theme: AppTheme.light,
            home: const Scaffold(body: OtherDocumentsView(kind: OtherDocumentKind.guia)),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.widget<Badge>(find.byType(Badge)).isLabelVisible, isFalse);

      await provider.applyFilters(
        OtherDocumentKind.guia,
        OtherDocumentFilters(desde: DateTime(2026, 10, 1), hasta: DateTime(2026, 10, 31)),
      );
      await tester.pumpAndSettle();
      expect(find.text('01 oct. 2026 - 31 oct. 2026'), findsOneWidget);
      expect(find.descendant(of: find.byType(Badge), matching: find.text('1')), findsOneWidget);

      await tester.tap(find.byTooltip('Quitar 01 oct. 2026 - 31 oct. 2026'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('filtro-fechas')), findsNothing);
      expect(repo.calls.last.filters.desde, OtherDocumentFilters.hoy(provider.now()).desde);
    });
  });

  group('OtherDocumentsView', () {
    Future<_FakeRepo> pump(
      WidgetTester tester,
      OtherDocumentKind kind, {
      Set<String> permissions = const {},
      List<String> roles = const [],
      List<WarehouseEntity> warehouses = const [],
      OtherDocumentPageEntity Function(OtherDocumentKind, int)? build,
      Size size = const Size(360, 780),
      ScreenLook? look,
    }) async {
      if (look != null) {
        // Letra real (Roboto), modo claro u oscuro y letra grande del sistema.
        await prepareLook(tester, look);
      } else {
        // Las pruebas dibujan con la fuente Ahem (casi el doble de ancha que una real).
        tester.view.physicalSize = Size(size.width * 3, size.height * 3);
        tester.view.devicePixelRatio = 3;
        tester.platformDispatcher.textScaleFactorTestValue = 0.55;
        addTearDown(() {
          tester.view.reset();
          tester.platformDispatcher.clearTextScaleFactorTestValue();
        });
      }

      final repo = _FakeRepo()..build = build;
      final session = _session(permissions: permissions, roles: roles, warehouses: warehouses);
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<ThemeProvider>(
              create: (_) => ThemeProvider(storage: _FakeThemeStorage()),
            ),
            ChangeNotifierProvider<AuthProvider>.value(value: _auth(session)),
            ChangeNotifierProvider<OtherDocumentsProvider>.value(value: _provider(repo)),
          ],
          child: lookApp(look, home: Scaffold(body: OtherDocumentsView(kind: kind))),
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

    testWidgets('los traslados tienen su botón de PDF', (tester) async {
      await pump(tester, OtherDocumentKind.traslado);
      expect(find.byTooltip('Ver PDF'), findsOneWidget);
    });

    testWidgets('el detalle de un traslado ofrece abrir su PDF', (tester) async {
      await pump(tester, OtherDocumentKind.traslado);

      await tester.tap(find.byTooltip('Ver detalle'));
      await tester.pumpAndSettle();

      expect(find.text('Ver PDF'), findsOneWidget);
    });

    testWidgets('las guías y las notas de crédito tienen su PDF y el de su comprobante', (tester) async {
      await pump(tester, OtherDocumentKind.guia, build: (kind, page) => one(_guide(), kind));

      expect(find.byTooltip('Ver PDF'), findsOneWidget);
      expect(find.byTooltip('Ver comprobante PDF'), findsOneWidget);
    });

    testWidgets('una nota de crédito tiene el mismo par de botones', (tester) async {
      await pump(
        tester,
        OtherDocumentKind.notaCredito,
        build: (kind, page) => one(_creditNote(), kind),
      );

      expect(find.byTooltip('Ver PDF'), findsOneWidget);
      expect(find.byTooltip('Ver comprobante PDF'), findsOneWidget);
    });

    testWidgets('una guía cuya venta no llegó no ofrece PDF', (tester) async {
      await pump(
        tester,
        OtherDocumentKind.guia,
        build: (kind, page) => one({..._guide()..remove('boleta')}, kind),
      );

      expect(find.byTooltip('Ver PDF'), findsNothing);
      expect(find.byTooltip('Ver comprobante PDF'), findsNothing);
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

    group('recibir y validar productos en el detalle del traslado', () {
      const update = {'despachos.transferir.update'};
      // La barra de búsqueda de la lista también es un TextField: este es el del código de barras.
      final barcodeField = find.byWidgetPredicate(
        (w) => w is TextField && w.decoration?.labelText == 'Código de barras',
      );
      const destino = WarehouseEntity(id: 2, name: 'AREQUIPA');
      const origen = WarehouseEntity(id: 1, name: 'LIMA');

      Future<_FakeRepo> openDetail(
        WidgetTester tester, {
        Set<String> permissions = update,
        List<String> roles = const [],
        List<WarehouseEntity> warehouses = const [],
      }) async {
        final repo = await pump(
          tester,
          OtherDocumentKind.traslado,
          permissions: permissions,
          roles: roles,
          warehouses: warehouses,
        );
        await tester.tap(find.byTooltip('Ver detalle'));
        await tester.pumpAndSettle();
        return repo;
      }

      testWidgets('un Ceo Empresa ve "Recibir"; confirma y el producto queda Recibido', (tester) async {
        final repo = await openDetail(tester, roles: const ['Ceo Empresa']);

        expect(find.text('Recibir'), findsOneWidget);
        expect(barcodeField, findsNothing);
        expect(find.text('Pendiente'), findsOneWidget);

        await tester.tap(find.text('Recibir'));
        await tester.pumpAndSettle();
        expect(find.text('¿Desea confirmar que recibió este producto?'), findsOneWidget);
        expect(repo.received, isEmpty);

        await tester.tap(find.widgetWithText(FilledButton, 'Confirmar'));
        await tester.pumpAndSettle();

        expect(repo.received, [(1, 10)]);
        expect(find.text('Se marcó como Recibido'), findsOneWidget);
        expect(find.text('Recibir'), findsNothing);
        expect(find.text('Recibido'), findsWidgets);
        expect(find.text('Pendiente'), findsNothing);
      });

      testWidgets('cancelar la confirmación no recibe nada', (tester) async {
        final repo = await openDetail(tester, roles: const ['Admin Empresa']);

        await tester.tap(find.text('Recibir'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Cancelar'));
        await tester.pumpAndSettle();

        expect(repo.received, isEmpty);
        expect(find.text('Recibir'), findsOneWidget);
      });

      testWidgets('quien tiene el almacén de destino también recibe', (tester) async {
        await openDetail(tester, warehouses: const [destino]);

        expect(find.text('Recibir'), findsOneWidget);
        expect(barcodeField, findsNothing);
      });

      testWidgets('quien solo tiene el almacén de origen valida con el código de barras', (tester) async {
        await openDetail(tester, warehouses: const [origen]);

        expect(find.text('Recibir'), findsNothing);
        expect(barcodeField, findsOneWidget);
        expect(find.text('Código de barras'), findsOneWidget);
      });

      testWidgets('un código de barras equivocado muestra el error y no valida', (tester) async {
        final repo = await openDetail(tester, warehouses: const [origen]);

        await tester.enterText(barcodeField, '000');
        await tester.testTextInput.receiveAction(TextInputAction.done);
        await tester.pumpAndSettle();

        expect(find.text('El código de barras no coincide'), findsOneWidget);
        expect(repo.confirmed, isEmpty);
      });

      testWidgets('el código de barras correcto valida el producto', (tester) async {
        final repo = await openDetail(tester, warehouses: const [origen]);

        await tester.enterText(barcodeField, '7750001');
        await tester.testTextInput.receiveAction(TextInputAction.done);
        await tester.pumpAndSettle();

        expect(repo.confirmed, [(1, 10)]);
        expect(find.text('Se marcó como Validado'), findsOneWidget);
        expect(barcodeField, findsNothing);
        expect(find.textContaining('Validado'), findsWidgets);
      });

      testWidgets('el botón de validar (check) también valida', (tester) async {
        final repo = await openDetail(tester, warehouses: const [origen]);

        await tester.enterText(barcodeField, '7750001');
        await tester.tap(find.byTooltip('Validar'));
        await tester.pumpAndSettle();

        expect(repo.confirmed, [(1, 10)]);
      });

      testWidgets('sin el permiso despachos.transferir.update no hay acciones', (tester) async {
        await openDetail(tester, permissions: const {}, roles: const ['Ceo Empresa']);

        expect(find.text('Recibir'), findsNothing);
        expect(barcodeField, findsNothing);
        expect(find.text('Pendiente'), findsOneWidget);
      });

      testWidgets('un traslado ya recibido no ofrece recibir', (tester) async {
        // La lista ya trae el producto recibido.
        final repo = await pump(
          tester,
          OtherDocumentKind.traslado,
          permissions: update,
          roles: const ['Ceo Empresa'],
          build: (kind, page) => one(_transfer(aceptado: true), kind),
        );
        await tester.tap(find.byTooltip('Ver detalle'));
        await tester.pumpAndSettle();

        expect(find.text('Recibir'), findsNothing);
        expect(repo.received, isEmpty);
      });

      testWidgets('al recibir, la tarjeta de la lista pasa de "Falta recibir" a "Recibido"', (tester) async {
        await openDetail(tester, roles: const ['Ceo Empresa']);

        await tester.tap(find.text('Recibir'));
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(FilledButton, 'Confirmar'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Cerrar'));
        await tester.pumpAndSettle();

        expect(find.text('Falta recibir'), findsNothing);
        expect(find.text('Recibido'), findsOneWidget);
      });

      testWidgets('si el backend rechaza, se avisa y el producto sigue pendiente', (tester) async {
        final repo = await openDetail(tester, roles: const ['Ceo Empresa']);
        repo.nextReceive = Either.left(const ValidationFailure('No autorizado'));

        await tester.tap(find.text('Recibir'));
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(FilledButton, 'Confirmar'));
        await tester.pumpAndSettle();

        expect(find.text('No autorizado'), findsOneWidget);
        expect(find.text('Recibir'), findsOneWidget);
        expect(find.text('Pendiente'), findsOneWidget);
      });
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
      expect(find.text('Motivo de traslado'), findsOneWidget);
      expect(find.text('01 - Venta'), findsOneWidget);
      expect(find.text('Ver PDF'), findsOneWidget);
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
      expect(find.text('Ver PDF'), findsOneWidget);
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

    group('modo oscuro y letra grande en pantallas completas', () {
      OtherDocumentPageEntity Function(OtherDocumentKind, int) withData(OtherDocumentKind kind) {
        return switch (kind) {
          OtherDocumentKind.guia => (k, p) => one(_guide(), k),
          OtherDocumentKind.notaCredito => (k, p) => one(_creditNote(), k),
          _ => (k, p) => OtherDocumentPageEntity(
              items: [otherDocumentFromJson(_transfer(), k)],
              currentPage: 1,
              lastPage: 1,
              total: 1,
            ),
        };
      }

      for (final kind in OtherDocumentKind.values) {
        for (final look in screenLooks) {
          testWidgets('${kind.label}: ${look.label}', (tester) async {
            final handle = tester.ensureSemantics();
            await pump(tester, kind, build: withData(kind), look: look);

            expect(find.byType(AppListCard), findsWidgets);
            await expectLooksRight(tester, look);
            handle.dispose();
          });
        }
      }

      testWidgets('el detalle de un traslado se lee en modo oscuro con letra grande', (tester) async {
        final handle = tester.ensureSemantics();
        const look = ScreenLook(dark: true);
        await pump(
          tester,
          OtherDocumentKind.traslado,
          permissions: const {'despachos.transferir.update'},
          roles: const ['Ceo Empresa'],
          look: look,
        );

        await tester.tap(find.byTooltip('Ver detalle'));
        await tester.pumpAndSettle();

        expect(find.text('Desde'), findsOneWidget);
        expect(find.text('Recibir'), findsOneWidget);
        await expectLooksRight(tester, look);
        handle.dispose();
      });
    });

    group('en tablet: lista a la izquierda y detalle a la derecha', () {
      const tablet = Size(1100, 800);

      for (final kind in OtherDocumentKind.values) {
        testWidgets('${kind.label}: sin selección el panel pide elegir un documento', (tester) async {
          await pump(tester, kind, size: tablet);
          expect(find.text('Selecciona un documento'), findsOneWidget);
        });
      }

      testWidgets('traslados: el detalle sale a la derecha, sin modal, con cada producto', (tester) async {
        await pump(tester, OtherDocumentKind.traslado, size: tablet);

        await tester.tap(find.text('T001-0007'));
        await tester.pumpAndSettle();

        expect(find.text('Selecciona un documento'), findsNothing);
        expect(find.text('Desde'), findsOneWidget);
        expect(find.text('SUBWOOFER 12"'), findsOneWidget);
        expect(find.byType(Dialog), findsNothing);
        expect(find.byType(BottomSheet), findsNothing);
        expect(
          tester.getTopLeft(find.text('Desde')).dx,
          greaterThan(tester.getTopLeft(find.text('T001-0007').first).dx + 300),
        );
      });

      testWidgets('la tarjeta elegida se resalta y el panel ofrece "Ver PDF"', (tester) async {
        await pump(tester, OtherDocumentKind.traslado, size: tablet);
        await tester.tap(find.text('T001-0007'));
        await tester.pumpAndSettle();

        expect(tester.widget<AppListCard>(find.byType(AppListCard).first).selected, isTrue);
        expect(find.text('Ver PDF'), findsOneWidget);
        expect(find.text('Cerrar'), findsOneWidget);
      });

      testWidgets('traslados: recibir un producto desde el panel lo marca Recibido y el panel sigue abierto', (tester) async {
        final repo = await pump(
          tester,
          OtherDocumentKind.traslado,
          permissions: const {'despachos.transferir.update'},
          roles: const ['Ceo Empresa'],
          size: tablet,
        );
        await tester.tap(find.text('T001-0007'));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Recibir'));
        await tester.pumpAndSettle();
        // La confirmación sí es un diálogo, encima del panel.
        expect(find.text('¿Desea confirmar que recibió este producto?'), findsOneWidget);
        await tester.tap(find.widgetWithText(FilledButton, 'Confirmar'));
        await tester.pumpAndSettle();

        expect(repo.received, [(1, 10)]);
        expect(find.text('Recibir'), findsNothing);
        expect(find.text('Desde'), findsOneWidget, reason: 'el detalle sigue a la vista');
      });

      testWidgets('guías: el panel ofrece el PDF de la guía y el de su comprobante', (tester) async {
        await pump(
          tester,
          OtherDocumentKind.guia,
          build: (kind, page) => one(_guide(), kind),
          size: tablet,
        );
        await tester.tap(find.byTooltip('Ver detalle'));
        await tester.pumpAndSettle();

        expect(find.text('Ver PDF'), findsOneWidget);
        expect(find.byTooltip('Ver comprobante PDF'), findsOneWidget);
        expect(find.byType(Dialog), findsNothing);
      });

      testWidgets('eliminar un traslado abierto en el panel lo vacía', (tester) async {
        final repo = await pump(
          tester,
          OtherDocumentKind.traslado,
          permissions: const {'transferir-stock.destroy'},
          size: tablet,
        );
        await tester.tap(find.text('T001-0007'));
        await tester.pumpAndSettle();
        expect(find.text('Desde'), findsOneWidget);

        await tester.tap(find.byTooltip('Eliminar'));
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(FilledButton, 'Eliminar'));
        await tester.pumpAndSettle();

        expect(repo.deleted, [1]);
        expect(find.text('Desde'), findsNothing);
        expect(find.text('Selecciona un documento'), findsOneWidget);
      });

      testWidgets('en celular nada cambia: el detalle abre como modal', (tester) async {
        await pump(tester, OtherDocumentKind.traslado);

        await tester.tap(find.text('T001-0007'));
        await tester.pumpAndSettle();

        expect(find.text('Selecciona un documento'), findsNothing);
        expect(find.byType(BottomSheet), findsOneWidget);
      });
    });
  });
}
