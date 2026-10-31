import '../../core/errors/failures.dart';
import '../../core/utils/either.dart';
import '../../domain/entities/other_document_entity.dart';
import '../../domain/repositories/other_document_repository.dart';
import '../datasources/auth_local_datasource.dart';
import '../datasources/other_document_remote_datasource.dart';
import 'token_guard.dart';

class OtherDocumentRepositoryImpl with TokenGuard implements OtherDocumentRepository {
  final OtherDocumentRemoteDataSource remoteDataSource;

  @override
  final AuthLocalDataSource authLocalDataSource;

  OtherDocumentRepositoryImpl({
    required this.remoteDataSource,
    required this.authLocalDataSource,
  });

  @override
  Future<Either<Failure, OtherDocumentPageEntity>> getPage({
    required int companyId,
    required OtherDocumentKind kind,
    required OtherDocumentFilters filters,
    int? number,
    int page = 1,
    int pageSize = 20,
  }) =>
      withToken(
        (token) => remoteDataSource.getPage(
          token: token,
          companyId: companyId,
          kind: kind,
          filters: filters,
          number: number,
          page: page,
          pageSize: pageSize,
        ),
      );

  @override
  Future<Either<Failure, void>> deleteTransfer(int id) =>
      withToken((token) => remoteDataSource.deleteTransfer(token, id));
}
