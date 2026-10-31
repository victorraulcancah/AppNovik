import '../../core/errors/failures.dart';
import '../../core/utils/either.dart';
import '../entities/other_document_entity.dart';
import '../repositories/other_document_repository.dart';

class GetOtherDocumentsUseCase {
  final OtherDocumentRepository repository;
  GetOtherDocumentsUseCase({required this.repository});

  Future<Either<Failure, OtherDocumentPageEntity>> call({
    required int companyId,
    required OtherDocumentKind kind,
    required OtherDocumentFilters filters,
    int? number,
    int page = 1,
    int pageSize = 20,
  }) =>
      repository.getPage(
        companyId: companyId,
        kind: kind,
        filters: filters,
        number: number,
        page: page,
        pageSize: pageSize,
      );
}

/// Elimina un traslado de stock mientras no se haya recibido ningún producto.
class DeleteTransferUseCase {
  final OtherDocumentRepository repository;
  DeleteTransferUseCase({required this.repository});

  Future<Either<Failure, void>> call(OtherDocumentEntity transfer) async {
    if (transfer.kind != OtherDocumentKind.traslado) {
      return Either.left(const ValidationFailure('Solo se pueden eliminar traslados'));
    }
    if (!transfer.sePuedeEliminar) {
      return Either.left(const ValidationFailure(
        'No puede eliminarlo cuando ya se aceptó productos de la transferencia',
      ));
    }
    return repository.deleteTransfer(transfer.id);
  }
}
