import 'dart:typed_data';
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
    required DocumentFilters filters,
    int page = 1,
    int pageSize = 20,
  }) =>
      withToken(
        (token) => remoteDataSource.getDocuments(
          token: token,
          companyId: companyId,
          kind: kind,
          search: search,
          filters: filters,
          page: page,
          pageSize: pageSize,
        ),
      );

  @override
  Future<Either<Failure, DownloadedFile>> exportDocuments({
    required int companyId,
    required DocumentKind kind,
    String? search,
    required DocumentFilters filters,
  }) =>
      withToken(
        (token) => remoteDataSource.exportDocuments(
          token: token,
          companyId: companyId,
          kind: kind,
          search: search,
          filters: filters,
        ),
      );

  @override
  Future<Either<Failure, DocumentFilterCatalogs>> getFilterCatalogs(int companyId) =>
      withToken((token) => remoteDataSource.getFilterCatalogs(token, companyId));

  @override
  Future<Either<Failure, void>> deleteSale(int id) =>
      withToken((token) => remoteDataSource.deleteSale(token, id));

  @override
  Future<Either<Failure, void>> deleteQuote(int id) =>
      withToken((token) => remoteDataSource.deleteQuote(token, id));

  @override
  Future<Either<Failure, void>> createCreditNote({
    required int boletaId,
    required String descripcion,
    required DateTime fechaEmision,
  }) =>
      withToken(
        (token) => remoteDataSource.createCreditNote(
          token: token,
          boletaId: boletaId,
          descripcion: descripcion,
          fechaEmision: fechaEmision,
        ),
      );

  @override
  Future<Either<Failure, DownloadedFile>> downloadCdr({
    required int boletaId,
    required String name,
  }) =>
      withToken((token) async => DownloadedFile(
            name: name,
            bytes: await remoteDataSource.downloadBytes(token, '/boletas/$boletaId/download-cdr'),
          ));

  @override
  Future<Either<Failure, Uint8List>> getCompanyLogo() =>
      withToken((token) => remoteDataSource.downloadBytes(token, '/empresas/logo'));
}
