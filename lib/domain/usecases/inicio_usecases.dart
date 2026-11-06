import '../../core/errors/failures.dart';
import '../../core/utils/either.dart';
import '../entities/inicio_entity.dart';
import '../repositories/inicio_repository.dart';

Either<Failure, T>? _checkRange<T>(DateTime desde, DateTime hasta) => desde.isAfter(hasta)
    ? Either.left(const ValidationFailure('La fecha inicial no puede ser posterior a la final'))
    : null;

class GetWarehouseSalesUseCase {
  final InicioRepository repository;
  GetWarehouseSalesUseCase({required this.repository});

  Future<Either<Failure, List<WarehouseSalesEntity>>> call() => repository.getWarehouseSales();
}

class GetExecutiveSummaryUseCase {
  final InicioRepository repository;
  GetExecutiveSummaryUseCase({required this.repository});

  Future<Either<Failure, ExecutiveSummaryEntity>> call(DateTime desde, DateTime hasta) {
    final invalid = _checkRange<ExecutiveSummaryEntity>(desde, hasta);
    return invalid != null ? Future.value(invalid) : repository.getExecutiveSummary(desde, hasta);
  }
}

class GetTeamSummaryUseCase {
  final InicioRepository repository;
  GetTeamSummaryUseCase({required this.repository});

  Future<Either<Failure, TeamSummaryEntity>> call(DateTime desde, DateTime hasta) {
    final invalid = _checkRange<TeamSummaryEntity>(desde, hasta);
    return invalid != null ? Future.value(invalid) : repository.getTeamSummary(desde, hasta);
  }
}

class GetCeoSummaryUseCase {
  final InicioRepository repository;
  GetCeoSummaryUseCase({required this.repository});

  Future<Either<Failure, CeoSummaryEntity>> call(DateTime desde, DateTime hasta, {int? sucursal}) {
    final invalid = _checkRange<CeoSummaryEntity>(desde, hasta);
    return invalid != null ? Future.value(invalid) : repository.getCeoSummary(desde, hasta, sucursal: sucursal);
  }
}
