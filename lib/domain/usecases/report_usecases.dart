import '../../core/errors/failures.dart';
import '../../core/utils/either.dart';
import '../entities/document_entity.dart';
import '../entities/report_entity.dart';
import '../repositories/report_repository.dart';

class GetSalesReportUseCase {
  final ReportRepository repository;
  GetSalesReportUseCase({required this.repository});

  Future<Either<Failure, SalesReportEntity>> call({
    required SalesReportFilters filters,
    int page = 1,
    int pageSize = 15,
    String? sortField,
    bool sortDescending = true,
  }) {
    if (filters.desde.isAfter(filters.hasta)) {
      return Future.value(
        Either.left(const ValidationFailure('La fecha inicial no puede ser posterior a la final')),
      );
    }
    return repository.getSalesReport(
      filters: filters,
      page: page,
      pageSize: pageSize,
      sortField: sortField,
      sortDescending: sortDescending,
    );
  }
}

class ExportSalesReportUseCase {
  final ReportRepository repository;
  ExportSalesReportUseCase({required this.repository});

  Future<Either<Failure, DownloadedFile>> call(SalesReportFilters filters) =>
      repository.exportSalesReport(filters);
}

class GetReportCatalogsUseCase {
  final ReportRepository repository;
  GetReportCatalogsUseCase({required this.repository});

  Future<Either<Failure, SalesReportCatalogs>> call({
    required int companyId,
    required int userId,
    required bool soloMiCartera,
  }) =>
      repository.getCatalogs(companyId: companyId, userId: userId, soloMiCartera: soloMiCartera);
}

class GetReportSaleUseCase {
  final ReportRepository repository;
  GetReportSaleUseCase({required this.repository});

  Future<Either<Failure, DocumentEntity>> call(int id) => repository.getSale(id);
}
