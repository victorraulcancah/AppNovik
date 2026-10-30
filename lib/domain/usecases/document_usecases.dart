import 'dart:typed_data';
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
    required DocumentFilters filters,
    int page = 1,
    int pageSize = 20,
  }) =>
      repository.getDocuments(
        companyId: companyId,
        kind: kind,
        search: search,
        filters: filters,
        page: page,
        pageSize: pageSize,
      );
}

class ExportDocumentsUseCase {
  final DocumentRepository repository;
  ExportDocumentsUseCase({required this.repository});

  Future<Either<Failure, DownloadedFile>> call({
    required int companyId,
    required DocumentKind kind,
    String? search,
    required DocumentFilters filters,
  }) =>
      repository.exportDocuments(
        companyId: companyId,
        kind: kind,
        search: search,
        filters: filters,
      );
}

class GetDocumentFilterCatalogsUseCase {
  final DocumentRepository repository;
  GetDocumentFilterCatalogsUseCase({required this.repository});

  Future<Either<Failure, DocumentFilterCatalogs>> call(int companyId) =>
      repository.getFilterCatalogs(companyId);
}

/// Elimina una venta o una cotización. Una venta con boleta o factura no se elimina:
/// se anula con una nota de crédito (igual que la web).
class DeleteDocumentUseCase {
  final DocumentRepository repository;
  DeleteDocumentUseCase({required this.repository});

  Future<Either<Failure, void>> call(DocumentEntity document) {
    if (!document.activo) {
      return Future.value(Either.left(const ValidationFailure('El documento ya está eliminado')));
    }
    if (document.esCotizacion) return repository.deleteQuote(document.id);
    if (document.boleta != null) {
      return Future.value(Either.left(const ValidationFailure(
        'Una boleta o factura no se elimina: se anula con una nota de crédito',
      )));
    }
    return repository.deleteSale(document.id);
  }
}

class CreateCreditNoteUseCase {
  final DocumentRepository repository;
  CreateCreditNoteUseCase({required this.repository});

  Future<Either<Failure, void>> call({
    required DocumentEntity document,
    required String descripcion,
    required DateTime fechaEmision,
  }) {
    final boleta = document.boleta;
    if (boleta == null || !document.sePuedeAnularConNotaCredito) {
      return Future.value(Either.left(
        const ValidationFailure('Este documento no admite una nota de crédito'),
      ));
    }
    if (descripcion.trim().isEmpty) {
      return Future.value(Either.left(
        const ValidationFailure('La descripción es obligatoria (razón para anular la boleta o factura)'),
      ));
    }
    return repository.createCreditNote(
      boletaId: boleta.id,
      descripcion: descripcion.trim(),
      fechaEmision: fechaEmision,
    );
  }
}

class DownloadCdrUseCase {
  final DocumentRepository repository;
  DownloadCdrUseCase({required this.repository});

  Future<Either<Failure, DownloadedFile>> call(DocumentEntity document) {
    final boleta = document.boleta;
    if (boleta == null || !boleta.tieneCdr) {
      return Future.value(Either.left(
        const ValidationFailure('Este documento no tiene constancia de recepción (CDR)'),
      ));
    }
    return repository.downloadCdr(boletaId: boleta.id, name: 'CDR-${document.numero}.zip');
  }
}

class GetCompanyLogoUseCase {
  final DocumentRepository repository;
  GetCompanyLogoUseCase({required this.repository});

  Future<Either<Failure, Uint8List>> call() => repository.getCompanyLogo();
}
