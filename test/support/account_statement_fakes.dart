import 'dart:async';
import 'dart:typed_data';

import 'package:app_novik/core/errors/failures.dart';
import 'package:app_novik/core/utils/either.dart';
import 'package:app_novik/domain/entities/account_statement_entity.dart';
import 'package:app_novik/domain/entities/company_entity.dart';
import 'package:app_novik/domain/entities/document_entity.dart' show DownloadedFile;
import 'package:app_novik/domain/entities/module_entity.dart';
import 'package:app_novik/domain/entities/sale_entity.dart' show ClientEntity;
import 'package:app_novik/domain/entities/saved_credentials_entity.dart';
import 'package:app_novik/domain/entities/session_context_entity.dart';
import 'package:app_novik/domain/entities/user_entity.dart';
import 'package:app_novik/domain/repositories/account_statement_repository.dart';
import 'package:app_novik/domain/repositories/auth_repository.dart';
import 'package:app_novik/domain/usecases/account_statement_usecases.dart';
import 'package:app_novik/domain/usecases/auth_usecases.dart';
import 'package:app_novik/presentation/providers/account_statement_provider.dart';
import 'package:app_novik/presentation/providers/auth_provider.dart';
import 'package:flutter/foundation.dart' show VoidCallback;

const acme = ClientEntity(
  id: 7,
  name: 'ACME SAC',
  documento: '20123456789',
  tipo: 'e',
  credito: 5000,
  creditoDisponible: 3000,
);

const ana = ClientEntity(id: 8, name: 'ANA RUIZ', documento: '12345678', tipo: 'p');

StatementRowEntity saleRow(int n, {String titulo = 'SUBWOOFER'}) => StatementRowEntity(
      id: 's-$n',
      fecha: DateTime(2026, 11, 3),
      documento: 'B001-${n.toString().padLeft(4, '0')}',
      cantidad: 2,
      titulo: '$titulo $n',
      detalle: 'SUB-$n · 7POWER',
      soles: 100,
    );

StatementRowEntity paymentRow(int n) => StatementRowEntity(
      id: 'f-$n',
      fecha: DateTime(2026, 11, 4),
      documento: 'B001-0001',
      titulo: 'Pagó con YAPE',
      soles: 60,
      registradoPor: 'FRANCIS BULNES GONZALES',
      origen: 'Pago de cuota',
      esPago: true,
    );

const summary = StatementSummaryEntity(
  credito: 5000,
  creditoDisponible: 3000,
  lineaUtilizada: 2000,
  deudaTotalSoles: 1500.5,
  deudaTotalDolares: 20,
  deudaAnteriorSoles: 200,
);

/// Repositorio de prueba: sirve las filas que se le den y anota lo que le piden.
class FakeStatementRepository implements AccountStatementRepository {
  final List<String> calls = [];
  List<ClientEntity> clients = [acme, ana];
  List<StatementRowEntity> main = [saleRow(1), paymentRow(1)];
  List<StatementRowEntity> orders = [saleRow(2, titulo: 'PEDIDO')];
  List<StatementRowEntity> payments = [paymentRow(2)];
  StatementSummaryEntity mainSummary = summary;
  Failure? mainFailure;
  Failure? ordersFailure;
  StatementQuery? lastQuery;

  /// Si se pone, la respuesta de la pestaña principal espera a que se complete.
  Completer<void>? mainGate;

  Either<Failure, StatementPageEntity> _page(
    List<StatementRowEntity> all,
    int page,
    int size, {
    StatementSummaryEntity? sum,
  }) {
    final from = (page - 1) * size;
    final slice = from >= all.length ? <StatementRowEntity>[] : all.sublist(from, (from + size).clamp(0, all.length));
    return Either.right(StatementPageEntity(rows: slice, total: all.length, summary: sum));
  }

  @override
  Future<Either<Failure, List<ClientEntity>>> searchClients(int companyId, String search) async {
    calls.add('search:$search');
    return Either.right(clients);
  }

  @override
  Future<Either<Failure, StatementPageEntity>> getStatement(
    StatementQuery query, {
    required int page,
    required int pageSize,
  }) async {
    calls.add('main:$page');
    lastQuery = query;
    // Lo que había al pedirlo: una respuesta que se retrasa trae los datos de cuando salió.
    final rows = main;
    final failure = mainFailure;
    await mainGate?.future;
    if (failure != null) return Either.left(failure);
    return _page(rows, page, pageSize, sum: mainSummary);
  }

  @override
  Future<Either<Failure, StatementPageEntity>> getOrders(
    StatementQuery query, {
    required int page,
    required int pageSize,
  }) async {
    calls.add('orders:$page');
    lastQuery = query;
    if (ordersFailure != null) return Either.left(ordersFailure!);
    return _page(orders, page, pageSize);
  }

  @override
  Future<Either<Failure, StatementPageEntity>> getPayments(
    StatementQuery query, {
    required int page,
    required int pageSize,
  }) async {
    calls.add('payments:$page');
    lastQuery = query;
    return _page(payments, page, pageSize);
  }

  @override
  Future<Either<Failure, DownloadedFile>> exportExcel(StatementTab tab, StatementQuery query) async {
    calls.add('excel:${tab.name}');
    return Either.right(DownloadedFile(name: '${tab.fileName}.xlsx', bytes: Uint8List.fromList([1])));
  }

  @override
  Future<Either<Failure, Uint8List>> exportPdf(StatementQuery query) async {
    calls.add('pdf:${query.agrupado}');
    return Either.right(Uint8List.fromList([37, 80, 68, 70]));
  }
}

AccountStatementProvider statementProvider(
  FakeStatementRepository repo, {
  VoidCallback? onExpired,
  DateTime Function()? now,
}) =>
    AccountStatementProvider(
      searchClientsUseCase: SearchStatementClientsUseCase(repository: repo),
      getStatementUseCase: GetStatementUseCase(repository: repo),
      getOrdersUseCase: GetStatementOrdersUseCase(repository: repo),
      getPaymentsUseCase: GetStatementPaymentsUseCase(repository: repo),
      exportExcelUseCase: ExportStatementExcelUseCase(repository: repo),
      exportPdfUseCase: ExportStatementPdfUseCase(repository: repo),
      onSessionExpired: onExpired,
      now: now ?? () => DateTime(2026, 11, 18),
    );

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

SessionContextEntity statementSession({
  Set<String> permissions = const {'estado-de-cuenta.index'},
  int companyId = 7,
}) =>
    SessionContextEntity(
      user: const UserEntity(id: 9, name: 'Ana', usuario: 'ana'),
      company: CompanyEntity(id: companyId, razonSocial: 'ACME', igv: 0.18, renta: 0.015),
      modules: const [ModuleEntity(id: 1, name: 'Estado de Cuenta')],
      permissions: permissions,
      roles: const [],
      warehouses: const [],
    );

AuthProvider statementAuth({Set<String> permissions = const {'estado-de-cuenta.index'}}) {
  final repo = _FakeAuthRepository();
  return AuthProvider(
    loginUseCase: LoginUseCase(repository: repo),
    logoutUseCase: LogoutUseCase(repository: repo),
    getSessionContextUseCase: GetSessionContextUseCase(repository: repo),
    getSavedCredentialsUseCase: GetSavedCredentialsUseCase(repository: repo),
    saveCredentialsUseCase: SaveCredentialsUseCase(repository: repo),
    clearSavedCredentialsUseCase: ClearSavedCredentialsUseCase(repository: repo),
  )..session = statementSession(permissions: permissions);
}
