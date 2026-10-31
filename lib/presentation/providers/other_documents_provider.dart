import 'package:flutter/material.dart';
import '../../core/errors/failures.dart';
import '../../core/utils/either.dart';
import '../../domain/entities/other_document_entity.dart';
import '../../domain/usecases/other_document_usecases.dart';

/// Lo que se ve de una lista: sus documentos, su búsqueda, sus filtros y la paginación.
class OtherDocumentsState {
  final OtherDocumentFilters filters;
  String search = '';
  List<OtherDocumentEntity> items = [];
  bool loading = false;
  bool loadingMore = false;
  bool hasMore = false;
  bool loadedOnce = false;
  int total = 0;
  int page = 0;
  String? error;

  OtherDocumentsState(this.filters);

  /// Número buscado: lo que va después del último guion, sin ceros a la izquierda
  /// (`T001-0007` busca el 7). `null` si no hay búsqueda o no tiene dígitos.
  int? get number {
    final text = search.trim();
    if (text.isEmpty) return null;
    final tail = text.contains('-') ? text.substring(text.lastIndexOf('-') + 1) : text;
    final digits = tail.replaceAll(RegExp(r'\D'), '');
    return digits.isEmpty ? null : int.tryParse(digits);
  }
}

/// Estado de las listas de traslados, guías de remisión, notas de crédito y entradas de stock
/// de Documentos. Cada una conserva su búsqueda y sus filtros; por defecto muestra lo de hoy.
class OtherDocumentsProvider extends ChangeNotifier {
  static const pageSize = 20;

  final GetOtherDocumentsUseCase _getDocuments;
  final DeleteTransferUseCase _deleteTransfer;

  /// Se llama cuando el backend responde 401 (token vencido).
  final VoidCallback? _onSessionExpired;

  /// Hora actual; se puede reemplazar en pruebas.
  final DateTime Function() now;

  OtherDocumentsProvider({
    required GetOtherDocumentsUseCase getDocumentsUseCase,
    required DeleteTransferUseCase deleteTransferUseCase,
    VoidCallback? onSessionExpired,
    DateTime Function()? now,
  })  : _getDocuments = getDocumentsUseCase,
        _deleteTransfer = deleteTransferUseCase,
        _onSessionExpired = onSessionExpired,
        now = now ?? DateTime.now;

  int? _companyId;
  int _request = 0;
  late Map<OtherDocumentKind, OtherDocumentsState> _states = _fresh();

  Map<OtherDocumentKind, OtherDocumentsState> _fresh() => {
        for (final k in OtherDocumentKind.values)
          k: OtherDocumentsState(OtherDocumentFilters.hoy(now())),
      };

  OtherDocumentsState stateOf(OtherDocumentKind kind) => _states[kind]!;

  /// Los filtros distintos de "hoy" cuentan como aplicados.
  bool filtersActive(OtherDocumentKind kind) {
    final f = stateOf(kind).filters;
    final today = OtherDocumentFilters.hoy(now());
    return f.desde != today.desde || f.hasta != today.hasta;
  }

  /// Se llama cuando cambia la sesión. Al cambiar de empresa se descarta todo. No notifica:
  /// corre mientras se construye el árbol de widgets.
  void syncCompany(int? companyId) {
    if (companyId == _companyId) return;
    _companyId = companyId;
    _request++;
    _states = _fresh();
  }

  /// Carga la lista la primera vez que se abre.
  Future<void> ensureLoaded(OtherDocumentKind kind) async {
    final s = stateOf(kind);
    if (_companyId != null && !s.loadedOnce && !s.loading) await refresh(kind);
  }

  Future<void> refresh(OtherDocumentKind kind) => _fetch(kind, page: 1);

  Future<void> loadMore(OtherDocumentKind kind) async {
    final s = stateOf(kind);
    if (s.loading || s.loadingMore || !s.hasMore) return;
    await _fetch(kind, page: s.page + 1);
  }

  Future<void> setSearch(OtherDocumentKind kind, String text) {
    stateOf(kind).search = text;
    return refresh(kind);
  }

  Future<void> applyFilters(OtherDocumentKind kind, OtherDocumentFilters filters) {
    _states[kind] = _copyWithFilters(stateOf(kind), filters);
    return refresh(kind);
  }

  OtherDocumentsState _copyWithFilters(OtherDocumentsState old, OtherDocumentFilters filters) =>
      OtherDocumentsState(filters)..search = old.search;

  Future<void> _fetch(OtherDocumentKind kind, {required int page}) async {
    final companyId = _companyId;
    if (companyId == null) return;
    final s = stateOf(kind);

    final request = ++_request;
    final first = page == 1;
    if (first) {
      s.loading = true;
      s.error = null;
    } else {
      s.loadingMore = true;
    }
    notifyListeners();

    final result = await _getDocuments(
      companyId: companyId,
      kind: kind,
      filters: s.filters,
      number: s.number,
      page: page,
      pageSize: pageSize,
    );

    // Una respuesta vieja (otra empresa, otra búsqueda) no pisa la actual.
    if (request != _request || !identical(s, stateOf(kind))) return;

    s.loading = false;
    s.loadingMore = false;
    s.loadedOnce = true;
    result.fold(
      (failure) {
        if (failure is AuthenticationFailure) _onSessionExpired?.call();
        if (first) s.items = [];
        s.error = failure.message;
        s.hasMore = false;
      },
      (data) {
        s.items = first ? data.items : [...s.items, ...data.items];
        s.page = data.currentPage;
        s.hasMore = data.hasMore;
        s.total = data.total;
        s.error = null;
      },
    );
    notifyListeners();
  }

  /// Elimina un traslado y lo saca de la lista (la web no muestra los eliminados).
  Future<Either<Failure, void>> deleteTransfer(OtherDocumentEntity transfer) async {
    final result = await _deleteTransfer(transfer);
    if (result.isLeft) {
      if (result.left is AuthenticationFailure) _onSessionExpired?.call();
      return result;
    }
    final s = stateOf(OtherDocumentKind.traslado);
    s.items = [for (final i in s.items) if (i.id != transfer.id) i];
    s.total = s.total > 0 ? s.total - 1 : 0;
    notifyListeners();
    return result;
  }
}
