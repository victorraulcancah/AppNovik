import '../../core/errors/failures.dart';
import '../../core/utils/either.dart';
import '../entities/report_entity.dart';

abstract class ReportRepository {
  /// Resumen ejecutivo del usuario para el rango [desde]–[hasta] (días inclusive).
  /// El backend corta [hasta] en hoy.
  Future<Either<Failure, ExecutiveSummaryEntity>> getExecutiveSummary({
    required DateTime desde,
    required DateTime hasta,
  });
}
