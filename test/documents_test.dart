import 'dart:convert';
import 'dart:typed_data';
import 'package:app_novik/core/errors/failures.dart';
import 'package:app_novik/core/utils/either.dart';
import 'package:app_novik/data/datasources/theme_local_datasource.dart';
import 'package:app_novik/data/datasources/document_remote_datasource.dart';
import 'package:app_novik/data/models/document_model.dart';
import 'package:app_novik/domain/entities/company_entity.dart';
import 'package:app_novik/domain/entities/saved_credentials_entity.dart';
import 'package:app_novik/domain/entities/document_entity.dart';
import 'package:app_novik/domain/entities/other_document_entity.dart';
import 'package:app_novik/domain/entities/session_context_entity.dart';
import 'package:app_novik/domain/entities/user_entity.dart';
import 'package:app_novik/domain/repositories/auth_repository.dart';
import 'package:app_novik/domain/repositories/document_repository.dart';
import 'package:app_novik/domain/repositories/other_document_repository.dart';
import 'package:app_novik/domain/usecases/auth_usecases.dart';
import 'package:app_novik/domain/usecases/document_usecases.dart';
import 'package:app_novik/domain/usecases/other_document_usecases.dart';
import 'package:app_novik/presentation/pages/documents_page.dart';
import 'package:app_novik/presentation/pdf/receipt_pdf.dart';
import 'package:app_novik/presentation/providers/auth_provider.dart';
import 'package:app_novik/presentation/providers/documents_provider.dart';
import 'package:app_novik/presentation/providers/other_documents_provider.dart';
import 'package:app_novik/presentation/providers/theme_provider.dart';
import 'package:app_novik/theme/app_theme.dart';
import 'package:app_novik/presentation/widgets/document_filters.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// Las otras listas de Documentos (traslados, guías...), con un traslado de ejemplo.
class _FakeOtherRepository implements OtherDocumentRepository {
  final List<OtherDocumentKind> pedidas = [];

  @override
  Future<Either<Failure, OtherDocumentPageEntity>> getPage({
    required int companyId,
    required OtherDocumentKind kind,
    required OtherDocumentFilters filters,
    int? number,
    int page = 1,
    int pageSize = 20,
  }) async {
    pedidas.add(kind);
    return Either.right(const OtherDocumentPageEntity(
      items: [
        OtherDocumentEntity(
          kind: OtherDocumentKind.traslado,
          id: 1,
          numero: 'T001-0007',
          usuario: 'ANA',
          desde: 'LIMA',
          hacia: 'AREQUIPA',
          lines: [OtherDocumentLine(cantidad: 3, name: 'SUBWOOFER')],
        ),
      ],
      currentPage: 1,
      lastPage: 1,
      total: 1,
    ));
  }

  @override
  Future<Either<Failure, void>> deleteTransfer(int id) async => Either.rightVoid();
}

class _Call {
  final DocumentKind kind;
  final String? search;
  final DocumentFilters filters;
  final int page;

  _Call(this.kind, this.search, this.filters, this.page);
}

class _FakeDocumentRepository implements DocumentRepository {
  final List<_Call> calls = [];
  final List<String> actions = [];
  Either<Failure, DocumentPageEntity>? next;

  @override
  Future<Either<Failure, DocumentPageEntity>> getDocuments({
    required int companyId,
    required DocumentKind kind,
    String? search,
    required DocumentFilters filters,
    int page = 1,
    int pageSize = 20,
  }) async {
    calls.add(_Call(kind, search, filters, page));
    return next ??
        Either.right(DocumentPageEntity(
          items: [
            DocumentEntity(id: page, kind: kind, numero: 'V001-000$page', comprobante: 'Nota de venta'),
          ],
          currentPage: page,
          lastPage: 2,
          total: 2,
          totalSoles: 150.5,
          totalDolares: 20,
        ));
  }

  @override
  Future<Either<Failure, DownloadedFile>> exportDocuments({
    required int companyId,
    required DocumentKind kind,
    String? search,
    required DocumentFilters filters,
  }) async {
    actions.add('export:${kind.name}');
    return Either.right(DownloadedFile(name: 'Ventas.xlsx', bytes: Uint8List.fromList([1, 2, 3])));
  }

  @override
  Future<Either<Failure, DocumentFilterCatalogs>> getFilterCatalogs(int companyId) async {
    actions.add('catalogs');
    return Either.right(const DocumentFilterCatalogs(
      sucursales: [(id: 1, name: 'LIMA'), (id: 2, name: 'AREQUIPA')],
      vendedores: [(id: 9, name: 'ANA'), (id: 10, name: 'LUIS')],
      clientes: [(id: 5, name: 'ACME SAC')],
    ));
  }

  @override
  Future<Either<Failure, void>> deleteSale(int id) async {
    actions.add('deleteSale:$id');
    return Either.rightVoid();
  }

  @override
  Future<Either<Failure, void>> deleteQuote(int id) async {
    actions.add('deleteQuote:$id');
    return Either.rightVoid();
  }

  @override
  Future<Either<Failure, void>> createCreditNote({
    required int boletaId,
    required String descripcion,
    required DateTime fechaEmision,
  }) async {
    actions.add('creditNote:$boletaId:$descripcion');
    return Either.rightVoid();
  }

  @override
  Future<Either<Failure, DownloadedFile>> downloadCdr({
    required int boletaId,
    required String name,
  }) async {
    actions.add('cdr:$boletaId');
    return Either.right(DownloadedFile(name: name, bytes: Uint8List(0)));
  }

  @override
  Future<Either<Failure, Uint8List>> getCompanyLogo() async {
    actions.add('logo');
    return Either.left(const ServerFailure('sin logo'));
  }
}

final _now = DateTime(2026, 10, 28, 15, 30);

SessionContextEntity _session({
  int companyId = 7,
  List<String> roles = const [],
  Set<String> permissions = const {},
}) =>
    SessionContextEntity(
      user: const UserEntity(id: 9, name: 'Ana', usuario: 'ana'),
      company: CompanyEntity(id: companyId, razonSocial: 'ACME'),
      modules: const [],
      permissions: permissions,
      roles: roles,
      warehouses: const [],
    );

DocumentsProvider _provider(_FakeDocumentRepository repo, {SessionContextEntity? session}) {
  return DocumentsProvider(
    getDocumentsUseCase: GetDocumentsUseCase(repository: repo),
    exportDocumentsUseCase: ExportDocumentsUseCase(repository: repo),
    getFilterCatalogsUseCase: GetDocumentFilterCatalogsUseCase(repository: repo),
    deleteDocumentUseCase: DeleteDocumentUseCase(repository: repo),
    createCreditNoteUseCase: CreateCreditNoteUseCase(repository: repo),
    downloadCdrUseCase: DownloadCdrUseCase(repository: repo),
    getCompanyLogoUseCase: GetCompanyLogoUseCase(repository: repo),
    now: () => _now,
  )..syncSession(session ?? _session());
}

DocumentEntity _sale({
  int id = 1,
  bool activo = true,
  DocumentBoletaEntity? boleta,
  DocumentKind kind = DocumentKind.venta,
}) =>
    DocumentEntity(
      id: id,
      kind: kind,
      numero: boleta == null ? 'V001-0001' : 'B001-00001',
      comprobante: boleta == null ? 'Nota de venta' : 'Boleta',
      activo: activo,
      boleta: boleta,
    );

const _boleta = DocumentBoletaEntity(id: 44, tipo: 'b', tieneCdr: true);

/// Cliente HTTP falso que guarda lo último que se le pidió.
class _Http {
  late http.Request last;
  final List<http.Request> all = [];
  String body = '{}';
  int status = 200;

  MockClient get client => MockClient((request) async {
        last = request;
        all.add(request);
        return http.Response(body, status, headers: {'content-type': 'application/json'});
      });
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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('documentFromJson', () {
    test('arma el número de boleta y de factura como la web', () {
      expect(
        documentNumber({'boleta': {'tipo': 'b', 'serie': 1, 'numero': 123}}, DocumentKind.venta),
        'B001-00123',
      );
      expect(
        documentNumber({'boleta': {'tipo': 'f', 'serie': 1, 'numero': 45}}, DocumentKind.venta),
        'F001-0045',
      );
      expect(documentNumber({'nro_documento': 12}, DocumentKind.venta), 'V001-0012');
      expect(documentNumber({'nro_documento': 34}, DocumentKind.cotizacion), 'C001-0034');
    });

    test('lee una venta con sus productos y pagos', () {
      final d = documentFromJson({
        'id': 9,
        'nro_documento': 16,
        'estado': false,
        'total_soles': '51.50',
        'total_dolares': 0,
        'created_at': '2026-10-22T15:30:00.000000Z',
        'client': {'razon_social': '', 'name': 'GLADIS', 'last_name': 'PUCHOC'},
        'vendedor': {'name': 'LINDA'},
        'user': {'name': 'ADMIN'},
        'warehouse': {'name': 'LIMA'},
        'anulado_por': {'name': 'JEFE'},
        'products': [
          {
            'name': 'TORNILLO',
            'codigo': '8809',
            'brand': {'name': 'ANTONIO'},
            'pivot': {
              'cantidad': 2,
              'precio': '17.50',
              'subtotal_con_dto': '35.00',
              'monto_dto': '1.5',
              'dolares': 0,
            },
          },
        ],
        'payment_methods': [
          {
            'name': 'EFECTIVO',
            'pivot': {'monto': '51.50'},
          },
        ],
      }, DocumentKind.venta);

      expect(d.numero, 'V001-0016');
      expect(d.comprobante, 'Nota de venta');
      expect(d.activo, isFalse);
      expect(d.cliente, 'GLADIS PUCHOC');
      expect(d.vendedor, 'LINDA');
      expect(d.monto, 51.5);
      expect(d.simboloMoneda, 'S/');
      expect(d.anuladoPor, 'JEFE');
      expect(d.items.single.cantidad, 2);
      expect(d.items.single.subtotal, 35);
      expect(d.items.single.descuento, 1.5);
      expect(d.descuento, 1.5);
      expect(d.items.single.marca, 'ANTONIO');
      expect(d.pagos.single.metodo, 'EFECTIVO');
      expect(d.pagos.single.monto, 51.5);
      expect(d.boleta, isNull);
      expect(d.sePuedeEliminar, isFalse); // ya está eliminada
    });

    test('el vendedor es el ejecutivo del cliente si lo hay, con su teléfono y correo', () {
      final d = documentFromJson({
        'id': 1,
        'nro_documento': 1,
        'total_soles': 0,
        'total_dolares': 100,
        'tipo_de_cambio': '3.42',
        'ejecutivo_de_la_venta': {'name': 'EJECUTIVO', 'telefono': '999', 'email': 'e@x.pe'},
        'vendedor': {'name': 'OTRO', 'telefono': '111'},
        'boleta': {'id': 5, 'tipo': 'f', 'serie': 1, 'numero': 7},
      }, DocumentKind.venta);

      expect(d.vendedor, 'EJECUTIVO');
      expect(d.vendedorTelefono, '999');
      expect(d.vendedorEmail, 'e@x.pe');
      expect(d.esDolares, isTrue);
      expect(d.monto, 100);
      expect(d.tipoCambio, 3.42);
      expect(d.comprobante, 'Factura');
      expect(d.boleta!.esFactura, isTrue);
    });

    test('sin ejecutivo sale el vendedor elegido o, si no, quien registró', () {
      final d = documentFromJson({
        'id': 1,
        'user': {'name': 'CAJERO', 'telefono': '222'},
      }, DocumentKind.venta);
      expect(d.vendedor, 'CAJERO');
      expect(d.vendedorTelefono, '222');
    });

    test('lee los datos que salen en el comprobante', () {
      final d = documentFromJson({
        'id': 3,
        'nro_documento': 5,
        'client': {
          'dni_ruc': '20123456789',
          'razon_social': 'ACME SAC',
          'direccion': 'AV. UNO 1',
          'adresses': [
            {'predeterminado': 0, 'direccion': 'OTRA'},
            {'predeterminado': 1, 'direccion': 'AV. PRINCIPAL 123'},
          ],
        },
        'warehouse': {
          'name': 'LIMA',
          'datos': 1,
          'datos_vendedor': 0,
          'direccion': 'JR. ALMACEN 5',
          'telefono': '01-555',
          'comentarios': 'No se aceptan cambios',
        },
        'boleta': {
          'id': 8,
          'tipo': 'b',
          'serie': 1,
          'numero': 9,
          'cdr': 'cdr/R-1.zip',
          'guia': {'id': 1},
          'nota_credito': null,
        },
      }, DocumentKind.venta);

      expect(d.clienteDocumento, '20123456789');
      expect(d.clienteDireccion, 'AV. PRINCIPAL 123');
      expect(d.datosAlmacen!.usaDatos, isTrue);
      expect(d.datosAlmacen!.usaDatosVendedor, isFalse);
      expect(d.datosAlmacen!.direccion, 'JR. ALMACEN 5');
      expect(d.datosAlmacen!.comentarios, 'No se aceptan cambios');
      expect(d.boleta!.id, 8);
      expect(d.boleta!.tieneCdr, isTrue);
      expect(d.boleta!.tieneGuia, isTrue);
      expect(d.boleta!.tieneNotaCredito, isFalse);
      // Con boleta electrónica no se elimina: se anula con nota de crédito.
      expect(d.sePuedeEliminar, isFalse);
      expect(d.sePuedeAnularConNotaCredito, isTrue);
    });

    test('una cotización usa la fecha de emisión y dice si reservó stock', () {
      final d = documentFromJson({
        'id': 2,
        'nro_documento': 5,
        'estado': true,
        'reservar_stock': 1,
        'vencimiento_stock': '2026-11-05T05:00:00.000000Z',
        'fecha_emision': '2026-10-20T10:00:00.000000Z',
        'created_at': '2026-10-01T10:00:00.000000Z',
      }, DocumentKind.cotizacion);

      expect(d.comprobante, 'Cotización');
      expect(d.reservado, isTrue);
      expect(d.vencimientoStock, isNotNull);
      expect(d.creado!.toUtc().day, 20);
      expect(d.boleta, isNull);
      expect(d.sePuedeEliminar, isTrue);
      expect(d.sePuedeAnularConNotaCredito, isFalse);
    });

    test('la página trae los totales en soles y dólares de todo lo filtrado', () {
      final page = DocumentPageModel.fromJson({
        'current_page': 1,
        'last_page': 3,
        'total': 120,
        'total_soles': 12345.6,
        'total_dolares': '99.5',
        'data': [
          {'id': 1, 'nro_documento': 1},
        ],
      }, DocumentKind.venta);

      expect(page.total, 120);
      expect(page.hasMore, isTrue);
      expect(page.totalSoles, 12345.6);
      expect(page.totalDolares, 99.5);
    });

    test('las opciones de los filtros salen de {id, name} o del cliente con su etiqueta', () {
      final options = filterOptionsFromJson([
        {'id': 1, 'name': 'LIMA'},
        {'id': 2, 'display_label': 'ACME - ACME SAC', 'name': 'ACME'},
        {'id': 3, 'first_name': 'ANA', 'last_name': 'PEREZ'},
        {'name': 'sin id'},
      ]);
      expect(options.map((o) => o.name), ['LIMA', 'ACME - ACME SAC', 'ANA PEREZ']);
    });
  });

  group('DocumentFilters', () {
    test('al entrar son los documentos de hoy y no hay nada que restablecer', () {
      final f = DocumentFilters.hoy(_now);
      expect(f.desde, DateTime(2026, 10, 28));
      expect(f.hasta, DateTime(2026, 10, 28));
      expect(f.isActive(_now), isFalse);
    });

    test('copyWith conserva lo no indicado y permite poner null', () {
      final f = DocumentFilters.hoy(_now).copyWith(tipo: DocumentTipo.boleta, sucursales: [1]);
      expect(f.tipo, DocumentTipo.boleta);
      expect(f.desde, DateTime(2026, 10, 28));
      expect(f.isActive(_now), isTrue);

      final todas = f.copyWith(desde: null, hasta: null);
      expect(todas.desde, isNull);
      expect(todas.tipo, DocumentTipo.boleta);
      expect(todas.isActive(_now), isTrue); // "todas las fechas" ya no es como se entra

      expect(f.copyWith(tipo: null).tipo, isNull);
    });
  });

  group('rango de fechas de los filtros', () {
    test('se muestra como la web y sin fechas dice "Todas las fechas"', () {
      expect(documentFilterRange(DocumentFilters.hoy(_now)), '28 oct. 2026 - 28 oct. 2026');
      expect(
        documentFilterRange(DocumentFilters.hoy(_now).copyWith(desde: DateTime(2026, 1, 5))),
        '05 ene. 2026 - 28 oct. 2026',
      );
      expect(
        documentFilterRange(DocumentFilters.hoy(_now).copyWith(desde: null, hasta: null)),
        'Todas las fechas',
      );
    });
  });

  group('DocumentsProvider', () {
    test('arranca con las ventas de hoy, como la web, y trae los totales', () async {
      final repo = _FakeDocumentRepository();
      final provider = _provider(repo);

      await provider.ensureLoaded();

      final call = repo.calls.single;
      expect(call.kind, DocumentKind.venta);
      expect(call.filters.desde, DateTime(2026, 10, 28));
      expect(call.filters.hasta, DateTime(2026, 10, 28));
      expect(provider.filtersActive, isFalse);
      expect(provider.totalSoles, 150.5);
      expect(provider.totalDolares, 20);
    });

    test('cada lista tiene sus propios filtros', () async {
      final repo = _FakeDocumentRepository();
      final provider = _provider(repo);
      await provider.applyFilters(
        provider.filters.copyWith(tipo: DocumentTipo.boleta, estado: DocumentEstado.activos),
      );
      expect(repo.calls.last.filters.tipo, DocumentTipo.boleta);
      expect(provider.filtersActive, isTrue);

      await provider.selectKind(DocumentKind.cotizacion);
      expect(repo.calls.last.kind, DocumentKind.cotizacion);
      expect(repo.calls.last.filters.tipo, isNull);
      expect(provider.filtersActive, isFalse);

      await provider.applyFilters(
        provider.filters.copyWith(estadoCotizacion: DocumentQuoteState.pendientes),
      );
      await provider.selectKind(DocumentKind.venta);
      // Al volver a ventas siguen sus filtros.
      expect(repo.calls.last.filters.tipo, DocumentTipo.boleta);
      expect(provider.filters.estadoCotizacion, DocumentQuoteState.todas);
    });

    test('restablecer vuelve a los documentos de hoy', () async {
      final repo = _FakeDocumentRepository();
      final provider = _provider(repo);
      await provider.applyFilters(provider.filters.copyWith(desde: null, hasta: null, sucursales: [1]));
      expect(provider.filtersActive, isTrue);

      await provider.resetFilters();

      expect(provider.filtersActive, isFalse);
      expect(repo.calls.last.filters.sucursales, isEmpty);
      expect(repo.calls.last.filters.desde, DateTime(2026, 10, 28));
    });

    test('buscar por número manda la búsqueda', () async {
      final repo = _FakeDocumentRepository();
      final provider = _provider(repo);
      await provider.ensureLoaded();

      await provider.setSearch(' 123 ');

      expect(repo.calls.last.search, '123');
    });

    test('loadMore pide la página siguiente y se detiene al final', () async {
      final repo = _FakeDocumentRepository();
      final provider = _provider(repo);
      await provider.refresh();
      await provider.loadMore();
      await provider.loadMore();

      expect(provider.items, hasLength(2));
      expect(repo.calls.map((c) => c.page), [1, 2]);
    });

    test('cambiar de empresa descarta todo, filtros incluidos', () async {
      final repo = _FakeDocumentRepository();
      final provider = _provider(repo);
      await provider.applyFilters(provider.filters.copyWith(sucursales: [1]));
      await provider.ensureCatalogs();

      provider.syncSession(_session(companyId: 8));

      expect(provider.items, isEmpty);
      expect(provider.kind, DocumentKind.venta);
      expect(provider.filtersActive, isFalse);
      expect(provider.catalogsLoaded, isFalse);
    });

    test('un error en la primera página queda en error', () async {
      final repo = _FakeDocumentRepository()
        ..next = Either.left(const NetworkFailure('Sin conexión a internet'));
      final provider = _provider(repo);

      await provider.refresh();

      expect(provider.error, 'Sin conexión a internet');
      expect(provider.items, isEmpty);
    });

    test('los catálogos se piden una vez', () async {
      final repo = _FakeDocumentRepository();
      final provider = _provider(repo);

      await provider.ensureCatalogs();
      await provider.ensureCatalogs();

      expect(repo.actions.where((a) => a == 'catalogs'), hasLength(1));
      expect(provider.catalogs.vendedores, hasLength(2));
    });

    test('un vendedor sin permiso para ver a los demás solo se ve a sí mismo', () async {
      final repo = _FakeDocumentRepository();
      final provider = _provider(repo, session: _session(roles: ['Vendedor']));
      await provider.ensureCatalogs();
      expect(provider.catalogs.vendedores.map((v) => v.name), ['ANA']);

      final jefe = _provider(
        repo,
        session: _session(roles: ['Vendedor'], permissions: {'reportes.ventas.ver-otros-vendedores'}),
      );
      await jefe.ensureCatalogs();
      expect(jefe.catalogs.vendedores, hasLength(2));
    });

    test('exportar descarga lo que se ve', () async {
      final repo = _FakeDocumentRepository();
      final provider = _provider(repo);

      final result = await provider.exportCurrent();

      expect(result.isRight, isTrue);
      expect(result.right.name, 'Ventas.xlsx');
      expect(repo.actions, contains('export:venta'));
      expect(provider.exporting, isFalse);
    });

    test('eliminar una venta la elimina y recarga la lista', () async {
      final repo = _FakeDocumentRepository();
      final provider = _provider(repo);
      await provider.refresh();

      final result = await provider.deleteDocument(_sale(id: 5));

      expect(result.isRight, isTrue);
      expect(repo.actions, contains('deleteSale:5'));
      expect(repo.calls, hasLength(2)); // recargó
    });

    test('eliminar una cotización usa su propio endpoint', () async {
      final repo = _FakeDocumentRepository();
      final provider = _provider(repo);

      await provider.deleteDocument(_sale(id: 6, kind: DocumentKind.cotizacion));

      expect(repo.actions, contains('deleteQuote:6'));
    });

    test('una boleta no se elimina: se anula con nota de crédito', () async {
      final repo = _FakeDocumentRepository();
      final provider = _provider(repo);

      final result = await provider.deleteDocument(_sale(boleta: _boleta));

      expect(result.isLeft, isTrue);
      expect(result.left, isA<ValidationFailure>());
      expect(repo.actions, isEmpty);
    });

    test('la nota de crédito pide descripción y solo sobre boletas activas sin nota', () async {
      final repo = _FakeDocumentRepository();
      final provider = _provider(repo);

      final sinTexto = await provider.createCreditNote(
        document: _sale(boleta: _boleta),
        descripcion: '   ',
        fechaEmision: _now,
      );
      expect(sinTexto.isLeft, isTrue);

      final sinBoleta = await provider.createCreditNote(
        document: _sale(),
        descripcion: 'Error',
        fechaEmision: _now,
      );
      expect(sinBoleta.isLeft, isTrue);

      final conNota = await provider.createCreditNote(
        document: _sale(boleta: const DocumentBoletaEntity(id: 1, tipo: 'b', tieneNotaCredito: true)),
        descripcion: 'Error',
        fechaEmision: _now,
      );
      expect(conNota.isLeft, isTrue);
      expect(repo.actions, isEmpty);

      final ok = await provider.createCreditNote(
        document: _sale(boleta: _boleta),
        descripcion: ' Error en el RUC ',
        fechaEmision: _now,
      );
      expect(ok.isRight, isTrue);
      expect(repo.actions, ['creditNote:44:Error en el RUC']);
    });

    test('el CDR solo se descarga si la boleta lo tiene', () async {
      final repo = _FakeDocumentRepository();
      final provider = _provider(repo);

      final sin = await provider.downloadCdr(_sale(boleta: const DocumentBoletaEntity(id: 1, tipo: 'b')));
      expect(sin.isLeft, isTrue);

      final con = await provider.downloadCdr(_sale(boleta: _boleta));
      expect(con.right.name, 'CDR-B001-00001.zip');
    });

    test('el logo se pide una sola vez y es opcional', () async {
      final repo = _FakeDocumentRepository();
      final provider = _provider(repo);

      expect(await provider.companyLogo(), isNull);
      expect(await provider.companyLogo(), isNull);
      expect(repo.actions.where((a) => a == 'logo'), hasLength(1));
    });
  });

  group('DocumentRemoteDataSourceImpl (lo que recibe el backend)', () {
    final all = DocumentFilters.hoy(_now).copyWith(
      sucursales: [1, 2],
      vendedores: [9],
      clientes: [5],
      tipo: DocumentTipo.notaVenta,
      estado: DocumentEstado.eliminados,
    );

    test('ventas: fecha_desde, sucursales[], tipo_documento y estado_documento', () async {
      final http = _Http()..body = jsonEncode({'data': [], 'current_page': 1, 'last_page': 1, 'total': 0});
      final source = DocumentRemoteDataSourceImpl(client: http.client);

      await source.getDocuments(
        token: 't',
        companyId: 7,
        kind: DocumentKind.venta,
        filters: all,
        page: 2,
        pageSize: 20,
      );

      final q = http.last.url.queryParametersAll;
      expect(http.last.url.path, endsWith('/api/ventas'));
      expect(http.last.headers['Authorization'], 'Bearer t');
      expect(q['company_id'], ['7']);
      expect(q['pagination[current]'], ['2']);
      expect(q['fecha_desde'], ['2026-10-28']);
      expect(q['fecha_hasta'], ['2026-10-28']);
      expect(q['sucursales[]'], ['1', '2']);
      expect(q['vendedores[]'], ['9']);
      expect(q['clientes[]'], ['5']);
      expect(q['tipo_documento'], ['nt']);
      expect(q['estado_documento'], ['eliminados']);
      // Los filtros de la lista de cotizaciones no viajan.
      expect(q.containsKey('estado_cotizacion'), isFalse);
    });

    test('cotizaciones: estado_cotizacion y reserva', () async {
      final http = _Http()..body = jsonEncode({'data': [], 'current_page': 1, 'last_page': 1, 'total': 0});
      final source = DocumentRemoteDataSourceImpl(client: http.client);

      await source.getDocuments(
        token: 't',
        companyId: 7,
        kind: DocumentKind.cotizacion,
        filters: DocumentFilters.hoy(_now).copyWith(
          estadoCotizacion: DocumentQuoteState.procesadas,
          reserva: DocumentReserve.reservadas,
          tipo: DocumentTipo.boleta,
        ),
        page: 1,
        pageSize: 20,
      );

      final q = http.last.url.queryParametersAll;
      expect(http.last.url.path, endsWith('/api/cotizaciones'));
      expect(q['estado_cotizacion'], ['procesadas']);
      expect(q['reserva'], ['reservadas']);
      expect(q.containsKey('tipo_documento'), isFalse);
    });

    test('sin fechas no se manda ningún rango', () async {
      final http = _Http()..body = jsonEncode({'data': []});
      final source = DocumentRemoteDataSourceImpl(client: http.client);

      await source.getDocuments(
        token: 't',
        companyId: 7,
        kind: DocumentKind.venta,
        filters: DocumentFilters.hoy(_now).copyWith(desde: null, hasta: null),
        page: 1,
        pageSize: 20,
      );

      expect(http.last.url.queryParametersAll.containsKey('fecha_desde'), isFalse);
    });

    test('buscar por número manda solo el número, sin filtros', () async {
      final http = _Http()..body = jsonEncode({'data': []});
      final source = DocumentRemoteDataSourceImpl(client: http.client);

      await source.getDocuments(
        token: 't',
        companyId: 7,
        kind: DocumentKind.venta,
        search: '1234',
        filters: all,
        page: 1,
        pageSize: 20,
      );

      final q = http.last.url.queryParametersAll;
      expect(q['search_input'], ['1234']);
      expect(q.containsKey('fecha_desde'), isFalse);
      expect(q.containsKey('sucursales[]'), isFalse);
    });

    test('exportar ventas: POST /ventas/export con los mismos filtros y sin empresa', () async {
      final http = _Http();
      final source = DocumentRemoteDataSourceImpl(client: http.client);

      final file = await source.exportDocuments(
        token: 't',
        companyId: 7,
        kind: DocumentKind.venta,
        filters: all,
      );

      expect(http.last.method, 'POST');
      expect(http.last.url.path, endsWith('/api/ventas/export'));
      expect(http.last.url.queryParametersAll['tipo_documento'], ['nt']);
      expect(http.last.url.queryParametersAll.containsKey('company_id'), isFalse);
      expect(file.name, 'Ventas.xlsx');
    });

    test('exportar cotizaciones pendientes: POST /cotizaciones/export con la empresa', () async {
      final http = _Http();
      final source = DocumentRemoteDataSourceImpl(client: http.client);

      final file = await source.exportDocuments(
        token: 't',
        companyId: 7,
        kind: DocumentKind.cotizacion,
        filters: DocumentFilters.hoy(_now).copyWith(estadoCotizacion: DocumentQuoteState.pendientes),
      );

      expect(http.last.method, 'POST');
      expect(http.last.url.path, endsWith('/api/cotizaciones/export'));
      expect(http.last.url.queryParametersAll['company_id'], ['7']);
      expect(http.last.url.queryParametersAll['estado_cotizacion'], ['pendientes']);
      expect(file.name, 'Cotizaciones pendientes.xlsx');
    });

    test('eliminar una venta es un PUT con estado false', () async {
      final http = _Http();
      final source = DocumentRemoteDataSourceImpl(client: http.client);

      await source.deleteSale('t', 12);

      expect(http.last.method, 'PUT');
      expect(http.last.url.path, endsWith('/api/ventas/12'));
      expect(jsonDecode(http.last.body), {'estado': false});
    });

    test('eliminar una cotización es un DELETE', () async {
      final http = _Http();
      final source = DocumentRemoteDataSourceImpl(client: http.client);

      await source.deleteQuote('t', 3);

      expect(http.last.method, 'DELETE');
      expect(http.last.url.path, endsWith('/api/cotizaciones/3'));
    });

    test('la nota de crédito manda boleta, descripción y fecha', () async {
      final http = _Http();
      final source = DocumentRemoteDataSourceImpl(client: http.client);

      await source.createCreditNote(
        token: 't',
        boletaId: 44,
        descripcion: 'Error en el RUC',
        fechaEmision: DateTime(2026, 10, 27),
      );

      expect(http.last.method, 'POST');
      expect(http.last.url.path, endsWith('/api/nota-credito'));
      expect(jsonDecode(http.last.body), {
        'boleta_id': 44,
        'descripcion': 'Error en el RUC',
        'fecha_emision': '2026-10-27',
      });
    });

    test('los filtros piden sucursales, ejecutivos (rol Vendedor) y clientes de mi cartera', () async {
      final http = _Http()..body = jsonEncode([{'id': 1, 'name': 'X'}]);
      final source = DocumentRemoteDataSourceImpl(client: http.client);

      final catalogs = await source.getFilterCatalogs('t', 7);

      final urls = http.all.map((r) => r.url).toList();
      expect(urls.any((u) => u.path.endsWith('/almacenes/list')), isTrue);
      final users = urls.firstWhere((u) => u.path.endsWith('/usuarios/list'));
      expect(users.queryParametersAll['roles[]'], ['Vendedor']);
      final clients = urls.firstWhere((u) => u.path.endsWith('/clientes/list'));
      expect(clients.queryParametersAll['solo_mi_cartera'], ['true']);
      expect(catalogs.sucursales.single.name, 'X');
    });

    test('un 422 del servidor llega como error de validación con su mensaje', () async {
      final http = _Http()
        ..status = 422
        ..body = jsonEncode({'error': 'Nota de crédito rechazada por SUNAT'});
      final source = DocumentRemoteDataSourceImpl(client: http.client);

      expect(
        () => source.createCreditNote(
          token: 't',
          boletaId: 1,
          descripcion: 'x',
          fechaEmision: _now,
        ),
        throwsA(predicate((e) => e.toString().contains('Nota de crédito rechazada por SUNAT'))),
      );
    });
  });

  group('comprobante en PDF', () {
    const company = CompanyEntity(
      id: 1,
      razonSocial: 'ACME SAC',
      ruc: '20123456789',
      direccion: 'AV. EMPRESA 1',
      telefono: '01-111',
      email: 'ventas@acme.pe',
      web: 'acme.pe',
      igv: 0.18,
    );

    DocumentEntity doc({
      DocumentWarehouseEntity? almacen,
      DocumentBoletaEntity? boleta,
      DocumentKind kind = DocumentKind.venta,
      bool dolares = false,
    }) =>
        DocumentEntity(
          id: 1,
          kind: kind,
          numero: boleta == null ? 'V001-0001' : 'B001-00001',
          comprobante: 'x',
          cliente: 'ACME',
          clienteDocumento: '20123456789',
          vendedor: 'ANA',
          vendedorTelefono: '999',
          vendedorEmail: 'ana@acme.pe',
          almacen: 'LIMA',
          datosAlmacen: almacen,
          esDolares: dolares,
          tipoCambio: dolares ? 3.4 : null,
          boleta: boleta,
          reservado: kind == DocumentKind.cotizacion ? true : null,
          creado: DateTime(2026, 10, 28),
          descuento: 5,
          observaciones: 'Entregar mañana',
          pagos: const [DocumentPaymentEntity(metodo: 'EFECTIVO', monto: 118)],
          items: const [
            DocumentItemEntity(
              name: 'SUBWOOFER 12" – 1200W 🔊 Ñandú',
              codigo: 'SUB-12',
              marca: 'PIONEER',
              cantidad: 2,
              precio: 59,
              subtotal: 118,
            ),
          ],
        );

    test('sin configuración del almacén salen los datos de la empresa', () {
      final h = resolveReceiptHeader(doc(), company);
      expect(h.direccion, 'AV. EMPRESA 1');
      expect(h.telefono, '01-111');
      expect(h.email, 'ventas@acme.pe');
      expect(h.web, 'acme.pe');
    });

    test('con datos del almacén salen los del almacén y, si faltan, los de la empresa', () {
      final h = resolveReceiptHeader(
        doc(almacen: const DocumentWarehouseEntity(usaDatos: true, direccion: 'JR. ALMACEN 5', telefono: '01-555')),
        company,
      );
      expect(h.direccion, 'JR. ALMACEN 5');
      expect(h.telefono, '01-555');
      expect(h.email, 'ventas@acme.pe');
    });

    test('con datos del vendedor salen su teléfono y correo', () {
      final h = resolveReceiptHeader(
        doc(almacen: const DocumentWarehouseEntity(usaDatos: true, usaDatosVendedor: true, direccion: 'JR. 5')),
        company,
      );
      expect(h.telefono, '999');
      expect(h.email, 'ana@acme.pe');
      expect(h.direccion, 'JR. 5');
    });

    test('el título según el tipo de documento', () {
      expect(receiptTitle(doc()), 'Nota de Venta');
      expect(receiptTitle(doc(boleta: _boleta)), 'Boleta Electrónica');
      expect(receiptTitle(doc(boleta: const DocumentBoletaEntity(id: 1, tipo: 'f'))), 'Factura Electrónica');
      expect(receiptTitle(doc(kind: DocumentKind.cotizacion)), 'Cotización');
    });

    test('el divisor del IGV acepta fracción o porcentaje y por defecto es 18 %', () {
      expect(receiptIgvDivisor(company), closeTo(1.18, 1e-9));
      expect(receiptIgvDivisor(const CompanyEntity(id: 1, razonSocial: 'X', igv: 18)), closeTo(1.18, 1e-9));
      expect(receiptIgvDivisor(const CompanyEntity(id: 1, razonSocial: 'X')), closeTo(1.18, 1e-9));
    });

    test('genera un PDF A4 y un ticket sin fallar con tildes, ñ, signos y emojis', () async {
      for (final ticket in [false, true]) {
        for (final d in [doc(), doc(boleta: _boleta), doc(kind: DocumentKind.cotizacion), doc(dolares: true)]) {
          final bytes = await buildReceiptPdf(document: d, company: company, ticket: ticket);
          expect(String.fromCharCodes(bytes.take(5)), '%PDF-', reason: 'ticket=$ticket ${d.numero}');
          expect(bytes.length, greaterThan(800));
        }
      }
    });

    test('un logo que no es una imagen no rompe el PDF', () async {
      final bytes = await buildReceiptPdf(
        document: doc(),
        company: company,
        logo: Uint8List.fromList([1, 2, 3]),
      );
      expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
    });
  });

  group('DocumentsPage', () {
    Future<(_FakeDocumentRepository, DocumentsProvider)> pump(
      WidgetTester tester, {
      Set<String> permissions = const {'documentos.ventas.index'},
      _FakeOtherRepository? other,
    }) async {
      // Las pruebas dibujan con la fuente Ahem (casi el doble de ancha que una real).
      tester.view.physicalSize = const Size(360 * 3, 780 * 3);
      tester.view.devicePixelRatio = 3;
      tester.platformDispatcher.textScaleFactorTestValue = 0.55;
      addTearDown(() {
        tester.view.reset();
        tester.platformDispatcher.clearTextScaleFactorTestValue();
      });

      final repo = _FakeDocumentRepository();
      final session = _session(permissions: permissions);
      final documents = _provider(repo, session: session);
      final otherRepo = other ?? _FakeOtherRepository();
      final otherDocuments = OtherDocumentsProvider(
        getDocumentsUseCase: GetOtherDocumentsUseCase(repository: otherRepo),
        deleteTransferUseCase: DeleteTransferUseCase(repository: otherRepo),
      )..syncCompany(7);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<ThemeProvider>(
              create: (_) => ThemeProvider(storage: _FakeThemeStorage()),
            ),
            ChangeNotifierProvider<AuthProvider>.value(value: _auth(session)),
            ChangeNotifierProvider<DocumentsProvider>.value(value: documents),
            ChangeNotifierProvider<OtherDocumentsProvider>.value(value: otherDocuments),
          ],
          child: MaterialApp(theme: AppTheme.light, home: const Scaffold(body: DocumentsPage())),
        ),
      );
      await tester.pumpAndSettle();
      return (repo, documents);
    }

    testWidgets('no muestra etiquetas de filtros ni totales sueltos; descargar y totales van en Acciones', (tester) async {
      await pump(tester);

      expect(find.byType(Chip), findsNothing);
      expect(find.byType(InputChip), findsNothing);
      expect(find.textContaining('Total Soles'), findsNothing);
      expect(find.text('Restablecer'), findsNothing);
      expect(find.byTooltip('Descargar Excel'), findsNothing);
      // La lista y el contador de documentos sí están.
      expect(find.text('V001-0001'), findsOneWidget);
      expect(find.text('2 ventas'), findsOneWidget);
      expect(find.text('Acciones'), findsOneWidget);
    });

    testWidgets('Acciones ofrece descargar el Excel y ver los totales', (tester) async {
      await pump(tester);

      await tester.tap(find.text('Acciones'));
      await tester.pumpAndSettle();

      expect(find.byTooltip('Descargar Excel'), findsOneWidget);
      expect(find.byTooltip('Totales'), findsOneWidget);
    });

    testWidgets('Totales abre un modal con el periodo, la cantidad y los totales en soles y dólares', (tester) async {
      await pump(tester);

      await tester.tap(find.text('Acciones'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Totales'));
      await tester.pumpAndSettle();

      expect(find.text('Periodo'), findsOneWidget);
      expect(find.text('28 oct. 2026 - 28 oct. 2026'), findsOneWidget);
      expect(find.text('Total Soles'), findsOneWidget);
      expect(find.text('S/. 150.50'), findsOneWidget);
      expect(find.text('Total Dólares'), findsOneWidget);
      expect(find.text(r'$ 20.00'), findsOneWidget);
      expect(find.text('Cerrar'), findsOneWidget);
    });


    const todas = {
      'documentos.ventas.index',
      'documentos.cotizaciones.index',
      'despachos.transferir.index',
      'documentos.guia_remision.index',
      'documentos.nota_credito.index',
      'documentos.stock.index',
    };

    testWidgets('con acceso a todo, el selector ofrece las seis listas de la web en su orden', (tester) async {
      await pump(tester, permissions: todas);

      expect(find.byType(DropdownButtonFormField<String>), findsOneWidget); // el selector
      await tester.tap(find.text('Ventas').first);
      await tester.pumpAndSettle();

      final orden = [
        'Ventas',
        'Cotizaciones',
        'Traslados de Stock',
        'Guías de Remisión',
        'Notas de Crédito',
        'Entrada de Stock',
      ];
      var antes = -1.0;
      for (final label in orden) {
        final y = tester.getTopLeft(find.text(label).last).dy;
        expect(y, greaterThan(antes), reason: label);
        antes = y;
      }
    });

    testWidgets('cada lista sale solo con su permiso, como en la web', (tester) async {
      await pump(
        tester,
        permissions: const {'documentos.ventas.index', 'documentos.stock.index'},
      );

      await tester.tap(find.text('Ventas').first);
      await tester.pumpAndSettle();

      expect(find.text('Entrada de Stock'), findsOneWidget);
      expect(find.text('Cotizaciones'), findsNothing);
      expect(find.text('Traslados de Stock'), findsNothing);
      expect(find.text('Guías de Remisión'), findsNothing);
      expect(find.text('Notas de Crédito'), findsNothing);
    });

    testWidgets('con una sola lista no hay selector', (tester) async {
      await pump(tester);

      expect(find.byType(DropdownButtonFormField<String>), findsNothing);
    });

    testWidgets('elegir Traslados de Stock muestra esa lista, sin el botón Acciones de las ventas', (tester) async {
      final other = _FakeOtherRepository();
      await pump(tester, permissions: todas, other: other);
      expect(find.text('Acciones'), findsOneWidget);

      await tester.tap(find.text('Ventas').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Traslados de Stock').last);
      await tester.pumpAndSettle();

      expect(other.pedidas, [OtherDocumentKind.traslado]);
      expect(find.text('T001-0007'), findsOneWidget);
      expect(find.text('LIMA → AREQUIPA'), findsOneWidget);
      expect(find.text('Acciones'), findsNothing);
      expect(find.text('V001-0001'), findsNothing);
    });

    testWidgets('volver a Ventas muestra otra vez sus documentos y sus Acciones', (tester) async {
      await pump(tester, permissions: todas);

      await tester.tap(find.text('Ventas').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Entrada de Stock').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Entrada de Stock').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ventas').last);
      await tester.pumpAndSettle();

      expect(find.text('V001-0001'), findsOneWidget);
      expect(find.text('Acciones'), findsOneWidget);
    });

    testWidgets('Descargar Excel pide el Excel de lo que se ve', (tester) async {
      final (repo, _) = await pump(tester);

      await tester.tap(find.text('Acciones'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Descargar Excel'));
      await tester.pumpAndSettle();

      expect(repo.actions, contains('export:venta'));
    });
  });
}
