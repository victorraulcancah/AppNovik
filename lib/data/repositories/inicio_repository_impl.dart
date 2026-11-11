import '../../core/errors/failures.dart';
import '../../core/utils/either.dart';
import '../../domain/entities/inicio_entity.dart';
import '../../domain/repositories/inicio_cache_repository.dart';
import '../../domain/repositories/inicio_repository.dart';
import '../datasources/auth_local_datasource.dart';
import '../datasources/inicio_remote_datasource.dart';
import 'token_guard.dart';

class InicioRepositoryImpl with TokenGuard implements InicioRepository, InicioCacheRepository {
  final InicioRemoteDataSource remoteDataSource;

  @override
  final AuthLocalDataSource authLocalDataSource;

  InicioRepositoryImpl({required this.remoteDataSource, required this.authLocalDataSource});

  @override
  Future<Either<Failure, List<WarehouseSalesEntity>>> getWarehouseSales() =>
      withToken(remoteDataSource.getWarehouseSales);

  @override
  Future<Either<Failure, ExecutiveSummaryEntity>> getExecutiveSummary(DateTime desde, DateTime hasta) =>
      withToken((token) => remoteDataSource.getExecutiveSummary(token, desde, hasta));

  @override
  Future<Either<Failure, TeamSummaryEntity>> getTeamSummary(DateTime desde, DateTime hasta) =>
      withToken((token) => remoteDataSource.getTeamSummary(token, desde, hasta));

  @override
  Future<Either<Failure, CeoSummaryEntity>> getCeoSummary(DateTime desde, DateTime hasta, {int? sucursal}) =>
      withToken((token) => remoteDataSource.getCeoSummary(token, desde, hasta, sucursal: sucursal));

  /// Lee lo guardado con el token de la sesión (en memoria, no cuesta una lectura del disco).
  Future<T?> _cached<T>(Future<T?> Function(String token) read) async {
    try {
      final token = await authLocalDataSource.getToken();
      return token == null ? null : await read(token);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<List<WarehouseSalesEntity>?> cachedWarehouseSales() => _cached(remoteDataSource.cachedWarehouseSales);

  @override
  Future<ExecutiveSummaryEntity?> cachedExecutiveSummary() => _cached(remoteDataSource.cachedExecutiveSummary);

  @override
  Future<TeamSummaryEntity?> cachedTeamSummary() => _cached(remoteDataSource.cachedTeamSummary);

  @override
  Future<CeoSummaryEntity?> cachedCeoSummary() => _cached(remoteDataSource.cachedCeoSummary);

  @override
  Future<void> clearCache() => remoteDataSource.clearCache();
}
