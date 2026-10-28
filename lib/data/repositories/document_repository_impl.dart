import '../../core/errors/failures.dart';
import '../../core/utils/either.dart';
import '../../domain/entities/document_entity.dart';
import '../../domain/repositories/document_repository.dart';
import '../datasources/auth_local_datasource.dart';
import '../datasources/document_remote_datasource.dart';
import 'token_guard.dart';

class DocumentRepositoryImpl with TokenGuard implements DocumentRepository {
  final DocumentRemoteDataSource remoteDataSource;

  @override
  final AuthLocalDataSource authLocalDataSource;

  DocumentRepositoryImpl({
    required this.remoteDataSource,
    required this.authLocalDataSource,
  });

  @override
  Future<Either<Failure, DocumentPageEntity>> getDocuments({
    required int companyId,
    required DocumentKind kind,
    String? search,
    DateTime? from,
    DateTime? to,
    DocumentTipo? tipo,
    DocumentEstado? estado,
    bool soloPendientes = false,
    int page = 1,
    int pageSize = 20,
  }) =>
      withToken(
        (token) => remoteDataSource.getDocuments(
          token: token,
          companyId: companyId,
          kind: kind,
          search: search,
          from: from,
          to: to,
          tipo: tipo,
          estado: estado,
          soloPendientes: soloPendientes,
          page: page,
          pageSize: pageSize,
        ),
      );
}
