import 'package:flutter/material.dart';
import '../../core/errors/failures.dart';
import '../../domain/entities/document_entity.dart';
import '../../domain/usecases/document_usecases.dart';

/// Estado de la pantalla Documentos: ventas o cotizaciones, con búsqueda por
/// número, filtros y paginación.
class DocumentsProvider extends ChangeNotifier {
  static const pageSize = 20;

  final GetDocumentsUseCase _getDocuments;

  /// Se llama cuando el backend responde 401 (token vencido).
  final VoidCallback? _onSessionExpired;

  /// Hora actual; se puede reemplazar en pruebas.
  final DateTime Function() _now;

  DocumentsProvider({
    required GetDocumentsUseCase getDocumentsUseCase,
    VoidCallback? onSessionExpired,
    DateTime Function()? now,
  })  : _getDocuments = getDocumentsUseCase,
        _onSessionExpired = onSessionExpired,
        _now = now ?? DateTime.now;

  int? _companyId;
  int _page = 0;
  int _request = 0;

  DocumentKind kind = DocumentKind.venta;
  String search = '';

  /// Por defecto, igual que la web, solo los documentos de hoy.
  DocumentDateRange range = DocumentDateRange.hoy;
  DocumentTipo? tipo;
  DocumentEstado? estado;
  bool soloPendientes = false;

  List<DocumentEntity> items = [];
  bool loading = false;
  bool loadingMore = false;
  bool hasMore = false;
  int total = 0;
  String? error;

  bool get filtersActive =>
      range != DocumentDateRange.hoy ||
      tipo != null ||
      estado != null ||
      soloPendientes;

  /// Se llama cuando cambia la sesión. Al cambiar de empresa se descarta todo.
  /// No notifica: corre mientras se construye el árbol de widgets.
  void syncCompany(int? companyId) {
    if (companyId == _companyId) return;
    _companyId = companyId;
    kind = DocumentKind.venta;
    search = '';
    range = DocumentDateRange.hoy;
    tipo = null;
    estado = null;
    soloPendientes = false;
    items = [];
    loading = false;
    loadingMore = false;
    hasMore = false;
    total = 0;
    error = null;
    _page = 0;
    _request++;
  }

  Future<void> ensureLoaded() async {
    if (_companyId != null && _page == 0 && !loading && error == null) {
      await refresh();
    }
  }

  Future<void> refresh() => _fetch(page: 1);

  Future<void> loadMore() async {
    if (loading || loadingMore || !hasMore) return;
    await _fetch(page: _page + 1);
  }

  /// Cambia entre ventas y cotizaciones; los filtros propios de cada una se limpian.
  Future<void> selectKind(DocumentKind value) {
    if (value == kind) return Future.value();
    kind = value;
    tipo = null;
    estado = null;
    soloPendientes = false;
    return refresh();
  }

  Future<void> setSearch(String text) {
    search = text.trim();
    return refresh();
  }

  Future<void> applyFilters({
    required DocumentDateRange range,
    DocumentTipo? tipo,
    DocumentEstado? estado,
    bool soloPendientes = false,
  }) {
    this.range = range;
    this.tipo = tipo;
    this.estado = estado;
    this.soloPendientes = soloPendientes;
    return refresh();
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

    // Con un número buscado se ignoran las fechas: el backend busca en toda la empresa.
    final bounds = search.isEmpty ? range.bounds(_now()) : null;

    final result = await _getDocuments(
      companyId: companyId,
      kind: kind,
      search: search.isEmpty ? null : search,
      from: bounds?.$1,
      to: bounds?.$2,
      tipo: tipo,
      estado: estado,
      soloPendientes: soloPendientes,
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
        error = null;
      },
    );
    loading = false;
    loadingMore = false;
    notifyListeners();
  }
}
