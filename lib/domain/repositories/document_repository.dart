import 'dart:typed_data';
import '../../core/errors/failures.dart';
import '../../core/utils/either.dart';
import '../entities/document_entity.dart';

abstract class DocumentRepository {
  /// Ventas o cotizaciones de la empresa.
  ///
  /// - [search]: número de documento exacto; con él se buscan en toda la empresa y se ignoran los filtros.
  /// - [filters]: filtros avanzados (fechas, sucursales, ejecutivos, clientes, tipo, estado...).
  Future<Either<Failure, DocumentPageEntity>> getDocuments({
    required int companyId,
    required DocumentKind kind,
    String? search,
    required DocumentFilters filters,
    int page = 1,
    int pageSize = 20,
  });

  /// Excel de lo que se ve (mismos filtros y búsqueda, sin paginación).
  Future<Either<Failure, DownloadedFile>> exportDocuments({
    required int companyId,
    required DocumentKind kind,
    String? search,
    required DocumentFilters filters,
  });

  /// Sucursales, ejecutivos y clientes que se ofrecen en los filtros.
  Future<Either<Failure, DocumentFilterCatalogs>> getFilterCatalogs(int companyId);

  /// Elimina una venta sin comprobante electrónico (queda como "Eliminado").
  Future<Either<Failure, void>> deleteSale(int id);

  /// Elimina una cotización (queda como "Usado").
  Future<Either<Failure, void>> deleteQuote(int id);

  /// Emite una nota de crédito sobre una boleta o factura.
  Future<Either<Failure, void>> createCreditNote({
    required int boletaId,
    required String descripcion,
    required DateTime fechaEmision,
  });

  /// Constancia de recepción (CDR) de SUNAT de una boleta o factura.
  Future<Either<Failure, DownloadedFile>> downloadCdr({
    required int boletaId,
    required String name,
  });

  /// Logo de la empresa para el comprobante; falla si no tiene.
  Future<Either<Failure, Uint8List>> getCompanyLogo();
}
