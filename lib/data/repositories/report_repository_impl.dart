import '../../core/errors/failures.dart';
import '../../core/utils/either.dart';
import '../../domain/entities/document_entity.dart';
import '../../domain/entities/report_entity.dart';
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
  Future<Either<Failure, DownloadedFile>> exportSalesReport(SalesReportFilters filters) =>
      withToken(
        (token) async => DownloadedFile(
          name: 'Reporte de Ventas.xlsx',
          bytes: await remoteDataSource.exportSalesReport(token, filters),
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
