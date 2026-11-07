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

/// Marca un producto de un traslado como **recibido** en el almacén de destino. Suma el stock al
/// destino, así que no se repite: un producto ya recibido o un traslado eliminado se rechazan
/// antes de llamar al backend (que no lo comprueba).
class ReceiveTransferProductUseCase {
  final OtherDocumentRepository repository;
  ReceiveTransferProductUseCase({required this.repository});

  Future<Either<Failure, OtherDocumentEntity>> call(
    OtherDocumentEntity transfer,
    OtherDocumentLine line,
  ) async {
    final productId = line.productId;
    if (transfer.kind != OtherDocumentKind.traslado || productId == null) {
      return Either.left(const ValidationFailure('Solo se pueden recibir productos de un traslado'));
    }
    if (!transfer.activo) {
      return Either.left(const ValidationFailure('El traslado fue eliminado'));
    }
    if (line.aceptado) {
      return Either.left(const ValidationFailure('Este producto ya fue recibido'));
    }
    return repository.receiveTransferProduct(transfer.id, productId);
  }
}

/// Marca un producto de un traslado como **validado**, siempre que el código de barras escrito
/// sea el del producto (la web lo compara en el cliente antes de llamar al backend).
class ConfirmTransferProductUseCase {
  final OtherDocumentRepository repository;
  ConfirmTransferProductUseCase({required this.repository});

  Future<Either<Failure, OtherDocumentEntity>> call(
    OtherDocumentEntity transfer,
    OtherDocumentLine line,
    String barcode,
  ) async {
    final productId = line.productId;
    if (transfer.kind != OtherDocumentKind.traslado || productId == null) {
      return Either.left(const ValidationFailure('Solo se pueden validar productos de un traslado'));
    }
    final expected = line.codBarra;
    if (expected == null) {
      return Either.left(const ValidationFailure('Este producto no tiene código de barras'));
    }
    if (barcode.trim() != expected) {
      return Either.left(const ValidationFailure('El código de barras no coincide'));
    }
    return repository.confirmTransferProduct(transfer.id, productId);
  }
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
