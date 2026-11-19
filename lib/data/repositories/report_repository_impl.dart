import '../../core/errors/failures.dart';
import '../../core/utils/either.dart';
import '../../domain/entities/document_entity.dart';
import '../../domain/entities/report_entity.dart';
import '../../domain/entities/report_ranking_entity.dart';
import '../../domain/repositories/report_repository.dart';
import '../datasources/auth_local_datasource.dart';
import '../datasources/report_remote_datasource.dart';
import 'token_guard.dart';

class ReportRepositoryImpl with TokenGuard implements ReportRepository {
  final ReportRemoteDataSource remoteDataSource;

  @override
  final AuthLocalDataSource authLocalDataSource;

  ReportRepositoryImpl({
    required this.remoteDataSource,
    required this.authLocalDataSource,
  });

  @override
  Future<Either<Failure, SalesReportEntity>> getSalesReport({
    required SalesReportFilters filters,
    int page = 1,
    int pageSize = 15,
    String? sortField,
    bool sortDescending = true,
  }) =>
      withToken(
        (token) => remoteDataSource.getSalesReport(
          token: token,
          filters: filters,
          page: page,
          pageSize: pageSize,
          sortField: sortField,
          sortDescending: sortDescending,
        ),
      );

  @override
  Future<Either<Failure, RankingReport>> getRanking({
    required ReportKind kind,
    required SalesReportFilters filters,
    required int companyId,
    int page = 1,
    int pageSize = 100,
    String? search,
  }) =>
      withToken(
        (token) => remoteDataSource.getRanking(
          token: token,
          kind: kind,
          filters: filters,
          companyId: companyId,
          page: page,
          pageSize: pageSize,
          search: search,
        ),
      );

  @override
  Future<Either<Failure, RankingProductsPage>> getRankingProducts({
    required ReportKind kind,
    required SalesReportFilters filters,
    required int companyId,
    required int entityId,
    int page = 1,
    int pageSize = 50,
  }) =>
      withToken(
        (token) => remoteDataSource.getRankingProducts(
          token: token,
          kind: kind,
          filters: filters,
          companyId: companyId,
          entityId: entityId,
          page: page,
          pageSize: pageSize,
        ),
      );

  @override
  Future<Either<Failure, List<SalesReportDocumentEntity>>> getRankingProductDocuments({
    required ReportKind kind,
    required SalesReportFilters filters,
    required int companyId,
    required int entityId,
    required int productId,
  }) =>
      withToken(
        (token) => remoteDataSource.getRankingProductDocuments(
          token: token,
          kind: kind,
          filters: filters,
          companyId: companyId,
          entityId: entityId,
          productId: productId,
        ),
      );

  @override
  Future<Either<Failure, List<ReportProductOption>>> searchProductCodes({
    required int companyId,
    required String text,
  }) =>
      withToken(
        (token) => remoteDataSource.searchProductCodes(token: token, companyId: companyId, text: text),
      );

  @override
  Future<Either<Failure, DownloadedFile>> exportSalesReport(
    SalesReportFilters filters, {
    ReportKind kind = ReportKind.general,
    int? companyId,
  }) =>
      withToken(
        (token) async => DownloadedFile(
          name: kind.exportName,
          bytes: await remoteDataSource.exportSalesReport(token, filters, kind: kind, companyId: companyId),
        ),
      );

  @override
  Future<Either<Failure, SalesReportCatalogs>> getCatalogs({
    required int companyId,
    required int userId,
    required bool soloMiCartera,
  }) =>
      withToken(
        (token) => remoteDataSource.getCatalogs(
          token: token,
          companyId: companyId,
          userId: userId,
          soloMiCartera: soloMiCartera,
        ),
      );

  @override
  Future<Either<Failure, DocumentEntity>> getSale(int id) =>
      withToken((token) => remoteDataSource.getSale(token, id));
}
