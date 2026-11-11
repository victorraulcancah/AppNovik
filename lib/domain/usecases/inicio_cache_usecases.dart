import '../entities/inicio_entity.dart';
import '../repositories/inicio_cache_repository.dart';

/// Lee lo último que se vio de cada vista del Inicio (ver [InicioCacheRepository]).
class GetCachedInicioUseCase {
  final InicioCacheRepository repository;
  GetCachedInicioUseCase({required this.repository});

  Future<List<WarehouseSalesEntity>?> warehouses() => repository.cachedWarehouseSales();

  Future<ExecutiveSummaryEntity?> executive() => repository.cachedExecutiveSummary();

  Future<TeamSummaryEntity?> team() => repository.cachedTeamSummary();

  Future<CeoSummaryEntity?> ceo() => repository.cachedCeoSummary();
}

/// Borra lo guardado del Inicio (al cerrar sesión).
class ClearInicioCacheUseCase {
  final InicioCacheRepository repository;
  ClearInicioCacheUseCase({required this.repository});

  Future<void> call() => repository.clearCache();
}
