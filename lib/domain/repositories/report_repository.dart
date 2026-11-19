import '../../core/errors/failures.dart';
import '../../core/utils/either.dart';
import '../entities/document_entity.dart';
import '../entities/report_entity.dart';
import '../entities/report_ranking_entity.dart';

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

  /// Un ranking (departamentos, vendedores, marcas, categorías o clientes) del rango y los filtros,
  /// de mayor a menor venta. [search] solo lo usa Clientes (búsqueda en el servidor).
  Future<Either<Failure, RankingReport>> getRanking({
    required ReportKind kind,
    required SalesReportFilters filters,
    required int companyId,
    int page = 1,
    int pageSize = 100,
    String? search,
  });

  /// Excel del reporte con los mismos filtros.
  Future<Either<Failure, DownloadedFile>> exportSalesReport(SalesReportFilters filters);

  /// Los productos cuyo código contiene [text], para elegir uno en el filtro "Código de producto".
  Future<Either<Failure, List<ReportProductOption>>> searchProductCodes({
    required int companyId,
    required String text,
  });

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
