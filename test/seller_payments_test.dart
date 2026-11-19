import 'dart:convert';
import 'dart:typed_data';

import 'package:app_novik/core/constants/api_constants.dart';
import 'package:app_novik/core/errors/failures.dart';
import 'package:app_novik/core/utils/either.dart';
import 'package:app_novik/data/datasources/seller_payment_remote_datasource.dart';
import 'package:app_novik/data/datasources/theme_local_datasource.dart';
import 'package:app_novik/data/models/seller_payment_model.dart';
import 'package:app_novik/domain/entities/company_entity.dart';
import 'package:app_novik/domain/entities/saved_credentials_entity.dart';
import 'package:app_novik/domain/entities/seller_payment_entity.dart';
import 'package:app_novik/domain/entities/session_context_entity.dart';
import 'package:app_novik/domain/entities/user_entity.dart';
import 'package:app_novik/domain/repositories/auth_repository.dart';
import 'package:app_novik/domain/repositories/seller_payment_repository.dart';
import 'package:app_novik/domain/usecases/auth_usecases.dart';
import 'package:app_novik/domain/usecases/seller_payment_usecases.dart';
import 'package:app_novik/presentation/components/app_list_card.dart' show AppListCard;
import 'package:app_novik/presentation/components/app_pickers.dart' show AppPickerField;
import 'package:app_novik/presentation/components/app_summary.dart';
import 'package:app_novik/presentation/pages/seller_payments_page.dart';
import 'package:app_novik/presentation/providers/auth_provider.dart';
import 'package:app_novik/presentation/providers/seller_payments_provider.dart';
import 'package:app_novik/presentation/providers/theme_provider.dart';
import 'package:app_novik/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';

/// Un pago aplicado a dos cuotas (la web edita la primera parte), pendiente por defecto.
Map<String, dynamic> _installmentPaymentJson({int id = 1, int estado = 2, bool confirmedPart = false}) => {
      'id': id,
      'client_id': 5,
      'client': {'id': 5, 'razon_social': 'ACME SAC', 'name': 'Acme', 'last_name': null},
      'user': {'id': 9, 'name': 'LUIS VENDEDOR'},
      'monto_total': 150.5,
      'saldo_pendiente': 0,
      'moneda': 'soles',
      'estado': estado,
      'es_saldo_a_favor': false,
      'created_at': '2026-11-10T12:00:00.000000Z',
      'payment_method_id': null,
      'payment_method': null,
      'ultima_nota': {
        'texto': 'Cuota 1',
        'user': {'id': 9, 'name': 'LUIS VENDEDOR'},
      },
      'notas_count': 2,
      'fee_payments_sellers': [
        {
          'id': 31,
          'payment_method_id': 2,
          'monto': 100,
          'estado': confirmedPart,
          'payment_method': {'id': 2, 'name': 'YAPE'},
          'payment_seller': {'id': id, 'monto_total': 150.5, 'moneda': 'soles', 'client_id': 5},
        },
        {
          'id': 32,
          'payment_method_id': 3,
          'monto': 50.5,
          'estado': confirmedPart,
          'payment_method': {'id': 3, 'name': 'EFECTIVO'},
          'payment_seller': {'id': id, 'monto_total': 150.5, 'moneda': 'soles', 'client_id': 5},
        },
      ],
    };

/// Un pago sin cuotas (saldo a favor), en dólares y aprobado.
Map<String, dynamic> _favorPaymentJson({int id = 2, int estado = 1}) => {
      'id': id,
      'client_id': 6,
      'client': {'id': 6, 'razon_social': null, 'name': 'Ana', 'last_name': 'Pérez'},
      'user': {'id': 4, 'name': 'FRANCIS BULNES GONZALES'},
      'monto_total': '250.00',
      'moneda': 'dolares',
      'estado': estado,
      'es_saldo_a_favor': true,
      'created_at': '2026-11-12T12:00:00.000000Z',
      'payment_method_id': 4,
      'payment_method': {'id': 4, 'name': 'TRANSFERENCIA'},
      'ultima_nota': {
        'texto': 'Anticipo',
        'user': {'id': 4, 'name': 'FRANCIS BULNES GONZALES'},
      },
      'notas_count': 1,
      'fee_payments_sellers': [],
    };

Map<String, dynamic> _pageJson({List<Map<String, dynamic>>? data, int page = 1, int last = 1}) => {
      'data': data ?? [_installmentPaymentJson()],
      'current_page': page,
      'last_page': last,
      'total': 42,
      'total_soles': 9000.25,
      'total_dolares': 120,
      'metodos_disponibles': [
        {'id': 2, 'name': 'YAPE'},
        {'id': 3, 'name': 'EFECTIVO'},
      ],
    };

/// Ruta base de la API según la URL con la que se compile (en producción lleva `/7power/public`).
final _apiPath = Uri.parse(ApiConstants.baseUrl).path;

SellerPaymentEntity _payment({
  int id = 1,
  int? estado,
  bool confirmedPart = false,
  bool favor = false,
}) =>
    sellerPaymentFromJson(
      favor
          ? _favorPaymentJson(id: id, estado: estado ?? 1)
          : _installmentPaymentJson(id: id, estado: estado ?? 2, confirmedPart: confirmedPart),
    );

final _now = DateTime(2026, 11, 17, 10, 30, 15);

class _FakeSellerPaymentRepository implements SellerPaymentRepository {
  List<SellerPaymentEntity> items = [_payment()];
  int lastPage = 1;
  Failure? failure;
  Failure? actionFailure;
  Failure? debtFailure;
  final calls = <({int page, SellerPaymentFilters filters})>[];
  int methodCalls = 0;
  int sellerCalls = 0;
  final clientCalls = <bool>[];
  SellerPaymentFilters? exported;
  SellerPaymentCreate? created;
  final approved = <int>[];
  final deleted = <({int id, bool afterConfirm})>[];
  ({int id, int method, double? monto})? editedInstallment;
  ({int id, int method})? edited;
  int? debtClientId;

  /// El historial de notas del pago (la más reciente primero) y si el usuario puede escribir.
  List<SellerPaymentNote> notes = [
    SellerPaymentNote(
      id: 11,
      texto: 'Segunda nota',
      creado: DateTime(2026, 11, 12, 15, 5),
      autor: 'LUIS VENDEDOR',
      puedeEliminar: true,
      puedeEditar: true,
    ),
    // La de otro autor, ya corregida por él: se ve "Editada el …" y no tiene lápiz.
    SellerPaymentNote(
      id: 9,
      texto: 'Corregida por otro',
      creado: DateTime(2026, 11, 9, 7, 0),
      autor: 'FRANCIS BULNES GONZALES',
      editadaEn: DateTime(2026, 11, 9, 8, 15),
    ),
    // Eliminada (y editada antes): tachada, sin lápiz y sin "Editada el".
    SellerPaymentNote(
      id: 10,
      texto: 'Cuota 1',
      creado: DateTime(2026, 11, 10, 9, 30),
      autor: 'FRANCIS BULNES GONZALES',
      eliminadaEn: DateTime(2026, 11, 11, 18, 45),
      eliminadaPor: 'CEO',
      editadaEn: DateTime(2026, 11, 10, 10, 0),
    ),
  ];
  bool canWriteNotes = true;
  Failure? notesFailure;
  Failure? noteActionFailure;
  final notesLoadedFor = <int>[];
  final addedNotes = <({int paymentId, String texto})>[];
  final deletedNotes = <int>[];
  final editedNotes = <({int noteId, String texto})>[];
  Failure? editNoteFailure;

  List<SellerPaymentOption> clients = const [
    SellerPaymentOption(id: 7, name: 'DISTRIBUIDORA SUR'),
    SellerPaymentOption(id: 8, name: 'ALMACENES NORTE'),
  ];
  List<SellerPaymentOption> sellers = const [
    SellerPaymentOption(id: 4, name: 'FRANCIS BULNES GONZALES'),
    SellerPaymentOption(id: 5, name: 'LUIS VENDEDOR'),
  ];
  List<SellerPaymentOption> methods = const [
    SellerPaymentOption(id: 2, name: 'YAPE'),
    SellerPaymentOption(id: 3, name: 'EFECTIVO'),
    SellerPaymentOption(id: 4, name: 'TRANSFERENCIA'),
    SellerPaymentOption(id: 9, name: 'CRÉDITO'),
    SellerPaymentOption(id: 10, name: 'CONTRAENTREGA'),
    SellerPaymentOption(id: 11, name: 'PUNTOS'),
  ];
  SellerClientDebt debt = const SellerClientDebt(soles: 1200, dolares: 0);

  Either<Failure, void> _action() => actionFailure != null ? Either.left(actionFailure!) : Either.rightVoid();

  @override
  Future<Either<Failure, SellerPaymentPageEntity>> getPayments({
    required int page,
    required int pageSize,
    required SellerPaymentFilters filters,
  }) async {
    calls.add((page: page, filters: filters));
    if (failure != null) return Either.left(failure!);
    return Either.right(
      SellerPaymentPageEntity(
        items: items,
        currentPage: page,
        lastPage: lastPage,
        total: items.isEmpty ? 0 : 42,
        totalSoles: items.isEmpty ? 0 : 9000.25,
        totalDolares: items.isEmpty ? 0 : 120,
        methods: const [
          SellerPaymentOption(id: 2, name: 'YAPE'),
          SellerPaymentOption(id: 3, name: 'EFECTIVO'),
        ],
      ),
    );
  }

  @override
  Future<Either<Failure, Uint8List>> exportPayments({required SellerPaymentFilters filters}) async {
    exported = filters;
    return Either.right(Uint8List.fromList([1, 2, 3]));
  }

  @override
  Future<Either<Failure, List<SellerPaymentOption>>> getPaymentMethods() async {
    methodCalls++;
    return Either.right(methods);
  }

  @override
  Future<Either<Failure, List<SellerPaymentOption>>> getClients({
    required int companyId,
    required bool onlyMine,
  }) async {
    clientCalls.add(onlyMine);
    return Either.right(clients);
  }

  @override
  Future<Either<Failure, List<SellerPaymentOption>>> getSellers({required int companyId}) async {
    sellerCalls++;
    return Either.right(sellers);
  }

  @override
  Future<Either<Failure, SellerClientDebt>> getClientDebt({required int clientId}) async {
    debtClientId = clientId;
    if (debtFailure != null) return Either.left(debtFailure!);
    return Either.right(debt);
  }

  @override
  Future<Either<Failure, void>> createPayment({required SellerPaymentCreate payment}) async {
    created = payment;
    return _action();
  }

  @override
  Future<Either<Failure, void>> approvePayment({required int id}) async {
    approved.add(id);
    return _action();
  }

  @override
  Future<Either<Failure, void>> editInstallmentPayment({
    required int id,
    required int paymentMethodId,
    double? monto,
  }) async {
    editedInstallment = (id: id, method: paymentMethodId, monto: monto);
    return _action();
  }

  @override
  Future<Either<Failure, void>> editPayment({
    required int id,
    required int paymentMethodId,
  }) async {
    edited = (id: id, method: paymentMethodId);
    return _action();
  }

  @override
  Future<Either<Failure, void>> deletePayment({required int id, required bool afterConfirm}) async {
    deleted.add((id: id, afterConfirm: afterConfirm));
    return _action();
  }

  @override
  Future<Either<Failure, SellerPaymentNotes>> getNotes({required int paymentId}) async {
    notesLoadedFor.add(paymentId);
    if (notesFailure != null) return Either.left(notesFailure!);
    return Either.right(SellerPaymentNotes(notas: notes, puedeEscribir: canWriteNotes));
  }

  @override
  Future<Either<Failure, SellerPaymentNote>> addNote({required int paymentId, required String texto}) async {
    addedNotes.add((paymentId: paymentId, texto: texto));
    if (noteActionFailure != null) return Either.left(noteActionFailure!);
    return Either.right(SellerPaymentNote(id: 100 + addedNotes.length, texto: texto, creado: DateTime(2026, 11, 17, 15, 5), autor: 'Ana', puedeEliminar: true));
  }

  @override
  Future<Either<Failure, SellerPaymentNote>> editNote({required int noteId, required String texto}) async {
    editedNotes.add((noteId: noteId, texto: texto));
    if (editNoteFailure != null) return Either.left(editNoteFailure!);
    final original = notes.firstWhere((n) => n.id == noteId, orElse: () => SellerPaymentNote(id: noteId, texto: 'Nueva'));
    return Either.right(
      SellerPaymentNote(
        id: noteId,
        texto: texto,
        creado: original.creado,
        autor: original.autor,
        puedeEliminar: true,
        puedeEditar: true,
        editadaEn: DateTime(2026, 11, 17, 17, 0),
      ),
    );
  }

  @override
  Future<Either<Failure, SellerPaymentNote>> deleteNote({required int noteId}) async {
    deletedNotes.add(noteId);
    if (noteActionFailure != null) return Either.left(noteActionFailure!);
    final original = notes.firstWhere((n) => n.id == noteId, orElse: () => SellerPaymentNote(id: noteId, texto: 'Nueva'));
    return Either.right(
      SellerPaymentNote(
        id: noteId,
        texto: original.texto,
        creado: original.creado,
        autor: original.autor,
        eliminadaEn: DateTime(2026, 11, 17, 16, 30),
        eliminadaPor: 'Ana',
      ),
    );
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
  Future<Either<Failure, void>> saveCredentials(String usuario, String password) async => Either.rightVoid();

  @override
  Future<Either<Failure, void>> clearSavedCredentials() async => Either.rightVoid();
}

SessionContextEntity _session({int companyId = 1, Set<String> permissions = const {'pagos-vendedores.index'}}) =>
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

SellerPaymentsProvider _provider(_FakeSellerPaymentRepository repo, {SessionContextEntity? session}) =>
    SellerPaymentsProvider(
      getPaymentsUseCase: GetSellerPaymentsUseCase(repository: repo),
      exportPaymentsUseCase: ExportSellerPaymentsUseCase(repository: repo),
      getMethodsUseCase: GetSellerPaymentMethodsUseCase(repository: repo),
      getClientsUseCase: GetSellerPaymentClientsUseCase(repository: repo),
      getSellersUseCase: GetSellerPaymentSellersUseCase(repository: repo),
      getClientDebtUseCase: GetSellerClientDebtUseCase(repository: repo),
      createUseCase: CreateSellerPaymentUseCase(repository: repo),
      approveUseCase: ApproveSellerPaymentUseCase(repository: repo),
      editInstallmentUseCase: EditSellerInstallmentPaymentUseCase(repository: repo),
      editUseCase: EditSellerPaymentUseCase(repository: repo),
      deleteUseCase: DeleteSellerPaymentUseCase(repository: repo),
      getNotesUseCase: GetSellerPaymentNotesUseCase(repository: repo),
      addNoteUseCase: AddSellerPaymentNoteUseCase(repository: repo),
      editNoteUseCase: EditSellerPaymentNoteUseCase(repository: repo),
      deleteNoteUseCase: DeleteSellerPaymentNoteUseCase(repository: repo),
      now: () => _now,
    )..syncSession(session ?? _session());

Future<({_FakeSellerPaymentRepository repo, SellerPaymentsProvider provider})> _pump(
  WidgetTester tester, {
  Set<String> permissions = const {'pagos-vendedores.index'},
  Size size = const Size(400, 900),
  ThemeMode mode = ThemeMode.light,
  double textScale = 1,
  void Function(_FakeSellerPaymentRepository repo)? setUp,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final repo = _FakeSellerPaymentRepository();
  setUp?.call(repo);
  final session = _session(permissions: permissions);
  final provider = _provider(repo, session: session);

  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<ThemeProvider>(create: (_) => ThemeProvider(storage: _FakeThemeStorage())),
        ChangeNotifierProvider<AuthProvider>.value(value: _auth(session)),
        ChangeNotifierProvider<SellerPaymentsProvider>.value(value: provider),
      ],
      child: MaterialApp(
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        themeMode: mode,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: const Scaffold(body: SellerPaymentsPage()),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return (repo: repo, provider: provider);
}

const _allPermissions = {
  'pagos-vendedores.index',
  'pagos-vendedores.store',
  'pagos-vendedores.showOthersSellers',
  'pagos-vendedores.confirmarPago',
  'pagos-vendedores.update',
  'pagos-vendedores.destroy',
  'pagos-vendedores.post-confirm.destroy',
};

void main() {
  group('Modelo de pagos de vendedores', () {
    test('lee una página con los totales y los métodos disponibles', () {
      final page = sellerPaymentPageFromJson(_pageJson(page: 1, last: 3));

      expect(page.items, hasLength(1));
      expect(page.total, 42);
      expect(page.totalSoles, 9000.25);
      expect(page.totalDolares, 120);
      expect(page.hasMore, isTrue);
      expect(page.methods.map((m) => m.name), ['YAPE', 'EFECTIVO']);
    });

    test('un pago con cuotas: cliente, ejecutivo, descripción, métodos y primera parte', () {
      final p = _payment();

      expect(p.cliente, 'ACME SAC');
      expect(p.ejecutivo, 'LUIS VENDEDOR');
      expect(p.descripcion, 'Cuota 1');
      expect(p.ultimaNota!.autor, 'LUIS VENDEDOR');
      expect(p.notasCount, 2);
      expect(p.metodos, ['YAPE', 'EFECTIVO']);
      expect(p.montoTotal, 150.5);
      expect(p.simbolo, 'S/.');
      expect(p.status, SellerPaymentStatus.pendiente);
      expect(p.isSaldoAFavor, isFalse);
      expect(p.editAllocation!.id, 31);
      expect(p.editAllocation!.paymentTotal, 150.5);
      expect(p.creado!.day, 10);
    });

    test('un pago sin cuotas es un saldo a favor, con su método y su descripción', () {
      final p = _payment(favor: true);

      expect(p.cliente, 'Ana Pérez');
      expect(p.isSaldoAFavor, isTrue);
      expect(p.editAllocation, isNull);
      expect(p.metodos, ['TRANSFERENCIA']);
      expect(p.descripcion, 'Anticipo');
      expect(p.montoTotal, 250);
      expect(p.esDolares, isTrue);
      expect(p.simbolo, r'$.');
      expect(p.status, SellerPaymentStatus.aprobado);
    });

    test('el estado 0 y deleted_at son un pago cancelado', () {
      expect(_payment(estado: 0).status, SellerPaymentStatus.cancelado);
      final deleted = sellerPaymentFromJson({..._installmentPaymentJson(), 'deleted_at': '2026-11-11T00:00:00Z'});
      expect(deleted.status, SellerPaymentStatus.cancelado);
    });

    test('los clientes usan el nombre que ve la web y la deuda sale del servidor', () {
      final list = sellerPaymentClientOptionsFromJson([
        {'id': 1, 'display_label': 'ACME SAC - 20123456789', 'name': 'x'},
        {'id': 2, 'razon_social': 'BETA SAC'},
        {'id': 3, 'name': 'Ana', 'last_name': 'Pérez'},
        {'id': 4},
      ]);
      expect(list.map((o) => o.name), ['ACME SAC - 20123456789', 'BETA SAC', 'Ana Pérez']);

      final debt = sellerClientDebtFromJson({'deuda_pendiente_soles': '1200.5', 'deuda_pendiente_dolares': 30});
      expect(debt.soles, 1200.5);
      expect(debt.dolares, 30);
    });

    test('los filtros: por defecto el mes, y cuentan solo los que cambian', () {
      final base = SellerPaymentFilters.mes(_now);
      expect(base.desde, DateTime(2026, 11, 1));
      expect(base.hasta, DateTime(2026, 11, 30));
      expect(base.count(base), 0);
      expect(base.copyWith(estado: SellerPaymentStatus.aprobado, montoMin: 10).count(base), 2);
      expect(base.copyWith(desde: null, hasta: null).count(base), 1);
      expect(base.copyWith(estado: SellerPaymentStatus.aprobado).copyWith(estado: null).estado, isNull);
    });
  });

  group('Datasource de pagos de vendedores', () {
    test('GET /pagos-vendedores-new manda paginación, búsqueda y filtros como la web', () async {
      late Uri uri;
      final ds = SellerPaymentRemoteDataSourceImpl(
        client: MockClient((request) async {
          uri = request.url;
          expect(request.method, 'GET');
          return http.Response(jsonEncode(_pageJson()), 200);
        }),
      );

      final page = await ds.getPayments(
        't',
        page: 2,
        pageSize: 50,
        filters: SellerPaymentFilters(
          desde: DateTime(2026, 11, 1),
          hasta: DateTime(2026, 11, 30),
          clientes: const [7, 8],
          ejecutivos: const [4],
          metodos: const [2],
          montoMin: 10,
          montoMax: 99.5,
          estado: SellerPaymentStatus.pendiente,
          search: const ['acme', 'yape'],
        ),
      );

      expect(page.items, hasLength(1));
      expect(uri.path, '$_apiPath/pagos-vendedores-new');
      expect(uri.queryParametersAll, {
        'pagination[current]': ['2'],
        'pagination[pageSize]': ['50'],
        'fecha_desde': ['2026-11-01'],
        'fecha_hasta': ['2026-11-30'],
        'clientes[]': ['7', '8'],
        'ejecutivos[]': ['4'],
        'metodos[]': ['2'],
        'monto_min': ['10'],
        'monto_max': ['99.5'],
        'estado_filter': ['2'],
        'search[]': ['acme', 'yape'],
      });
    });

    test('sin filtros solo manda la paginación (sin fechas = todas)', () async {
      late Uri uri;
      final ds = SellerPaymentRemoteDataSourceImpl(
        client: MockClient((request) async {
          uri = request.url;
          return http.Response('{"data": []}', 200);
        }),
      );

      await ds.getPayments('t', page: 1, pageSize: 50, filters: const SellerPaymentFilters());

      expect(uri.queryParameters.keys, ['pagination[current]', 'pagination[pageSize]']);
    });

    test('el estado cancelado se manda como 0', () async {
      late Uri uri;
      final ds = SellerPaymentRemoteDataSourceImpl(
        client: MockClient((request) async {
          uri = request.url;
          return http.Response('{"data": []}', 200);
        }),
      );

      await ds.getPayments('t', page: 1, pageSize: 50, filters: const SellerPaymentFilters(estado: SellerPaymentStatus.cancelado));

      expect(uri.queryParameters['estado_filter'], '0');
    });

    test('el Excel es un POST con los mismos filtros', () async {
      late http.Request req;
      final ds = SellerPaymentRemoteDataSourceImpl(
        client: MockClient((request) async {
          req = request;
          return http.Response.bytes([9, 9], 200);
        }),
      );

      final bytes = await ds.exportPayments(
        't',
        filters: SellerPaymentFilters(desde: DateTime(2026, 11, 1), hasta: DateTime(2026, 11, 30), search: const ['acme']),
      );

      expect(bytes, [9, 9]);
      expect(req.method, 'POST');
      expect(req.url.path, '$_apiPath/pagos-vendedores-new/export');
      expect(req.url.queryParametersAll, {
        'fecha_desde': ['2026-11-01'],
        'fecha_hasta': ['2026-11-30'],
        'search[]': ['acme'],
      });
    });

    test('los métodos de pago piden all=true; los clientes, su cartera solo en el filtro', () async {
      final uris = <Uri>[];
      final ds = SellerPaymentRemoteDataSourceImpl(
        client: MockClient((request) async {
          uris.add(request.url);
          return http.Response('[{"id": 2, "name": "YAPE", "display_label": "ACME"}]', 200);
        }),
      );

      final methods = await ds.getPaymentMethods('t');
      final all = await ds.getClients('t', companyId: 3, onlyMine: false);
      await ds.getClients('t', companyId: 3, onlyMine: true);
      final sellers = await ds.getSellers('t', companyId: 3);

      expect(methods.single.name, 'YAPE');
      expect(all.single.name, 'ACME');
      expect(sellers.single.name, 'YAPE');
      expect(uris[0].path, '$_apiPath/metodos-de-pago/list');
      expect(uris[0].queryParameters, {'all': 'true'});
      expect(uris[1].path, '$_apiPath/clientes/list');
      expect(uris[1].queryParameters, {'company_id': '3'});
      expect(uris[2].queryParameters, {'company_id': '3', 'solo_mi_cartera': 'true'});
      expect(uris[3].path, '$_apiPath/usuarios/list');
      expect(uris[3].queryParameters, {'company_id': '3', 'roles[0]': 'Vendedor'});
    });

    test('la deuda del cliente sale de clientes/{id}?include_deudas=true', () async {
      late Uri uri;
      final ds = SellerPaymentRemoteDataSourceImpl(
        client: MockClient((request) async {
          uri = request.url;
          return http.Response('{"id": 7, "deuda_pendiente_soles": 100.5, "deuda_pendiente_dolares": 20}', 200);
        }),
      );

      final debt = await ds.getClientDebt('t', clientId: 7);

      expect(uri.path, '$_apiPath/clientes/7');
      expect(uri.queryParameters, {'include_deudas': 'true'});
      expect(debt.soles, 100.5);
      expect(debt.dolares, 20);
    });

    test('registrar un pago es un POST a /pagos-vendedores/deposito con la fecha y hora', () async {
      late http.Request req;
      final ds = SellerPaymentRemoteDataSourceImpl(
        client: MockClient((request) async {
          req = request;
          return http.Response('[]', 200);
        }),
      );

      await ds.createPayment(
        't',
        payment: SellerPaymentCreate(
          clientId: 7,
          moneda: 'dolares',
          creado: DateTime(2026, 11, 5, 9, 8, 7),
          lines: const [
            SellerPaymentLine(paymentMethodId: 2, monto: 100.5, descripcionAdicional: 'Primera'),
            SellerPaymentLine(paymentMethodId: 3, monto: 20),
          ],
        ),
      );

      expect(req.method, 'POST');
      expect(req.url.path, '$_apiPath/pagos-vendedores/deposito');
      expect(jsonDecode(req.body), {
        'client_id': 7,
        'payment_methods': [
          {'payment_method_id': 2, 'monto': 100.5, 'descripcion_adicional': 'Primera'},
          {'payment_method_id': 3, 'monto': 20.0},
        ],
        'created_at': '2026-11-05 09:08:07',
        'moneda': 'dolares',
      });
    });

    test('sin fecha no manda created_at (el servidor pone ahora)', () async {
      late http.Request req;
      final ds = SellerPaymentRemoteDataSourceImpl(
        client: MockClient((request) async {
          req = request;
          return http.Response('[]', 200);
        }),
      );

      await ds.createPayment(
        't',
        payment: const SellerPaymentCreate(
          clientId: 7,
          moneda: 'soles',
          lines: [SellerPaymentLine(paymentMethodId: 2, monto: 5)],
        ),
      );

      expect((jsonDecode(req.body) as Map).containsKey('created_at'), isFalse);
    });

    test('aprobar es un PUT a confirmar-group/{id}', () async {
      late http.Request req;
      final ds = SellerPaymentRemoteDataSourceImpl(
        client: MockClient((request) async {
          req = request;
          return http.Response('{"id": 1}', 200);
        }),
      );

      await ds.approvePayment('t', id: 12);

      expect(req.method, 'PUT');
      expect(req.url.path, '$_apiPath/pagos-vendedores/confirmar-group/12');
    });

    test('editar la parte de una cuota es PUT edit-pre-confirm/{id}; el monto solo si se manda', () async {
      final requests = <http.Request>[];
      final ds = SellerPaymentRemoteDataSourceImpl(
        client: MockClient((request) async {
          requests.add(request);
          return http.Response('{"id": 31}', 200);
        }),
      );

      await ds.editInstallmentPayment('t', id: 31, paymentMethodId: 2, monto: 80);
      await ds.editInstallmentPayment('t', id: 31, paymentMethodId: 3);

      expect(requests.first.method, 'PUT');
      expect(requests.first.url.path, '$_apiPath/pagos-vendedores/edit-pre-confirm/31');
      // La descripción ya no viaja: son las notas del pago.
      expect(jsonDecode(requests.first.body), {'payment_method_id': 2, 'monto': 80.0});
      expect(jsonDecode(requests.last.body), {'payment_method_id': 3});
    });

    test('editar un saldo a favor es PUT edit-payment-seller/{id} solo con el método', () async {
      late http.Request req;
      final ds = SellerPaymentRemoteDataSourceImpl(
        client: MockClient((request) async {
          req = request;
          return http.Response('{"id": 2}', 200);
        }),
      );

      await ds.editPayment('t', id: 2, paymentMethodId: 4);

      expect(req.method, 'PUT');
      expect(req.url.path, '$_apiPath/pagos-vendedores/edit-payment-seller/2');
      expect(jsonDecode(req.body), {'payment_method_id': 4});
    });

    test('las notas: GET con el historial, POST con el texto y DELETE devuelve la nota eliminada', () async {
      final requests = <http.Request>[];
      final ds = SellerPaymentRemoteDataSourceImpl(
        client: MockClient((request) async {
          requests.add(request);
          if (request.method == 'GET') {
            return http.Response(
              jsonEncode({
                'puede_escribir': true,
                'notas': [
                  {
                    'id': 11,
                    'texto': 'Segunda',
                    'created_at': '2026-11-12T20:05:00.000000Z',
                    'user': {'id': 9, 'name': 'LUIS'},
                    'eliminada_at': null,
                    'eliminada_por': null,
                    'puede_eliminar': true,
                  },
                  {
                    'id': 10,
                    'texto': 'Primera',
                    'created_at': '2026-11-10T14:30:00.000000Z',
                    'user': null,
                    'eliminada_at': '2026-11-11T23:45:00.000000Z',
                    'eliminada_por': {'id': 1, 'name': 'CEO'},
                    'puede_eliminar': false,
                  },
                ],
              }),
              200,
            );
          }
          return http.Response(
            jsonEncode({
              'id': 12,
              'texto': 'Nueva',
              'created_at': '2026-11-17T20:00:00.000000Z',
              'user': {'id': 9, 'name': 'LUIS'},
              'eliminada_at': request.method == 'DELETE' ? '2026-11-17T21:00:00.000000Z' : null,
              'eliminada_por': request.method == 'DELETE' ? {'id': 9, 'name': 'LUIS'} : null,
              'puede_eliminar': request.method != 'DELETE',
            }),
            request.method == 'POST' ? 201 : 200,
          );
        }),
      );

      final notes = await ds.getNotes('t', paymentId: 7);
      final added = await ds.addNote('t', paymentId: 7, texto: 'Nueva');
      final removed = await ds.deleteNote('t', noteId: 12);

      expect(requests.map((r) => r.method), ['GET', 'POST', 'DELETE']);
      expect(requests[0].url.path, '$_apiPath/pagos-vendedores/7/notas');
      expect(requests[1].url.path, '$_apiPath/pagos-vendedores/7/notas');
      expect(jsonDecode(requests[1].body), {'texto': 'Nueva'});
      expect(requests[2].url.path, '$_apiPath/pagos-vendedores/notas/12');
      expect(notes.puedeEscribir, isTrue);
      expect(notes.notas.map((n) => n.id), [11, 10]);
      expect(notes.notas.first.autor, 'LUIS');
      expect(notes.notas.first.puedeEliminar, isTrue);
      expect(notes.notas.last.autor, isNull);
      expect(notes.notas.last.eliminada, isTrue);
      expect(notes.notas.last.eliminadaPor, 'CEO');
      expect(added.texto, 'Nueva');
      expect(added.eliminada, isFalse);
      expect(removed.eliminada, isTrue);
      expect(removed.eliminadaPor, 'LUIS');
    });

    test('un 403 al agregar una nota llega con el mensaje del servidor', () async {
      final ds = SellerPaymentRemoteDataSourceImpl(
        client: MockClient((request) async => http.Response('{"message": "No tienes permiso para agregar notas"}', 403)),
      );

      expect(() => ds.addNote('t', paymentId: 1, texto: 'x'), throwsA(predicate((e) => '$e'.contains('permiso'))));
    });

    test('editar una nota es PUT notas/{nota} con el texto y devuelve la nota editada', () async {
      late http.Request req;
      final ds = SellerPaymentRemoteDataSourceImpl(
        client: MockClient((request) async {
          req = request;
          return http.Response(
            jsonEncode({
              'id': 11,
              'texto': 'Texto corregido',
              'created_at': '2026-11-12T20:05:00.000000Z',
              'user': {'id': 9, 'name': 'LUIS'},
              'eliminada_at': null,
              'eliminada_por': null,
              'editada_at': '2026-11-17T22:00:00.000000Z',
              'puede_eliminar': true,
              'puede_editar': true,
            }),
            200,
          );
        }),
      );

      final note = await ds.editNote('t', noteId: 11, texto: 'Texto corregido');

      expect(req.method, 'PUT');
      expect(req.url.path, '$_apiPath/pagos-vendedores/notas/11');
      expect(jsonDecode(req.body), {'texto': 'Texto corregido'});
      expect(note.texto, 'Texto corregido');
      expect(note.puedeEditar, isTrue);
      expect(note.editada, isTrue);
      expect(note.eliminada, isFalse);
    });

    test('las notas traen puede_editar y editada_at (sin ellos, no se editan ni están editadas)', () {
      final edited = sellerPaymentNoteFromJson({'id': 1, 'texto': 'x', 'puede_editar': true, 'editada_at': '2026-11-17T22:00:00Z'});
      final plain = sellerPaymentNoteFromJson({'id': 2, 'texto': 'y'});

      expect(edited.puedeEditar, isTrue);
      expect(edited.editadaEn, isNotNull);
      expect(plain.puedeEditar, isFalse);
      expect(plain.editada, isFalse);
    });

    test('editar la nota de otro (403) o una sin cambios, vacía o eliminada (422) llega con el motivo', () async {
      final forbidden = SellerPaymentRemoteDataSourceImpl(
        client: MockClient((request) async => http.Response('{"message": "Solo puedes editar tus notas"}', 403)),
      );
      expect(
        () => forbidden.editNote('t', noteId: 1, texto: 'x'),
        throwsA(predicate((e) => '$e'.contains('No tienes permiso para esta acción'))),
      );

      for (final reason in ['No hay cambios en la nota', 'Escribe la nota', 'No se puede editar una nota eliminada']) {
        final ds = SellerPaymentRemoteDataSourceImpl(
          client: MockClient((request) async => http.Response(jsonEncode({'message': reason}), 422)),
        );
        expect(() => ds.editNote('t', noteId: 1, texto: 'x'), throwsA(predicate((e) => '$e'.contains(reason))));
      }
    });

    test('eliminar un pago pendiente y uno confirmado usan rutas distintas, con type=payment_seller', () async {
      final requests = <http.Request>[];
      final ds = SellerPaymentRemoteDataSourceImpl(
        client: MockClient((request) async {
          requests.add(request);
          return http.Response('{"message": "ok"}', 200);
        }),
      );

      await ds.deletePayment('t', id: 5, afterConfirm: false);
      await ds.deletePayment('t', id: 6, afterConfirm: true);

      expect(requests.map((r) => r.method), ['DELETE', 'DELETE']);
      expect(requests.first.url.path, '$_apiPath/pagos-vendedores/5');
      expect(requests.last.url.path, '$_apiPath/pagos-vendedores/delete-post-confirm/6');
      expect(requests.every((r) => r.url.queryParameters['type'] == 'payment_seller'), isTrue);
    });

    test('un 422 llega con el mensaje del servidor', () async {
      final ds = SellerPaymentRemoteDataSourceImpl(
        client: MockClient((request) async => http.Response('{"error": {"monto": ["El monto es obligatorio"]}}', 422)),
      );

      expect(
        () => ds.createPayment(
          't',
          payment: const SellerPaymentCreate(clientId: 1, moneda: 'soles', lines: []),
        ),
        throwsA(predicate((e) => '$e'.contains('El monto es obligatorio'))),
      );
    });
  });

  group('SellerPaymentsProvider', () {
    test('carga la primera página con los pagos del mes y sus totales', () async {
      final repo = _FakeSellerPaymentRepository();
      final p = _provider(repo);

      await p.ensureLoaded();

      expect(p.items, hasLength(1));
      expect(p.total, 42);
      expect(p.totalSoles, 9000.25);
      expect(p.totalDolares, 120);
      expect(repo.calls.single.page, 1);
      expect(repo.calls.single.filters.desde, DateTime(2026, 11, 1));
      expect(repo.calls.single.filters.hasta, DateTime(2026, 11, 30));
      expect(p.availableMethods.map((m) => m.name), ['YAPE', 'EFECTIVO']);
      expect(p.methodName(2), 'YAPE');
    });

    test('loadMore suma la página siguiente y para al llegar a la última', () async {
      final repo = _FakeSellerPaymentRepository()..lastPage = 2;
      final p = _provider(repo);
      await p.refresh();
      expect(p.hasMore, isTrue);

      repo.items = [_payment(id: 2, favor: true)];
      await p.loadMore();
      await p.loadMore();

      expect(p.items.map((d) => d.id), [1, 2]);
      expect(p.hasMore, isFalse);
      expect(repo.calls.map((c) => c.page), [1, 2]);
    });

    test('un error deja la lista vacía con el mensaje', () async {
      final repo = _FakeSellerPaymentRepository()..failure = const ServerFailure('Falló');
      final p = _provider(repo);

      await p.refresh();

      expect(p.items, isEmpty);
      expect(p.error, 'Falló');
      expect(p.totalSoles, 0);
    });

    test('los permisos son los de la web (pagos-vendedores.*)', () {
      final none = _provider(_FakeSellerPaymentRepository());
      expect(none.canIndex, isTrue);
      expect(none.canStore, isFalse);
      expect(none.canSeeOthers, isFalse);
      expect(none.canApprove, isFalse);

      final all = _provider(
        _FakeSellerPaymentRepository(),
        session: _session(permissions: {..._allPermissions, 'pagos-vendedores.post-confirm.update'}),
      );
      expect(all.canStore, isTrue);
      expect(all.canSeeOthers, isTrue);
      expect(all.canApprove, isTrue);
      expect(all.canUpdate, isTrue);
      expect(all.canDestroy, isTrue);
      expect(all.canPostConfirmUpdate, isTrue);
      expect(all.canPostConfirmDestroy, isTrue);
    });

    test('la búsqueda son términos: el que se escribe y los chips se mandan todos', () async {
      final repo = _FakeSellerPaymentRepository();
      final p = _provider(repo);

      await p.addSearchTerm(' acme ');
      await p.addSearchTerm('acme');
      await p.setSearch('yape');

      expect(p.searchTerms, ['acme']);
      expect(repo.calls.last.filters.search, ['acme', 'yape']);
      expect(p.hasAnyFilter, isTrue);

      await p.removeSearchTerm('acme');
      expect(repo.calls.last.filters.search, ['yape']);
      await p.clearSearchTerms();
      await p.setSearch('');
      expect(repo.calls.last.filters.search, isEmpty);
    });

    test('aplicar filtros los manda y Restablecer vuelve al mes y quita las búsquedas', () async {
      final repo = _FakeSellerPaymentRepository();
      final p = _provider(repo);

      await p.addSearchTerm('acme');
      await p.applyFilters(p.filters.copyWith(estado: SellerPaymentStatus.aprobado, clientes: const [7]));

      expect(repo.calls.last.filters.estado, SellerPaymentStatus.aprobado);
      expect(repo.calls.last.filters.clientes, [7]);
      expect(repo.calls.last.filters.search, ['acme']);
      expect(p.filtersCount, 2);

      await p.resetFilters();

      expect(repo.calls.last.filters.estado, isNull);
      expect(repo.calls.last.filters.clientes, isEmpty);
      expect(repo.calls.last.filters.search, isEmpty);
      expect(repo.calls.last.filters.desde, DateTime(2026, 11, 1));
      expect(p.filtersCount, 0);
      expect(p.hasAnyFilter, isFalse);
    });

    test('los catálogos se piden una sola vez y los métodos no incluyen Crédito, Contraentrega ni Puntos', () async {
      final repo = _FakeSellerPaymentRepository();
      final p = _provider(repo);

      final methods = await p.loadPaymentMethods();
      await p.loadPaymentMethods();
      await p.loadSellers();
      await p.loadSellers();
      await p.loadFilterClients();
      await p.loadAllClients();
      await p.loadAllClients();

      expect(methods.map((m) => m.name), ['YAPE', 'EFECTIVO', 'TRANSFERENCIA']);
      expect(repo.methodCalls, 1);
      expect(repo.sellerCalls, 1);
      expect(repo.clientCalls, [true, false]);
    });

    test('registrar un pago junta la fecha elegida con la hora de ahora y recarga la lista', () async {
      final repo = _FakeSellerPaymentRepository();
      final p = _provider(repo);

      final result = await p.createPayment(
        clientId: 7,
        moneda: 'dolares',
        date: DateTime(2026, 11, 5),
        lines: const [SellerPaymentLine(paymentMethodId: 2, monto: 30)],
      );

      expect(result.isRight, isTrue);
      expect(repo.created!.clientId, 7);
      expect(repo.created!.moneda, 'dolares');
      expect(repo.created!.creado, DateTime(2026, 11, 5, 10, 30, 15));
      expect(repo.calls, hasLength(1));

      await p.createPayment(
        clientId: 7,
        moneda: 'soles',
        lines: const [SellerPaymentLine(paymentMethodId: 2, monto: 30)],
      );
      expect(repo.created!.creado, isNull);
    });

    test('si registrar falla devuelve el error y no recarga', () async {
      final repo = _FakeSellerPaymentRepository()..actionFailure = const ValidationFailure('El monto es obligatorio');
      final p = _provider(repo);

      final result = await p.createPayment(
        clientId: 7,
        moneda: 'soles',
        lines: const [SellerPaymentLine(paymentMethodId: 2, monto: 30)],
      );

      expect(result.isLeft, isTrue);
      expect(result.left.message, 'El monto es obligatorio');
      expect(repo.calls, isEmpty);
    });

    test('editar un pago con cuotas edita su primera parte, con el monto si no está confirmada', () async {
      final repo = _FakeSellerPaymentRepository();
      final p = _provider(repo);

      await p.editPayment(_payment(), paymentMethodId: 3, monto: 80);
      expect(repo.editedInstallment, (id: 31, method: 3, monto: 80.0));
      expect(repo.edited, isNull);

      await p.editPayment(_payment(estado: 1, confirmedPart: true), paymentMethodId: 3, monto: 80);
      expect(repo.editedInstallment!.monto, isNull);
    });

    test('editar un saldo a favor usa edit-payment-seller con el id del pago', () async {
      final repo = _FakeSellerPaymentRepository();
      final p = _provider(repo);

      await p.editPayment(_payment(id: 2, favor: true), paymentMethodId: 4);

      expect(repo.edited, (id: 2, method: 4));
      expect(repo.editedInstallment, isNull);
    });

    test('las notas se piden, se agregan (sin espacios sobrantes) y se eliminan', () async {
      final repo = _FakeSellerPaymentRepository();
      final p = _provider(repo);

      final notes = await p.loadNotes(1);
      final added = await p.addNote(1, '  Pagó por Yape  ');
      final removed = await p.deleteNote(11);

      expect(notes.right.notas.map((n) => n.id), [11, 9, 10]);
      expect(notes.right.puedeEscribir, isTrue);
      expect(repo.notesLoadedFor, [1]);
      expect(repo.addedNotes, [(paymentId: 1, texto: 'Pagó por Yape')]);
      expect(added.right.autor, 'Ana');
      expect(repo.deletedNotes, [11]);
      expect(removed.right.eliminada, isTrue);
      expect(removed.right.eliminadaPor, 'Ana');
    });

    test('editar una nota manda el texto sin espacios sobrantes y devuelve la nota con su fecha de edición', () async {
      final repo = _FakeSellerPaymentRepository();
      final p = _provider(repo);

      final result = await p.editNote(11, '  Texto corregido ');

      expect(repo.editedNotes, [(noteId: 11, texto: 'Texto corregido')]);
      expect(result.right.texto, 'Texto corregido');
      expect(result.right.editada, isTrue);
      expect(result.right.autor, 'LUIS VENDEDOR');
    });

    test('si editar la nota falla devuelve el motivo del servidor', () async {
      final repo = _FakeSellerPaymentRepository()..editNoteFailure = const ValidationFailure('No hay cambios en la nota');
      final p = _provider(repo);

      final result = await p.editNote(11, 'x');

      expect(result.isLeft, isTrue);
      expect(result.left.message, 'No hay cambios en la nota');
    });

    test('si las notas fallan devuelve el error del servidor', () async {
      final repo = _FakeSellerPaymentRepository()
        ..notesFailure = const ServerFailure('Sin conexión')
        ..noteActionFailure = const ValidationFailure('Escribe la nota');
      final p = _provider(repo);

      expect((await p.loadNotes(1)).left.message, 'Sin conexión');
      expect((await p.addNote(1, 'x')).left.message, 'Escribe la nota');
      expect((await p.deleteNote(1)).left.message, 'Escribe la nota');
    });

    test('aprobar y eliminar recargan; un pago aprobado se elimina por la ruta post-confirmación', () async {
      final repo = _FakeSellerPaymentRepository();
      final p = _provider(repo);

      await p.approvePayment(_payment());
      await p.deletePayment(_payment(id: 3));
      await p.deletePayment(_payment(id: 4, estado: 1));

      expect(repo.approved, [1]);
      expect(repo.deleted, [(id: 3, afterConfirm: false), (id: 4, afterConfirm: true)]);
      expect(repo.calls, hasLength(3));
    });

    test('exportAll devuelve el Excel con su nombre y manda la búsqueda y los filtros', () async {
      final repo = _FakeSellerPaymentRepository();
      final p = _provider(repo);
      await p.addSearchTerm('acme');
      await p.applyFilters(p.filters.copyWith(estado: SellerPaymentStatus.pendiente));

      final result = await p.exportAll();

      expect(result.isRight, isTrue);
      expect(result.right.name, 'Registro de Pagos de Vendedores.xlsx');
      expect(result.right.bytes, [1, 2, 3]);
      expect(repo.exported!.estado, SellerPaymentStatus.pendiente);
      expect(repo.exported!.search, ['acme']);
      expect(p.exporting, isFalse);
    });

    test('al cambiar de empresa se descarta todo', () async {
      final repo = _FakeSellerPaymentRepository();
      final p = _provider(repo);
      await p.refresh();
      await p.addSearchTerm('x');
      await p.loadSellers();

      p.syncSession(_session(companyId: 2));

      expect(p.items, isEmpty);
      expect(p.searchTerms, isEmpty);
      expect(p.sellers, isNull);
      expect(p.filtersCount, 0);
    });
  });

  group('Pantalla de Pagos vendedores', () {
    testWidgets('muestra los pagos con monto, método, descripción y estado', (tester) async {
      await _pump(tester, setUp: (r) => r.items = [_payment(), _payment(id: 2, favor: true)]);

      expect(find.text('Pagos vendedores'), findsWidgets);
      expect(find.byType(AppListCard), findsNWidgets(2));
      expect(find.text('ACME SAC'), findsOneWidget);
      expect(find.text('S/. 150.50'), findsOneWidget);
      expect(find.text('10/11/2026'), findsOneWidget);
      expect(find.text('Método: YAPE / EFECTIVO'), findsOneWidget);
      // La última nota y, con más de una, cuántas hay.
      expect(find.text('Nota: Cuota 1 (2 notas)'), findsOneWidget);
      expect(find.text('Pendiente'), findsOneWidget);
      expect(find.text('Ana Pérez'), findsOneWidget);
      expect(find.text(r'$. 250.00'), findsOneWidget);
      expect(find.text('Nota: Anticipo'), findsOneWidget);
      expect(find.text('Aprobado'), findsOneWidget);
    });

    testWidgets('la columna Ejecutivo solo la ve quien ve los pagos de todos', (tester) async {
      await _pump(tester);
      expect(find.textContaining('Ejecutivo:'), findsNothing);
    });

    testWidgets('quien ve los pagos de todos ve el ejecutivo comercial', (tester) async {
      await _pump(tester, permissions: const {'pagos-vendedores.index', 'pagos-vendedores.showOthersSellers'});
      expect(find.text('Ejecutivo: LUIS V.'), findsOneWidget);
    });

    testWidgets('los totales están en Acciones → Totales, en soles y dólares', (tester) async {
      await _pump(tester);

      expect(find.byType(AppMetricCard), findsNothing);
      await tester.tap(find.text('Acciones'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Totales'));
      await tester.pumpAndSettle();

      expect(find.text('Total Soles'), findsOneWidget);
      expect(find.text('S/. 9,000.25'), findsOneWidget);
      expect(find.text('Total Dólares'), findsOneWidget);
      expect(find.text(r'$. 120.00'), findsOneWidget);
      expect(find.text('01 nov. 2026 - 30 nov. 2026'), findsOneWidget);
    });

    testWidgets('sin pagos dice que no hay', (tester) async {
      await _pump(tester, setUp: (r) => r.items = []);
      expect(find.text('No hay pagos'), findsOneWidget);
    });

    testWidgets('si falla muestra el error y Reintentar vuelve a pedir', (tester) async {
      final r = await _pump(tester, setUp: (r) => r.failure = const ServerFailure('Sin conexión con el servidor'));

      expect(find.text('No se pudieron cargar los pagos'), findsOneWidget);
      expect(find.text('Sin conexión con el servidor'), findsOneWidget);

      r.repo.failure = null;
      await tester.tap(find.text('Reintentar'));
      await tester.pumpAndSettle();

      expect(find.text('ACME SAC'), findsOneWidget);
      expect(r.repo.calls, hasLength(2));
    });

    testWidgets('sin permiso pagos-vendedores.index no pide nada y avisa', (tester) async {
      final r = await _pump(tester, permissions: const {});

      expect(find.text('Sin acceso'), findsOneWidget);
      expect(find.byType(AppListCard), findsNothing);
      expect(r.repo.calls, isEmpty);
    });

    testWidgets('tocar un pago abre su detalle', (tester) async {
      await _pump(tester, permissions: const {'pagos-vendedores.index', 'pagos-vendedores.showOthersSellers'});

      await tester.tap(find.text('ACME SAC'));
      await tester.pumpAndSettle();

      expect(find.text('Pago 1'), findsOneWidget);
      expect(find.text('Notas del pago'), findsOneWidget);
      expect(find.text('Cerrar'), findsOneWidget);
    });

    testWidgets('el detalle muestra las notas con autor (nombre + inicial) y fecha, sin las eliminadas', (tester) async {
      final r = await _pump(tester);

      await tester.tap(find.text('ACME SAC'));
      await tester.pumpAndSettle();

      expect(r.repo.notesLoadedFor, [1]);
      expect(find.text('Segunda nota'), findsOneWidget);
      // El autor sale como nombre + inicial del apellido.
      expect(find.textContaining('LUIS V.', findRichText: true), findsWidgets);
      expect(find.textContaining('FRANCIS B.', findRichText: true), findsWidgets);
      expect(find.textContaining('VENDEDOR', findRichText: true), findsNothing);
      expect(find.textContaining('12/11/2026 03:05 pm', findRichText: true), findsOneWidget);
      // Una nota eliminada ya no se ve.
      expect(find.text('Cuota 1'), findsNothing);
      expect(find.textContaining('Eliminada por'), findsNothing);
      // Solo las que el servidor deja eliminar tienen el botón.
      expect(find.byTooltip('Eliminar nota'), findsOneWidget);
    });

    testWidgets('sin pagos-vendedores.notas (puede_escribir falso) no hay caja para escribir', (tester) async {
      await _pump(tester, setUp: (r) => r.canWriteNotes = false);

      await tester.tap(find.text('ACME SAC'));
      await tester.pumpAndSettle();

      expect(find.text('Segunda nota'), findsOneWidget);
      expect(find.byKey(const ValueKey('nota-texto')), findsNothing);
      expect(find.text('Agregar nota'), findsNothing);
    });

    testWidgets('un pago sin notas dice "Sin notas"', (tester) async {
      await _pump(tester, setUp: (r) => r.notes = []);

      await tester.tap(find.text('ACME SAC'));
      await tester.pumpAndSettle();

      expect(find.text('Sin notas'), findsOneWidget);
    });

    testWidgets('si las notas no cargan muestra el error en el detalle', (tester) async {
      await _pump(tester, setUp: (r) => r.notesFailure = const ServerFailure('No autorizado'));

      await tester.tap(find.text('ACME SAC'));
      await tester.pumpAndSettle();

      expect(find.text('No autorizado'), findsOneWidget);
    });

    testWidgets('agregar una nota la pone primera y al cerrar se refresca la lista', (tester) async {
      final r = await _pump(tester, size: const Size(400, 1400));

      await tester.tap(find.text('ACME SAC'));
      await tester.pumpAndSettle();
      final add = tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Agregar nota'));
      expect(add.onPressed, isNull);

      await tester.enterText(find.byKey(const ValueKey('nota-texto')), '  Llamar el lunes ');
      await tester.pump();
      await tester.tap(find.widgetWithText(FilledButton, 'Agregar nota'));
      await tester.pumpAndSettle();

      expect(r.repo.addedNotes, [(paymentId: 1, texto: 'Llamar el lunes')]);
      expect(find.text('Llamar el lunes'), findsOneWidget);
      // La nota nueva sale con el nombre de quien la escribió y la fecha.
      expect(find.textContaining('Ana  17/11/2026 03:05 pm', findRichText: true), findsOneWidget);
      // La caja queda vacía y la lista aún no se pidió de nuevo (se hace al cerrar).
      expect(tester.widget<TextField>(find.byKey(const ValueKey('nota-texto'))).controller!.text, isEmpty);
      expect(r.repo.calls, hasLength(1));

      await tester.tap(find.text('Cerrar'));
      await tester.pumpAndSettle();
      expect(r.repo.calls, hasLength(2));
    });

    testWidgets('si el servidor rechaza la nota muestra el motivo', (tester) async {
      final r = await _pump(tester, size: const Size(400, 1400));
      r.repo.noteActionFailure = const ValidationFailure('Escribe la nota');

      await tester.tap(find.text('ACME SAC'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const ValueKey('nota-texto')), 'Hola');
      await tester.pump();
      await tester.tap(find.widgetWithText(FilledButton, 'Agregar nota'));
      await tester.pumpAndSettle();

      expect(find.text('Escribe la nota'), findsOneWidget);
      expect(find.text('Hola'), findsOneWidget);
    });

    testWidgets('eliminar una nota pide confirmación y desaparece de la lista', (tester) async {
      final r = await _pump(tester, size: const Size(400, 1400));

      await tester.tap(find.text('ACME SAC'));
      await tester.pumpAndSettle();
      expect(find.text('Segunda nota'), findsOneWidget);
      await tester.tap(find.byTooltip('Eliminar nota'));
      await tester.pumpAndSettle();
      expect(find.text('¿Eliminar esta nota?'), findsOneWidget);
      expect(r.repo.deletedNotes, isEmpty);

      await tester.tap(find.text('Eliminar'));
      await tester.pumpAndSettle();

      expect(r.repo.deletedNotes, [11]);
      // La nota eliminada ya no se ve (ni tachada ni con quién la eliminó).
      expect(find.text('Segunda nota'), findsNothing);
      expect(find.textContaining('Eliminada por'), findsNothing);
      expect(find.byTooltip('Eliminar nota'), findsNothing);
    });

    testWidgets('cancelar la confirmación no elimina la nota', (tester) async {
      final r = await _pump(tester, size: const Size(400, 1400));

      await tester.tap(find.text('ACME SAC'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Eliminar nota'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();

      expect(r.repo.deletedNotes, isEmpty);
    });

    testWidgets('solo las notas propias (puede_editar) tienen lápiz', (tester) async {
      await _pump(tester, size: const Size(400, 1400));

      await tester.tap(find.text('ACME SAC'));
      await tester.pumpAndSettle();

      // De las tres notas, solo la de LUIS (la del usuario) se puede editar.
      expect(find.byTooltip('Editar nota'), findsOneWidget);
    });

    testWidgets('las notas editadas dicen cuándo, salvo las eliminadas', (tester) async {
      await _pump(tester, size: const Size(400, 1400));

      await tester.tap(find.text('ACME SAC'));
      await tester.pumpAndSettle();

      expect(find.text('Editada el 09/11/2026 08:15 am'), findsOneWidget);
      // La eliminada también se editó, pero ya no se ve.
      expect(find.text('Editada el 10/11/2026 10:00 am'), findsNothing);
      expect(find.textContaining('Eliminada por'), findsNothing);
      expect(find.text('Segunda nota'), findsOneWidget);
    });

    testWidgets('editar una nota: la caja trae el texto con contador, Guardar espera cambios y se reemplaza en la lista', (tester) async {
      final r = await _pump(tester, size: const Size(400, 1400));

      await tester.tap(find.text('ACME SAC'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Editar nota'));
      await tester.pumpAndSettle();

      final field = find.byKey(const ValueKey('nota-editar-texto'));
      expect(field, findsOneWidget);
      expect(tester.widget<TextField>(field).controller!.text, 'Segunda nota');
      expect(find.text('12/1000'), findsOneWidget);
      // Mientras se edita no están el lápiz ni el bote de esa nota.
      expect(find.byTooltip('Editar nota'), findsNothing);
      // Sin cambios no se puede guardar.
      expect(tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Guardar')).onPressed, isNull);

      await tester.enterText(field, 'Texto corregido');
      await tester.pump();
      expect(tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Guardar')).onPressed, isNotNull);

      await tester.tap(find.widgetWithText(FilledButton, 'Guardar'));
      await tester.pumpAndSettle();

      expect(r.repo.editedNotes, [(noteId: 11, texto: 'Texto corregido')]);
      expect(find.byKey(const ValueKey('nota-editar-texto')), findsNothing);
      expect(find.text('Texto corregido'), findsOneWidget);
      expect(find.text('Segunda nota'), findsNothing);
      expect(find.text('Editada el 17/11/2026 05:00 pm'), findsOneWidget);
      // La tarjeta de la lista se refresca al cerrar (muestra la última nota).
      expect(r.repo.calls, hasLength(1));
      await tester.tap(find.text('Cerrar'));
      await tester.pumpAndSettle();
      expect(r.repo.calls, hasLength(2));
    });

    testWidgets('un texto vacío o igual al original deja Guardar deshabilitado', (tester) async {
      final r = await _pump(tester, size: const Size(400, 1400));

      await tester.tap(find.text('ACME SAC'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Editar nota'));
      await tester.pumpAndSettle();

      final field = find.byKey(const ValueKey('nota-editar-texto'));
      await tester.enterText(field, '   ');
      await tester.pump();
      expect(tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Guardar')).onPressed, isNull);

      // Con espacios alrededor sigue siendo el mismo texto.
      await tester.enterText(field, '  Segunda nota ');
      await tester.pump();
      expect(tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Guardar')).onPressed, isNull);
      expect(r.repo.editedNotes, isEmpty);
    });

    testWidgets('Cancelar la edición deja la nota como estaba y no llama al servidor', (tester) async {
      final r = await _pump(tester, size: const Size(400, 1400));

      await tester.tap(find.text('ACME SAC'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Editar nota'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const ValueKey('nota-editar-texto')), 'Otra cosa');
      await tester.pump();
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('nota-editar-texto')), findsNothing);
      expect(find.text('Segunda nota'), findsOneWidget);
      expect(find.text('Otra cosa'), findsNothing);
      expect(find.byTooltip('Editar nota'), findsOneWidget);
      expect(r.repo.editedNotes, isEmpty);

      // Al reabrirla vuelve el texto original, no lo que se había escrito.
      await tester.tap(find.byTooltip('Editar nota'));
      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(find.byKey(const ValueKey('nota-editar-texto'))).controller!.text, 'Segunda nota');
    });

    testWidgets('si el servidor rechaza la edición muestra el motivo sin perder lo escrito', (tester) async {
      final r = await _pump(tester, size: const Size(400, 1400));
      r.repo.editNoteFailure = const ValidationFailure('No hay cambios en la nota');

      await tester.tap(find.text('ACME SAC'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Editar nota'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const ValueKey('nota-editar-texto')), 'Mi corrección');
      await tester.pump();
      await tester.tap(find.widgetWithText(FilledButton, 'Guardar'));
      await tester.pumpAndSettle();

      expect(find.text('No hay cambios en la nota'), findsOneWidget);
      final field = find.byKey(const ValueKey('nota-editar-texto'));
      expect(field, findsOneWidget);
      expect(tester.widget<TextField>(field).controller!.text, 'Mi corrección');
      // Sigue guardable para reintentar.
      expect(tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Guardar')).onPressed, isNotNull);
      // No se refrescó la lista: no hubo cambios.
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cerrar'));
      await tester.pumpAndSettle();
      expect(r.repo.calls, hasLength(1));
    });

    testWidgets('solo una nota se edita a la vez', (tester) async {
      await _pump(
        tester,
        size: const Size(400, 1400),
        setUp: (r) => r.notes = [
          SellerPaymentNote(id: 21, texto: 'Primera mía', creado: DateTime(2026, 11, 12, 15, 5), autor: 'Ana', puedeEditar: true),
          SellerPaymentNote(id: 20, texto: 'Segunda mía', creado: DateTime(2026, 11, 11, 15, 5), autor: 'Ana', puedeEditar: true),
        ],
      );

      await tester.tap(find.text('ACME SAC'));
      await tester.pumpAndSettle();
      expect(find.byTooltip('Editar nota'), findsNWidgets(2));

      await tester.tap(find.byTooltip('Editar nota').first);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('nota-editar-texto')), findsOneWidget);
      await tester.enterText(find.byKey(const ValueKey('nota-editar-texto')), 'Cambio a medias');
      await tester.pump();

      // Editar la otra cierra la primera (sin guardar) y abre la segunda.
      await tester.tap(find.byTooltip('Editar nota'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('nota-editar-texto')), findsOneWidget);
      expect(tester.widget<TextField>(find.byKey(const ValueKey('nota-editar-texto'))).controller!.text, 'Segunda mía');
      expect(find.text('Primera mía'), findsOneWidget);
      expect(find.text('Cambio a medias'), findsNothing);
    });

    testWidgets('en el modal de editar el pago también se edita una nota propia', (tester) async {
      final r = await _pump(tester, permissions: _allPermissions, size: const Size(400, 1600));

      await tester.tap(find.byTooltip('Editar'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Editar nota'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const ValueKey('nota-editar-texto')), 'Corregida en el modal');
      await tester.pump();
      await tester.tap(find.widgetWithText(FilledButton, 'Guardar'));
      await tester.pumpAndSettle();

      expect(r.repo.editedNotes, [(noteId: 11, texto: 'Corregida en el modal')]);
      expect(r.repo.editedInstallment, isNull);
      expect(find.text('Corregida en el modal'), findsOneWidget);
    });

    testWidgets('sin permiso de notas ninguna nota tiene lápiz', (tester) async {
      await _pump(
        tester,
        size: const Size(400, 1400),
        setUp: (r) => r.notes = [
          SellerPaymentNote(id: 21, texto: 'De otro', creado: DateTime(2026, 11, 12, 15, 5), autor: 'LUIS'),
        ],
      );

      await tester.tap(find.text('ACME SAC'));
      await tester.pumpAndSettle();

      expect(find.text('De otro'), findsOneWidget);
      expect(find.byTooltip('Editar nota'), findsNothing);
    });

    testWidgets('sin permisos de acción no hay botones en las filas', (tester) async {
      await _pump(tester);
      expect(find.byTooltip('Confirmar pago'), findsNothing);
      expect(find.byTooltip('Editar'), findsNothing);
      expect(find.byTooltip('Eliminar pago'), findsNothing);
    });

    testWidgets('un pago pendiente se confirma, edita o elimina según permisos', (tester) async {
      await _pump(tester, permissions: _allPermissions);
      expect(find.byTooltip('Confirmar pago'), findsOneWidget);
      expect(find.byTooltip('Editar'), findsOneWidget);
      expect(find.byTooltip('Eliminar pago'), findsOneWidget);
    });

    testWidgets('un pago aprobado solo se elimina con post-confirm.destroy y se edita con update o post-confirm.update', (tester) async {
      await _pump(
        tester,
        permissions: const {'pagos-vendedores.index', 'pagos-vendedores.post-confirm.destroy'},
        setUp: (r) => r.items = [_payment(estado: 1, confirmedPart: true)],
      );
      expect(find.byTooltip('Confirmar pago'), findsNothing);
      expect(find.byTooltip('Editar'), findsNothing);
      expect(find.byTooltip('Eliminar pago'), findsOneWidget);
    });

    testWidgets('un pago aprobado se edita con post-confirm.update', (tester) async {
      await _pump(
        tester,
        permissions: const {'pagos-vendedores.index', 'pagos-vendedores.post-confirm.update'},
        setUp: (r) => r.items = [_payment(estado: 1, confirmedPart: true)],
      );
      expect(find.byTooltip('Editar'), findsOneWidget);
      expect(find.byTooltip('Eliminar pago'), findsNothing);
    });

    testWidgets('un pago cancelado no tiene acciones', (tester) async {
      await _pump(
        tester,
        permissions: _allPermissions,
        setUp: (r) => r.items = [_payment(estado: 0)],
      );
      expect(find.text('Cancelado'), findsOneWidget);
      expect(find.byTooltip('Confirmar pago'), findsNothing);
      expect(find.byTooltip('Editar'), findsNothing);
      expect(find.byTooltip('Eliminar pago'), findsNothing);
    });

    testWidgets('confirmar un pago pide confirmación y lo aprueba', (tester) async {
      final r = await _pump(tester, permissions: _allPermissions);

      await tester.tap(find.byTooltip('Confirmar pago'));
      await tester.pumpAndSettle();
      expect(find.text('¿Estás seguro de confirmar el pago?'), findsOneWidget);
      expect(r.repo.approved, isEmpty);

      await tester.tap(find.text('Confirmar'));
      await tester.pumpAndSettle();

      expect(r.repo.approved, [1]);
      expect(find.text('Pago confirmado'), findsOneWidget);
      expect(r.repo.calls, hasLength(2));
    });

    testWidgets('eliminar un pago pendiente pide confirmación', (tester) async {
      final r = await _pump(tester, permissions: _allPermissions);

      await tester.tap(find.byTooltip('Eliminar pago'));
      await tester.pumpAndSettle();
      expect(find.text('¿Está seguro de eliminar este Pago?'), findsOneWidget);

      await tester.tap(find.text('Eliminar'));
      await tester.pumpAndSettle();

      expect(r.repo.deleted, [(id: 1, afterConfirm: false)]);
    });

    testWidgets('eliminar un pago confirmado avisa que queda marcado como eliminado', (tester) async {
      final r = await _pump(
        tester,
        permissions: _allPermissions,
        setUp: (r) => r.items = [_payment(estado: 1, confirmedPart: true)],
      );

      await tester.tap(find.byTooltip('Eliminar pago'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Se mantendrá visible pero marcado como eliminado'), findsOneWidget);

      await tester.tap(find.text('Eliminar'));
      await tester.pumpAndSettle();

      expect(r.repo.deleted, [(id: 1, afterConfirm: true)]);
    });

    testWidgets('si eliminar falla muestra el mensaje del servidor', (tester) async {
      final r = await _pump(tester, permissions: _allPermissions);
      r.repo.actionFailure = const ValidationFailure('No se pudo eliminar');

      await tester.tap(find.byTooltip('Eliminar pago'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Eliminar'));
      await tester.pumpAndSettle();

      expect(find.text('No se pudo eliminar'), findsOneWidget);
    });

    testWidgets('editar un pago con cuotas muestra el total y guarda sobre su primera parte', (tester) async {
      final r = await _pump(tester, permissions: _allPermissions);

      await tester.tap(find.byTooltip('Editar'));
      await tester.pumpAndSettle();

      expect(find.text('Editar Pago de Cuota'), findsOneWidget);
      expect(find.textContaining('Este es un pago de saldo a favor'), findsNothing);
      expect(find.widgetWithText(TextFormField, '150.5'), findsOneWidget);
      // La descripción ya no es un campo editable: son las notas del pago.
      expect(find.widgetWithText(TextFormField, 'Descripción adicional'), findsNothing);
      expect(find.text('Notas del pago'), findsOneWidget);
      expect(find.text('Segunda nota'), findsOneWidget);
      expect(r.repo.notesLoadedFor, [1]);

      await tester.enterText(find.widgetWithText(TextFormField, '150.5'), '120');
      await tester.tap(find.text('Editar').last);
      await tester.pumpAndSettle();

      expect(r.repo.editedInstallment, (id: 31, method: 2, monto: 120.0));
      expect(find.text('Pago editado'), findsOneWidget);
    });

    testWidgets('en el modal de editar se agrega una nota sin guardar el pago y la lista se refresca al cerrar', (tester) async {
      final r = await _pump(tester, permissions: _allPermissions, size: const Size(400, 1600));

      await tester.tap(find.byTooltip('Editar'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const ValueKey('nota-texto')), 'Nota desde editar');
      await tester.pump();
      await tester.tap(find.widgetWithText(FilledButton, 'Agregar nota'));
      await tester.pumpAndSettle();

      expect(r.repo.addedNotes, [(paymentId: 1, texto: 'Nota desde editar')]);
      expect(r.repo.editedInstallment, isNull);
      expect(r.repo.calls, hasLength(1));

      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();
      expect(r.repo.calls, hasLength(2));
      expect(r.repo.editedInstallment, isNull);
    });

    testWidgets('en el modal de editar se elimina una nota con confirmación', (tester) async {
      final r = await _pump(tester, permissions: _allPermissions, size: const Size(400, 1600));

      await tester.tap(find.byTooltip('Editar'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Eliminar nota'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Eliminar'));
      await tester.pumpAndSettle();

      expect(r.repo.deletedNotes, [11]);
      expect(find.text('Editar Pago de Cuota'), findsOneWidget);
    });

    testWidgets('el monto es obligatorio y mayor a cero al editar', (tester) async {
      final r = await _pump(tester, permissions: _allPermissions);

      await tester.tap(find.byTooltip('Editar'));
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextFormField, '150.5'), '0');
      await tester.tap(find.text('Editar').last);
      await tester.pumpAndSettle();

      expect(find.text('El monto debe ser mayor a 0'), findsOneWidget);
      expect(r.repo.editedInstallment, isNull);
    });

    testWidgets('en un pago ya confirmado el monto no se puede cambiar', (tester) async {
      final r = await _pump(
        tester,
        permissions: _allPermissions,
        setUp: (r) => r.items = [_payment(estado: 1, confirmedPart: true)],
      );

      await tester.tap(find.byTooltip('Editar'));
      await tester.pumpAndSettle();

      final amount = tester.widget<TextFormField>(find.widgetWithText(TextFormField, '150.5'));
      expect(amount.enabled, isFalse);

      await tester.tap(find.text('Editar').last);
      await tester.pumpAndSettle();
      expect(r.repo.editedInstallment!.monto, isNull);
    });

    testWidgets('un saldo a favor solo edita método y descripción', (tester) async {
      final r = await _pump(
        tester,
        permissions: _allPermissions,
        setUp: (r) => r.items = [_payment(id: 2, favor: true, estado: 2)],
      );

      await tester.tap(find.byTooltip('Editar'));
      await tester.pumpAndSettle();

      expect(find.text('Editar Pago (Saldo a Favor)'), findsOneWidget);
      expect(find.textContaining('Este es un pago de saldo a favor. Solo puedes editar el método de pago'), findsOneWidget);
      expect(find.text(r'$. 250.00'), findsWidgets);

      await tester.tap(find.text('Editar').last);
      await tester.pumpAndSettle();

      expect(r.repo.edited, (id: 2, method: 4));
    });

    testWidgets('si editar falla el modal sigue abierto con el mensaje', (tester) async {
      final r = await _pump(tester, permissions: _allPermissions);
      r.repo.actionFailure = const ValidationFailure('Monto inválido');

      await tester.tap(find.byTooltip('Editar'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Editar').last);
      await tester.pumpAndSettle();

      expect(find.text('Monto inválido'), findsOneWidget);
      expect(find.text('Editar Pago de Cuota'), findsOneWidget);
    });

    testWidgets('Realizar pago solo está con pagos-vendedores.store', (tester) async {
      await _pump(tester);
      await tester.tap(find.text('Acciones'));
      await tester.pumpAndSettle();
      expect(find.byTooltip('Realizar pago'), findsNothing);
      expect(find.byTooltip('Totales'), findsOneWidget);
    });

    testWidgets('realizar un pago: elegir cliente, ver su deuda, método, monto y registrar', (tester) async {
      final r = await _pump(tester, permissions: _allPermissions, size: const Size(400, 1600));

      await tester.tap(find.text('Acciones'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Realizar pago'));
      await tester.pumpAndSettle();

      expect(find.text('Realizar Pago de Cuota'), findsOneWidget);
      // Sin cliente, "Realizar" no se puede.
      final disabled = tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Realizar'));
      expect(disabled.onPressed, isNull);
      expect(find.text('El cliente no tiene deuda en soles: el monto ingresado se guardará como anticipo.'), findsOneWidget);

      await tester.tap(find.text('Buscar cliente'));
      await tester.pumpAndSettle();
      expect(r.repo.clientCalls.last, isFalse);
      await tester.tap(find.text('DISTRIBUIDORA SUR'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Aplicar'));
      await tester.pumpAndSettle();

      expect(r.repo.debtClientId, 7);
      expect(find.text('Se distribuirá el depósito sobre las cuotas más antiguas en soles.'), findsOneWidget);
      expect(find.text('S/. 1,200.00'), findsWidgets);

      await tester.tap(find.byType(DropdownButtonFormField<int>).first);
      await tester.pumpAndSettle();
      // Crédito, Contraentrega y Puntos no se ofrecen.
      expect(find.text('CRÉDITO'), findsNothing);
      expect(find.text('PUNTOS'), findsNothing);
      await tester.tap(find.text('YAPE').last);
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextFormField, 'Monto'), '300.50');
      await tester.enterText(find.widgetWithText(TextFormField, 'Descripción adicional'), 'Depósito BCP');

      await tester.tap(find.widgetWithText(FilledButton, 'Realizar'));
      await tester.pumpAndSettle();

      final created = r.repo.created!;
      expect(created.clientId, 7);
      expect(created.moneda, 'soles');
      expect(created.creado, isNull);
      expect(created.lines.single.paymentMethodId, 2);
      expect(created.lines.single.monto, 300.5);
      expect(created.lines.single.descripcionAdicional, 'Depósito BCP');
      expect(find.text('Depósito aplicado a la deuda'), findsOneWidget);
      expect(r.repo.calls, hasLength(2));
    });

    testWidgets('si el cliente solo debe dólares la moneda queda en dólares', (tester) async {
      final r = await _pump(
        tester,
        permissions: _allPermissions,
        size: const Size(400, 1600),
        setUp: (r) => r.debt = const SellerClientDebt(soles: 0, dolares: 80),
      );

      await tester.tap(find.text('Acciones'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Realizar pago'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Buscar cliente'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('ALMACENES NORTE'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Aplicar'));
      await tester.pumpAndSettle();

      expect(find.text('Se distribuirá el depósito sobre las cuotas más antiguas en dólares.'), findsOneWidget);
      expect(find.text('Deuda total dólares'), findsOneWidget);
      expect(find.text(r'$. 80.00'), findsWidgets);
      expect(r.repo.debtClientId, 8);
    });

    testWidgets('se pueden agregar y quitar métodos de pago; todos llevan método y monto', (tester) async {
      await _pump(tester, permissions: _allPermissions, size: const Size(400, 1600));

      await tester.tap(find.text('Acciones'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Realizar pago'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Buscar cliente'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('DISTRIBUIDORA SUR'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Aplicar'));
      await tester.pumpAndSettle();

      expect(find.text('Método de pago 1'), findsOneWidget);
      expect(find.byTooltip('Quitar método de pago'), findsNothing);
      await tester.ensureVisible(find.text('Agregar método de pago'));
      await tester.tap(find.text('Agregar método de pago'));
      await tester.pumpAndSettle();
      expect(find.text('Método de pago 2'), findsOneWidget);
      expect(find.byTooltip('Quitar método de pago'), findsOneWidget);

      // Sin llenar nada, no registra y avisa lo que falta.
      await tester.tap(find.widgetWithText(FilledButton, 'Realizar'));
      await tester.pumpAndSettle();
      expect(find.text('Elige el método de pago'), findsWidgets);
      expect(find.text('Escribe el monto'), findsWidgets);

      await tester.tap(find.byTooltip('Quitar método de pago'));
      await tester.pumpAndSettle();
      expect(find.text('Método de pago 2'), findsNothing);
    });

    testWidgets('escribir en el buscador filtra tras una pausa y Buscar deja el término como chip', (tester) async {
      final r = await _pump(tester);

      await tester.enterText(find.byType(SearchBar), 'acme');
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();
      expect(r.repo.calls.last.filters.search, ['acme']);

      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();
      expect(r.provider.searchTerms, ['acme']);
      expect(find.text('acme'), findsOneWidget);
      expect(r.repo.calls.last.filters.search, ['acme']);

      await tester.tap(find.byTooltip('Quitar "acme"'));
      await tester.pumpAndSettle();
      expect(r.repo.calls.last.filters.search, isEmpty);
    });

    testWidgets('el panel de filtros ofrece fechas, clientes, monto, métodos y estado; sin ver a todos no hay ejecutivo', (tester) async {
      await _pump(tester, size: const Size(400, 1400));

      await tester.tap(find.byTooltip('Filtros'));
      await tester.pumpAndSettle();

      expect(find.text('Filtros avanzados'), findsOneWidget);
      expect(find.text('Rango de fechas'), findsOneWidget);
      expect(find.text('01 nov. 2026 - 30 nov. 2026'), findsOneWidget);
      expect(find.text('Clientes'), findsOneWidget);
      expect(find.text('Monto desde'), findsOneWidget);
      expect(find.text('Monto hasta'), findsOneWidget);
      expect(find.text('Métodos de pago'), findsOneWidget);
      expect(find.text('Estado'), findsOneWidget);
      expect(find.text('Ejecutivo comercial'), findsNothing);
    });

    testWidgets('quien ve a todos filtra por ejecutivo comercial y queda como chip', (tester) async {
      final r = await _pump(
        tester,
        permissions: const {'pagos-vendedores.index', 'pagos-vendedores.showOthersSellers'},
        size: const Size(400, 1400),
      );

      await tester.tap(find.byTooltip('Filtros'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(AppPickerField, 'Todos').at(1));
      await tester.pumpAndSettle();
      await tester.tap(find.text('FRANCIS BULNES GONZALES'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Aplicar'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Aplicar filtros'));
      await tester.pumpAndSettle();

      expect(r.repo.calls.last.filters.ejecutivos, [4]);
      expect(find.text('Ejecutivo comercial: FRANCIS BULNES GONZALES'), findsOneWidget);
    });

    testWidgets('filtrar por estado deja un chip que se quita', (tester) async {
      final r = await _pump(tester, size: const Size(400, 1400));

      await tester.tap(find.byTooltip('Filtros'));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(DropdownButtonFormField<SellerPaymentStatus?>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Pendientes').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Aplicar filtros'));
      await tester.pumpAndSettle();

      expect(r.repo.calls.last.filters.estado, SellerPaymentStatus.pendiente);
      expect(find.text('Estado: Pendientes'), findsOneWidget);

      await tester.ensureVisible(find.byTooltip('Quitar Estado: Pendientes'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Quitar Estado: Pendientes'));
      await tester.pumpAndSettle();
      expect(r.repo.calls.last.filters.estado, isNull);
      expect(find.text('Estado: Pendientes'), findsNothing);
    });

    testWidgets('con los montos al revés se ordenan', (tester) async {
      final r = await _pump(tester, size: const Size(400, 1400));

      await tester.tap(find.byTooltip('Filtros'));
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextField, 'Monto desde'), '100');
      await tester.enterText(find.widgetWithText(TextField, 'Monto hasta'), '50');
      await tester.tap(find.text('Aplicar filtros'));
      await tester.pumpAndSettle();

      expect(r.repo.calls.last.filters.montoMin, 50);
      expect(r.repo.calls.last.filters.montoMax, 100);
      expect(find.text('Monto: 50 - 100'), findsOneWidget);
    });

    testWidgets('elegir "Hoy" en el panel cambia el rango y su chip vuelve al mes al quitarlo', (tester) async {
      final r = await _pump(tester, size: const Size(400, 1400));

      await tester.tap(find.byTooltip('Filtros'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Hoy'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Aplicar filtros'));
      await tester.pumpAndSettle();

      expect(r.repo.calls.last.filters.desde, DateTime(2026, 11, 17));
      expect(r.repo.calls.last.filters.hasta, DateTime(2026, 11, 17));
      expect(find.text('17 nov. 2026 - 17 nov. 2026'), findsOneWidget);

      await tester.ensureVisible(find.byTooltip('Quitar 17 nov. 2026 - 17 nov. 2026'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Quitar 17 nov. 2026 - 17 nov. 2026'));
      await tester.pumpAndSettle();
      expect(r.repo.calls.last.filters.desde, DateTime(2026, 11, 1));
      expect(r.repo.calls.last.filters.hasta, DateTime(2026, 11, 30));
    });

    testWidgets('el Excel se pide desde Acciones', (tester) async {
      final r = await _pump(tester);

      await tester.tap(find.text('Acciones'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Exportar Excel'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(r.repo.exported, isNotNull);
      expect(r.repo.exported!.desde, DateTime(2026, 11, 1));
    });

    testWidgets('en tablet hay dos paneles y se ve bien', (tester) async {
      await _pump(tester, size: const Size(1100, 800));

      expect(find.text('Selecciona un pago'), findsOneWidget);
      expect(tester.takeException(), isNull);
      expect(find.byType(AppListCard), findsOneWidget);
    });

    testWidgets('en modo oscuro y con letra grande no se desborda', (tester) async {
      await _pump(
        tester,
        permissions: _allPermissions,
        size: const Size(360, 640),
        mode: ThemeMode.dark,
        textScale: 1.4,
        setUp: (r) => r.items = [_payment(), _payment(id: 2, favor: true), _payment(id: 3, estado: 1, confirmedPart: true)],
      );

      expect(tester.takeException(), isNull);
      expect(find.byType(AppListCard), findsWidgets);
    });
  });
}
