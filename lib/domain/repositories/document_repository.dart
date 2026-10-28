import '../../core/errors/failures.dart';
import '../../core/utils/either.dart';
import '../entities/document_entity.dart';

abstract class DocumentRepository {
  /// Ventas o cotizaciones de la empresa.
  ///
  /// - [search]: número de documento exacto.
  /// - [from] / [to]: primer y último día (inclusive); `null` sin límite.
  /// - [tipo], [estado]: solo ventas.
  /// - [soloPendientes]: solo cotizaciones sin procesar.
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
  });
}
