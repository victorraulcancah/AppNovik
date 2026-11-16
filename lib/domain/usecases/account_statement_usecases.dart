import 'dart:typed_data';
import '../../core/errors/failures.dart';
import '../../core/utils/either.dart';
import '../entities/account_statement_entity.dart';
import '../entities/document_entity.dart' show DownloadedFile;
import '../entities/sale_entity.dart' show ClientEntity;
import '../repositories/account_statement_repository.dart';

class SearchStatementClientsUseCase {
  final AccountStatementRepository repository;
  SearchStatementClientsUseCase({required this.repository});

  Future<Either<Failure, List<ClientEntity>>> call(int companyId, String search) =>
      repository.searchClients(companyId, search.trim());
}

class GetStatementUseCase {
  final AccountStatementRepository repository;
  GetStatementUseCase({required this.repository});

  Future<Either<Failure, StatementPageEntity>> call(StatementQuery query, {required int page, required int pageSize}) =>
      repository.getStatement(query, page: page, pageSize: pageSize);
}

class GetStatementOrdersUseCase {
  final AccountStatementRepository repository;
  GetStatementOrdersUseCase({required this.repository});

  Future<Either<Failure, StatementPageEntity>> call(StatementQuery query, {required int page, required int pageSize}) =>
      repository.getOrders(query, page: page, pageSize: pageSize);
}

class GetStatementPaymentsUseCase {
  final AccountStatementRepository repository;
  GetStatementPaymentsUseCase({required this.repository});

  Future<Either<Failure, StatementPageEntity>> call(StatementQuery query, {required int page, required int pageSize}) =>
      repository.getPayments(query, page: page, pageSize: pageSize);
}

class ExportStatementExcelUseCase {
  final AccountStatementRepository repository;
  ExportStatementExcelUseCase({required this.repository});

  Future<Either<Failure, DownloadedFile>> call(StatementTab tab, StatementQuery query) =>
      repository.exportExcel(tab, query);
}

class ExportStatementPdfUseCase {
  final AccountStatementRepository repository;
  ExportStatementPdfUseCase({required this.repository});

  Future<Either<Failure, Uint8List>> call(StatementQuery query) => repository.exportPdf(query);
}
