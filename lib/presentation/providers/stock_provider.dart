import 'package:flutter/material.dart';
import '../../core/errors/failures.dart';
import '../../domain/entities/product_form_entity.dart';
import '../../domain/entities/stock_entity.dart';
import '../../domain/usecases/stock_usecases.dart';

/// Estado del módulo Stock: almacén elegido, lista de precios, búsqueda y las
/// existencias paginadas de ese almacén.
class StockProvider extends ChangeNotifier {
  static const pageSize = 20;

  final GetWarehousesUseCase _getWarehouses;
  final GetPriceListsUseCase _getPriceLists;
  final GetStockUseCase _getStock;

  /// Se llama cuando el backend responde 401 (token vencido).
  final VoidCallback? _onSessionExpired;

  StockProvider({
    required GetWarehousesUseCase getWarehousesUseCase,
    required GetPriceListsUseCase getPriceListsUseCase,
    required GetStockUseCase getStockUseCase,
    VoidCallback? onSessionExpired,
  })  : _getWarehouses = getWarehousesUseCase,
        _getPriceLists = getPriceListsUseCase,
        _getStock = getStockUseCase,
        _onSessionExpired = onSessionExpired;

  int? _companyId;
  int? _defaultWarehouseId;
  int? _defaultPriceListId;
  bool _initialized = false;
  int _page = 0;
  int _request = 0;

  List<CatalogItemEntity> warehouses = [];
  List<PriceListEntity> priceLists = [];
  int? warehouseId;
  int? priceListId;
  bool includeZero = false;
  List<String> search = const [];

  List<StockItemEntity> items = [];
  bool loading = false;
  bool loadingMore = false;
  bool hasMore = false;
  int total = 0;
  double costoTotal = 0;
  double totalVenta = 0;
  String? error;

  PriceListEntity? get priceList {
    for (final p in priceLists) {
      if (p.id == priceListId) return p;
    }
    return null;
  }

  bool get filtersActive => includeZero;

  /// Se llama cuando cambia la sesión. Al cambiar de empresa se descarta todo.
  /// No notifica: corre mientras se construye el árbol de widgets.
  void syncSession(int? companyId, {int? defaultWarehouseId, int? defaultPriceListId}) {
    _defaultWarehouseId = defaultWarehouseId;
    _defaultPriceListId = defaultPriceListId;
    if (companyId == _companyId) return;
    _companyId = companyId;
    _initialized = false;
    warehouses = [];
    priceLists = [];
    warehouseId = null;
    priceListId = null;
    includeZero = false;
    search = const [];
    items = [];
    loading = false;
    loadingMore = false;
    hasMore = false;
    total = 0;
    costoTotal = 0;
    totalVenta = 0;
    error = null;
    _page = 0;
    _request++;
  }

  /// Carga almacenes y listas de precios la primera vez y pide las existencias.
  Future<void> ensureLoaded() async {
    if (_companyId == null || _initialized || loading) return;
    await _initialize();
  }

  Future<void> _initialize() async {
    final companyId = _companyId!;
    final request = ++_request;
    loading = true;
    error = null;
    notifyListeners();

    final results = await Future.wait([
      _getWarehouses(companyId),
      _getPriceLists(companyId),
    ]);
    if (request != _request) return;

    final warehousesResult = results[0];
    final priceListsResult = results[1];

    if (warehousesResult.isLeft) {
      final failure = warehousesResult.left;
      error = failure.message;
      loading = false;
      if (failure is AuthenticationFailure) _onSessionExpired?.call();
      notifyListeners();
      return;
    }

    warehouses = warehousesResult.right as List<CatalogItemEntity>;
    // Las listas de precios son opcionales: sin ellas solo no hay columna de precio.
    priceLists = priceListsResult.isRight
        ? priceListsResult.right as List<PriceListEntity>
        : [];

    warehouseId = _pick(warehouses.map((w) => w.id).toList(), _defaultWarehouseId);
    priceListId = _pick(priceLists.map((p) => p.id).toList(), _defaultPriceListId);
    _initialized = true;

    if (warehouseId == null) {
      loading = false;
      notifyListeners();
      return;
    }
    loading = false;
    await _fetch(page: 1);
  }

  /// El predeterminado si existe en [ids]; si no, el último (como la web).
  int? _pick(List<int> ids, int? preferred) {
    if (ids.isEmpty) return null;
    return ids.contains(preferred) ? preferred : ids.last;
  }

  Future<void> refresh() async {
    if (!_initialized) return ensureLoaded();
    await _fetch(page: 1);
  }

  Future<void> loadMore() async {
    if (loading || loadingMore || !hasMore) return;
    await _fetch(page: _page + 1);
  }

  Future<void> selectWarehouse(int? id) {
    warehouseId = id;
    return refresh();
  }

  Future<void> selectPriceList(int? id) {
    priceListId = id;
    return refresh();
  }

  Future<void> setIncludeZero(bool value) {
    includeZero = value;
    return refresh();
  }

  Future<void> setSearch(String text) {
    search = text.split(RegExp(r'[\s,]+')).where((t) => t.isNotEmpty).toList();
    return refresh();
  }

  Future<void> _fetch({required int page}) async {
    final companyId = _companyId;
    final warehouse = warehouseId;
    if (companyId == null || warehouse == null) return;

    final request = ++_request;
    final first = page == 1;
    if (first) {
      loading = true;
      error = null;
    } else {
      loadingMore = true;
    }
    notifyListeners();

    final result = await _getStock(
      companyId: companyId,
      warehouseId: warehouse,
      priceListId: priceListId,
      search: search,
      includeZero: includeZero,
      page: page,
      pageSize: pageSize,
    );

    // Llegó tarde: ya se pidió otra cosa (otro almacén, otra búsqueda).
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
        costoTotal = data.costoTotal;
        totalVenta = data.totalVenta;
        error = null;
      },
    );
    loading = false;
    loadingMore = false;
    notifyListeners();
  }
}
