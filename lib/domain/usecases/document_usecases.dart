import '../../core/errors/failures.dart';
import '../../core/utils/either.dart';
import '../entities/document_entity.dart';
import '../repositories/document_repository.dart';

class GetDocumentsUseCase {
  final DocumentRepository repository;
  GetDocumentsUseCase({required this.repository});

  Future<Either<Failure, DocumentPageEntity>> call({
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
      repository.getDocuments(
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
      );
}
