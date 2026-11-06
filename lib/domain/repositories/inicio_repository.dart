import '../../core/errors/failures.dart';
import '../../core/utils/either.dart';
import '../entities/inicio_entity.dart';

abstract class InicioRepository {
  /// Pantalla general: lo vendido en el mes en cada almacén (`/ventas/reporte-almacenes`).
  Future<Either<Failure, List<WarehouseSalesEntity>>> getWarehouseSales();

  /// Resumen del Vendedor (`/ventas/resumen-ejecutivo`) para el rango [desde]–[hasta].
  Future<Either<Failure, ExecutiveSummaryEntity>> getExecutiveSummary(DateTime desde, DateTime hasta);

  /// Resumen del Jefe Comercial (`/ventas/resumen-equipo`).
  Future<Either<Failure, TeamSummaryEntity>> getTeamSummary(DateTime desde, DateTime hasta);

  /// Resumen del CEO (`/ventas/resumen-ceo`); [sucursal] limita las cifras a un almacén.
  Future<Either<Failure, CeoSummaryEntity>> getCeoSummary(DateTime desde, DateTime hasta, {int? sucursal});
}
