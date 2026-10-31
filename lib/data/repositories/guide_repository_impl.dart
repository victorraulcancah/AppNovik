import '../../core/errors/failures.dart';
import '../../core/utils/either.dart';
import '../../domain/entities/guide_form_entity.dart';
import '../../domain/entities/other_document_entity.dart';
import '../../domain/repositories/guide_repository.dart';
import '../datasources/auth_local_datasource.dart';
import '../datasources/guide_remote_datasource.dart';
import 'token_guard.dart';

class GuideRepositoryImpl with TokenGuard implements GuideRepository {
  final GuideRemoteDataSource remoteDataSource;

  @override
  final AuthLocalDataSource authLocalDataSource;

  GuideRepositoryImpl({
    required this.remoteDataSource,
    required this.authLocalDataSource,
  });

  @override
  Future<Either<Failure, GuideDefaultsEntity>> getDefaults(int saleId) =>
      withToken((token) => remoteDataSource.getDefaults(token, saleId));

  @override
  Future<Either<Failure, DriverEntity?>> findDriver(String dni) =>
      withToken((token) => remoteDataSource.findDriver(token, dni));

  @override
  Future<Either<Failure, OtherDocumentEntity>> createGuide(GuideFormEntity form) =>
      withToken((token) => remoteDataSource.createGuide(token, form));
}
