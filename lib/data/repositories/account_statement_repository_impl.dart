import 'dart:typed_data';
import '../../core/errors/failures.dart';
import '../../core/utils/either.dart';
import '../../domain/entities/account_statement_entity.dart';
import '../../domain/entities/document_entity.dart' show DownloadedFile;
import '../../domain/entities/sale_entity.dart' show ClientEntity;
import '../../domain/repositories/account_statement_repository.dart';
import '../datasources/account_statement_remote_datasource.dart';
import '../datasources/auth_local_datasource.dart';
import 'token_guard.dart';

class AccountStatementRepositoryImpl with TokenGuard implements AccountStatementRepository {
  final AccountStatementRemoteDataSource remoteDataSource;

  @override
  final AuthLocalDataSource authLocalDataSource;

  AccountStatementRepositoryImpl({required this.remoteDataSource, required this.authLocalDataSource});

  @override
  Future<Either<Failure, List<ClientEntity>>> searchClients(int companyId, String search) =>
      withToken((token) => remoteDataSource.searchClients(token, companyId, search));

  @override
  Future<Either<Failure, StatementPageEntity>> getStatement(StatementQuery query, {required int page, required int pageSize}) =>
      withToken((token) => remoteDataSource.getStatement(token, query, page: page, pageSize: pageSize));

  @override
  Future<Either<Failure, StatementPageEntity>> getOrders(StatementQuery query, {required int page, required int pageSize}) =>
      withToken((token) => remoteDataSource.getOrders(token, query, page: page, pageSize: pageSize));

  @override
  Future<Either<Failure, StatementPageEntity>> getPayments(StatementQuery query, {required int page, required int pageSize}) =>
      withToken((token) => remoteDataSource.getPayments(token, query, page: page, pageSize: pageSize));

  @override
  Future<Either<Failure, DownloadedFile>> exportExcel(StatementTab tab, StatementQuery query) =>
      withToken((token) => remoteDataSource.exportExcel(token, tab, query));

  @override
  Future<Either<Failure, Uint8List>> exportPdf(StatementQuery query) =>
      withToken((token) => remoteDataSource.exportPdf(token, query));
}
