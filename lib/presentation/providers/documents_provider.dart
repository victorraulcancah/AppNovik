import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../../core/errors/failures.dart';
import '../../core/utils/either.dart';
import '../../domain/entities/document_entity.dart';
import '../../domain/entities/session_context_entity.dart';
import '../../domain/usecases/document_usecases.dart';

/// Estado de la pantalla Documentos: ventas o cotizaciones, con búsqueda por
/// número, filtros avanzados (cada lista con los suyos, como la web), totales,
/// paginación y las acciones sobre un documento.
class DocumentsProvider extends ChangeNotifier {
  static const pageSize = 20;

  final GetDocumentsUseCase _getDocuments;
  final ExportDocumentsUseCase _export;
  final GetDocumentFilterCatalogsUseCase _getCatalogs;
  final DeleteDocumentUseCase _delete;
  final CreateCreditNoteUseCase _createCreditNote;
  final DownloadCdrUseCase _downloadCdr;
  final GetCompanyLogoUseCase _getLogo;

  /// Se llama cuando el backend responde 401 (token vencido).
  final VoidCallback? _onSessionExpired;

  /// Hora actual; se puede reemplazar en pruebas.
  final DateTime Function() _now;

  DocumentsProvider({
    required GetDocumentsUseCase getDocumentsUseCase,
    required ExportDocumentsUseCase exportDocumentsUseCase,
    required GetDocumentFilterCatalogsUseCase getFilterCatalogsUseCase,
    required DeleteDocumentUseCase deleteDocumentUseCase,
    required CreateCreditNoteUseCase createCreditNoteUseCase,
    required DownloadCdrUseCase downloadCdrUseCase,
    required GetCompanyLogoUseCase getCompanyLogoUseCase,
    VoidCallback? onSessionExpired,
    DateTime Function()? now,
  })  : _getDocuments = getDocumentsUseCase,
        _export = exportDocumentsUseCase,
        _getCatalogs = getFilterCatalogsUseCase,
        _delete = deleteDocumentUseCase,
        _createCreditNote = createCreditNoteUseCase,
        _downloadCdr = downloadCdrUseCase,
        _getLogo = getCompanyLogoUseCase,
        _onSessionExpired = onSessionExpired,
        _now = now ?? DateTime.now;

  int? _companyId;
  int? _userId;

  /// Un vendedor sin permiso para ver a los demás solo trabaja con lo suyo.
  bool _soloMiCartera = false;
  int _page = 0;
  int _request = 0;
  bool _loadedOnce = false;
  Future<Uint8List?>? _logo;

  DocumentKind kind = DocumentKind.venta;
  String search = '';

  late DocumentFilters _salesFilters = DocumentFilters.hoy(_now());
  late DocumentFilters _quoteFilters = DocumentFilters.hoy(_now());

  DocumentFilterCatalogs catalogs = const DocumentFilterCatalogs();
  bool catalogsLoaded = false;
  bool catalogsLoading = false;

  List<DocumentEntity> items = [];
  bool loading = false;
  bool loadingMore = false;
  bool hasMore = false;
  int total = 0;
  double totalSoles = 0;
  double totalDolares = 0;
  String? error;

  bool exporting = false;

  /// Los filtros de la lista que se está viendo.
  DocumentFilters get filters => kind == DocumentKind.cotizacion ? _quoteFilters : _salesFilters;

  bool get filtersActive => filters.isActive(_now());

  DateTime get now => _now();

  /// Se llama cuando cambia la sesión. Al cambiar de empresa se descarta todo.
  /// No notifica: corre mientras se construye el árbol de widgets.
  void syncSession(SessionContextEntity? session) {
    _userId = session?.user.id;
    _soloMiCartera = session != null &&
        session.hasRole('Vendedor') &&
        !session.can('reportes.ventas.ver-otros-vendedores');

    final companyId = session?.company.id;
    if (companyId == _companyId) return;
    _companyId = companyId;
    kind = DocumentKind.venta;
    search = '';
    _salesFilters = DocumentFilters.hoy(_now());
    _quoteFilters = DocumentFilters.hoy(_now());
    catalogs = const DocumentFilterCatalogs();
    catalogsLoaded = false;
    catalogsLoading = false;
    items = [];
    loading = false;
    loadingMore = false;
    hasMore = false;
    total = 0;
    totalSoles = 0;
    totalDolares = 0;
    error = null;
    exporting = false;
    _page = 0;
    _loadedOnce = false;
    _logo = null;
    _request++;
  }

  Future<void> ensureLoaded() async {
    if (_companyId != null && !_loadedOnce && !loading) await refresh();
  }

  Future<void> refresh() => _fetch(page: 1);

  Future<void> loadMore() async {
    if (loading || loadingMore || !hasMore) return;
    await _fetch(page: _page + 1);
  }

  /// Cambia entre ventas y cotizaciones; cada una conserva sus propios filtros.
  Future<void> selectKind(DocumentKind value) {
    if (value == kind) return Future.value();
    kind = value;
    return refresh();
  }

  Future<void> setSearch(String text) {
    search = text.trim();
    return refresh();
  }

  Future<void> applyFilters(DocumentFilters value) {
    if (kind == DocumentKind.cotizacion) {
      _quoteFilters = value;
    } else {
      _salesFilters = value;
    }
    return refresh();
  }

  /// Vuelve a como se entra: los documentos de hoy, sin otros filtros.
  Future<void> resetFilters() => applyFilters(DocumentFilters.hoy(_now()));

  /// Sucursales, ejecutivos y clientes del panel de filtros; se piden una vez, al abrirlo.
  Future<void> ensureCatalogs() async {
    final companyId = _companyId;
    if (companyId == null || catalogsLoaded || catalogsLoading) return;
    catalogsLoading = true;
    notifyListeners();

    final result = await _getCatalogs(companyId);
    if (companyId != _companyId) return;
    result.fold(
      (failure) {
        if (failure is AuthenticationFailure) _onSessionExpired?.call();
      },
      (data) {
        catalogs = DocumentFilterCatalogs(
          sucursales: data.sucursales,
          // El vendedor sin permiso para ver a los demás solo se ve a sí mismo.
          vendedores: _soloMiCartera
              ? [for (final v in data.vendedores) if (v.id == _userId) v]
              : data.vendedores,
          clientes: data.clientes,
        );
        catalogsLoaded = true;
      },
    );
    catalogsLoading = false;
    notifyListeners();
  }

  Future<Either<Failure, DownloadedFile>> exportCurrent() async {
    final companyId = _companyId;
    if (companyId == null || exporting) {
      return Either.left(const ValidationFailure('Ya se está preparando el archivo'));
    }
    exporting = true;
    notifyListeners();

    final result = await _export(
      companyId: companyId,
      kind: kind,
      search: search.isEmpty ? null : search,
      filters: filters,
    );
    exporting = false;
    _checkSession(result);
    notifyListeners();
    return result;
  }

  /// Elimina la venta o cotización y vuelve a cargar la lista (también cambian los totales).
  Future<Either<Failure, void>> deleteDocument(DocumentEntity document) async {
    final result = await _delete(document);
    _checkSession(result);
    if (result.isRight) await refresh();
    return result;
  }

  Future<Either<Failure, void>> createCreditNote({
    required DocumentEntity document,
    required String descripcion,
    required DateTime fechaEmision,
  }) async {
    final result = await _createCreditNote(
      document: document,
      descripcion: descripcion,
      fechaEmision: fechaEmision,
    );
    _checkSession(result);
    if (result.isRight) await refresh();
    return result;
  }

  Future<Either<Failure, DownloadedFile>> downloadCdr(DocumentEntity document) async {
    final result = await _downloadCdr(document);
    _checkSession(result);
    return result;
  }

  /// Logo de la empresa para el comprobante; `null` si no tiene. Se pide una sola vez.
  Future<Uint8List?> companyLogo() {
    return _logo ??= _getLogo().then((r) => r.isRight ? r.right : null);
  }

  void _checkSession(Either<Failure, Object?> result) {
    if (result.isLeft && result.left is AuthenticationFailure) _onSessionExpired?.call();
  }

  Future<void> _fetch({required int page}) async {
    final companyId = _companyId;
    if (companyId == null) return;

    final request = ++_request;
    final first = page == 1;
    if (first) {
      loading = true;
      error = null;
    } else {
      loadingMore = true;
    }
    notifyListeners();

    final result = await _getDocuments(
      companyId: companyId,
      kind: kind,
      search: search.isEmpty ? null : search,
      filters: filters,
      page: page,
      pageSize: pageSize,
    );

    // Llegó tarde: ya se pidió otra cosa (otra lista, otra búsqueda).
    if (request != _request) return;

    result.fold(
      (failure) {
        if (first) {
          items = [];
          hasMore = false;
          error = failure.message;
        }
        if (failure is AuthenticationFailure) _onSessionExpired?.call();
      },
      (data) {
        items = first ? data.items : [...items, ...data.items];
        _page = data.currentPage;
        hasMore = data.hasMore;
        total = data.total;
        totalSoles = data.totalSoles;
        totalDolares = data.totalDolares;
        error = null;
      },
    );
    _loadedOnce = true;
    loading = false;
    loadingMore = false;
    notifyListeners();
  }
}
