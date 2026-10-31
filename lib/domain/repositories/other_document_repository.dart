import '../../core/errors/failures.dart';
import '../../core/utils/either.dart';
import '../entities/other_document_entity.dart';

abstract class OtherDocumentRepository {
  /// Una página de traslados, guías, notas de crédito o entradas de stock. Con [number] (el
  /// número que se busca) se ignora el rango de fechas y se busca en toda la empresa.
  Future<Either<Failure, OtherDocumentPageEntity>> getPage({
    required int companyId,
    required OtherDocumentKind kind,
    required OtherDocumentFilters filters,
    int? number,
    int page = 1,
    int pageSize = 20,
  });

  /// Elimina un traslado (`DELETE /stock-transfer/{id}`).
  Future<Either<Failure, void>> deleteTransfer(int id);
}
