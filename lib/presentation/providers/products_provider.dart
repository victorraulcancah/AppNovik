import 'package:flutter/material.dart';
import '../../core/errors/failures.dart';
import '../../domain/entities/product_entity.dart';
import '../../domain/usecases/product_usecases.dart';

/// Estado de la lista de productos: búsqueda, filtro de tipo y paginación.
class ProductsProvider extends ChangeNotifier {
  static const pageSize = 20;

  final GetProductsUseCase _getProducts;

  /// Se llama cuando el backend responde 401 (token vencido).
  final VoidCallback? _onSessionExpired;

  ProductsProvider({
    required GetProductsUseCase getProductsUseCase,
    VoidCallback? onSessionExpired,
  })  : _getProducts = getProductsUseCase,
        _onSessionExpired = onSessionExpired;

  int? _companyId;
  int _page = 0;
  int _request = 0;

  List<ProductEntity> items = [];
  bool loading = false;
  bool loadingMore = false;
  bool hasMore = false;
  int total = 0;
  String? error;
  List<String> search = const [];

  /// `'p'` productos, `'s'` servicios, `null` ambos.
  String? tipo;

  bool get filtersActive => tipo != null;

  /// Se llama cuando cambia la sesión. Al cambiar de empresa se descarta todo,
  /// para no mostrar productos de la empresa anterior. No notifica: corre
  /// mientras se construye el árbol de widgets.
  void syncCompany(int? companyId) {
    if (companyId == _companyId) return;
    _companyId = companyId;
    items = [];
    loading = false;
    loadingMore = false;
    hasMore = false;
    total = 0;
    error = null;
    search = const [];
    tipo = null;
    _page = 0;
    _request++;
  }

  /// Carga la primera página si todavía no se cargó nada.
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

  Future<void> setSearch(String text) {
    search = text
        .split(RegExp(r'[\s,]+'))
        .where((t) => t.isNotEmpty)
        .toList();
    return refresh();
  }

  Future<void> setTipo(String? value) {
    tipo = value;
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

    final result = await _getProducts(
      companyId: companyId,
      page: page,
      pageSize: pageSize,
      search: search,
      tipo: tipo,
    );

    // Llegó tarde: ya se pidió otra cosa (otra búsqueda, otra empresa).
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
