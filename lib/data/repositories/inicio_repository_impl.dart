import '../../core/errors/failures.dart';
import '../../core/utils/either.dart';
import '../../domain/entities/inicio_entity.dart';
import '../../domain/repositories/inicio_repository.dart';
import '../datasources/auth_local_datasource.dart';
import '../datasources/inicio_remote_datasource.dart';
import 'token_guard.dart';

class InicioRepositoryImpl with TokenGuard implements InicioRepository {
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
}
