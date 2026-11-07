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
  final ReceiveTransferProductUseCase _receiveProduct;
  final ConfirmTransferProductUseCase _confirmProduct;

  /// Se llama cuando el backend responde 401 (token vencido).
  final VoidCallback? _onSessionExpired;

  /// Hora actual; se puede reemplazar en pruebas.
  final DateTime Function() now;

  OtherDocumentsProvider({
    required GetOtherDocumentsUseCase getDocumentsUseCase,
    required DeleteTransferUseCase deleteTransferUseCase,
    required ReceiveTransferProductUseCase receiveTransferProductUseCase,
    required ConfirmTransferProductUseCase confirmTransferProductUseCase,
    VoidCallback? onSessionExpired,
    DateTime Function()? now,
  })  : _getDocuments = getDocumentsUseCase,
        _deleteTransfer = deleteTransferUseCase,
        _receiveProduct = receiveTransferProductUseCase,
        _confirmProduct = confirmTransferProductUseCase,
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

  /// Productos de traslados con una petición en curso (`traslado:producto`), para no repetirla.
  final Set<String> _busy = {};

  String _key(int transferId, int? productId) => '$transferId:$productId';

  /// Si ya hay una petición en curso para este producto del traslado.
  bool isLineBusy(OtherDocumentEntity transfer, OtherDocumentLine line) =>
      _busy.contains(_key(transfer.id, line.productId));

  /// El traslado tal como está ahora en la lista (con lo recibido o validado hasta el momento),
  /// o [fallback] si ya no está (por ejemplo, si cambió el filtro).
  OtherDocumentEntity currentTransfer(OtherDocumentEntity fallback) {
    for (final i in stateOf(OtherDocumentKind.traslado).items) {
      if (i.id == fallback.id) return i;
    }
    return fallback;
  }

  /// Marca un producto del traslado como **recibido** y deja el traslado actualizado en la lista.
  Future<Either<Failure, OtherDocumentEntity>> receiveProduct(
    OtherDocumentEntity transfer,
    OtherDocumentLine line,
  ) =>
      _updateLine(transfer, line, () => _receiveProduct(currentTransfer(transfer), line));

  /// Marca un producto del traslado como **validado** (con su código de barras).
  Future<Either<Failure, OtherDocumentEntity>> confirmProduct(
    OtherDocumentEntity transfer,
    OtherDocumentLine line,
    String barcode,
  ) =>
      _updateLine(transfer, line, () => _confirmProduct(currentTransfer(transfer), line, barcode));

  Future<Either<Failure, OtherDocumentEntity>> _updateLine(
    OtherDocumentEntity transfer,
    OtherDocumentLine line,
    Future<Either<Failure, OtherDocumentEntity>> Function() call,
  ) async {
    final key = _key(transfer.id, line.productId);
    if (!_busy.add(key)) {
      return Either.left(const ValidationFailure('Ya se está procesando este producto'));
    }
    notifyListeners();

    final result = await call();
    _busy.remove(key);

    if (result.isLeft) {
      if (result.left is AuthenticationFailure) _onSessionExpired?.call();
      notifyListeners();
      return result;
    }

    // La respuesta no trae los costos de los productos: se conservan los que ya estaban y solo
    // se toma lo recibido, lo validado y el estado.
    final fresh = result.right;
    final s = stateOf(OtherDocumentKind.traslado);
    final index = s.items.indexWhere((i) => i.id == transfer.id);
    final old = index >= 0 ? s.items[index] : transfer;
    final merged = old.copyWith(
      activo: fresh.activo,
      lines: [
        for (final l in old.lines)
          () {
            final updated = fresh.lines.where((f) => f.productId == l.productId);
            return updated.isEmpty
                ? l
                : l.copyWith(aceptado: updated.first.aceptado, confirmado: updated.first.confirmado);
          }(),
      ],
    );
    if (index >= 0) s.items = [...s.items]..[index] = merged;
    notifyListeners();
    return Either.right(merged);
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
