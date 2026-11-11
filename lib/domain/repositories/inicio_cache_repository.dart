import '../entities/inicio_entity.dart';

/// Lo último que se vio en cada vista del Inicio con esta sesión, para mostrarlo al instante mientras
/// llega lo nuevo. Cada método devuelve `null` si no hay nada guardado, venció, es de otra sesión o no
/// se pudo leer: nunca falla.
abstract class InicioCacheRepository {
  Future<List<WarehouseSalesEntity>?> cachedWarehouseSales();

  Future<ExecutiveSummaryEntity?> cachedExecutiveSummary();

  Future<TeamSummaryEntity?> cachedTeamSummary();

  Future<CeoSummaryEntity?> cachedCeoSummary();

  /// Borra lo guardado (al cerrar sesión).
  Future<void> clearCache();
}
