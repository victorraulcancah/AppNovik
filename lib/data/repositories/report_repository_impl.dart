import '../../core/errors/failures.dart';
import '../../core/utils/either.dart';
import '../../domain/entities/report_entity.dart';
import '../../domain/repositories/report_repository.dart';
import '../datasources/auth_local_datasource.dart';
import '../datasources/report_remote_datasource.dart';
import 'token_guard.dart';

class ReportRepositoryImpl with TokenGuard implements ReportRepository {
  final ReportRemoteDataSource remoteDataSource;

  @override
  final AuthLocalDataSource authLocalDataSource;

  ReportRepositoryImpl({
    required this.remoteDataSource,
    required this.authLocalDataSource,
  });

  @override
  Future<Either<Failure, ExecutiveSummaryEntity>> getExecutiveSummary({
    required DateTime desde,
    required DateTime hasta,
  }) =>
      withToken(
        (token) => remoteDataSource.getExecutiveSummary(token: token, desde: desde, hasta: hasta),
      );
}
