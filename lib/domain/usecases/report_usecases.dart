import '../../core/errors/failures.dart';
import '../../core/utils/either.dart';
import '../entities/report_entity.dart';
import '../repositories/report_repository.dart';

class GetExecutiveSummaryUseCase {
  final ReportRepository repository;
  GetExecutiveSummaryUseCase({required this.repository});

  Future<Either<Failure, ExecutiveSummaryEntity>> call({
    required DateTime desde,
    required DateTime hasta,
  }) {
    if (desde.isAfter(hasta)) {
      return Future.value(
        Either.left(const ValidationFailure('La fecha inicial no puede ser posterior a la final')),
      );
    }
    return repository.getExecutiveSummary(desde: desde, hasta: hasta);
  }
}
