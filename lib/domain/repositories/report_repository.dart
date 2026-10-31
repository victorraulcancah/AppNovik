import '../../core/errors/failures.dart';
import '../../core/utils/either.dart';
import '../entities/document_entity.dart';
import '../entities/report_entity.dart';

abstract class ReportRepository {
  /// El reporte Ventas General. [page] y [pageSize] paginan los productos; [sortField]
  /// (`venta`, `cantidad`, `subtotal`, `descuento`) y [sortDescending] los ordenan.
  Future<Either<Failure, SalesReportEntity>> getSalesReport({
    required SalesReportFilters filters,
    int page = 1,
    int pageSize = 15,
    String? sortField,
    bool sortDescending = true,
  });

  /// Excel del reporte con los mismos filtros.
  Future<Either<Failure, DownloadedFile>> exportSalesReport(SalesReportFilters filters);

  /// Lo que se puede elegir en los filtros avanzados. [soloMiCartera]: un vendedor sin permiso
  /// para ver a los demás solo se ofrece a sí mismo y a sus clientes.
  Future<Either<Failure, SalesReportCatalogs>> getCatalogs({
    required int companyId,
    required int userId,
    required bool soloMiCartera,
  });

  /// Una venta completa (para abrir su comprobante desde el reporte).
  Future<Either<Failure, DocumentEntity>> getSale(int id);
}
