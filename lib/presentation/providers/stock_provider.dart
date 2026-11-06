import 'package:flutter/material.dart';
import '../../core/errors/failures.dart';
import '../../core/utils/either.dart';
import 'dart:typed_data';
import '../../domain/entities/document_entity.dart' show DownloadedFile;
import '../../domain/entities/other_document_entity.dart';
import '../../domain/entities/product_form_entity.dart';
import '../../domain/entities/stock_entity.dart';
import '../../domain/entities/stock_manage_entity.dart';
import '../../domain/usecases/stock_manage_usecases.dart';
import '../../domain/usecases/stock_usecases.dart';

/// Estado del módulo Stock: almacén elegido, lista de precios, búsqueda, filtros y las
/// existencias paginadas de ese almacén; y las operaciones que cambian el stock (aumentar,
/// actualizar, subir desde Excel y transferir).
class StockProvider extends ChangeNotifier {
  static const pageSize = 20;

  final GetWarehousesUseCase _getWarehouses;
  final GetPriceListsUseCase _getPriceLists;
  final GetStockUseCase _getStock;
  final ExportStockUseCase _exportStock;
  final SearchStockProductsUseCase _searchProducts;
  final AddStockUseCase _addStock;
  final UpdateStockUseCase _updateStock;
  final DownloadStockTemplateUseCase _downloadTemplate;
  final ImportStockUseCase _importStock;
  final TransferStockUseCase _transferStock;

  /// Se llama cuando el backend responde 401 (token vencido).
  final VoidCallback? _onSessionExpired;

  StockProvider({
    required GetWarehousesUseCase getWarehousesUseCase,
    required GetPriceListsUseCase getPriceListsUseCase,
    required GetStockUseCase getStockUseCase,
    required ExportStockUseCase exportStockUseCase,
    required SearchStockProductsUseCase searchStockProductsUseCase,
    required AddStockUseCase addStockUseCase,
    required UpdateStockUseCase updateStockUseCase,
    required DownloadStockTemplateUseCase downloadStockTemplateUseCase,
    required ImportStockUseCase importStockUseCase,
    required TransferStockUseCase transferStockUseCase,
    VoidCallback? onSessionExpired,
  })  : _getWarehouses = getWarehousesUseCase,
        _getPriceLists = getPriceListsUseCase,
        _getStock = getStockUseCase,
        _exportStock = exportStockUseCase,
        _searchProducts = searchStockProductsUseCase,
        _addStock = addStockUseCase,
        _updateStock = updateStockUseCase,
        _downloadTemplate = downloadStockTemplateUseCase,
        _importStock = importStockUseCase,
        _transferStock = transferStockUseCase,
        _onSessionExpired = onSessionExpired;

  int? _companyId;
  int? _userId;
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

  /// Lo que se está escribiendo en el buscador (cada palabra es un término).
  List<String> search = const [];

  /// Términos ya confirmados (con "buscar"), como los chips de la web; cada uno puede ser una
  /// frase y se muestra para poder quitarlo.
  List<String> searchTerms = const [];

  /// `'p'` productos, `'s'` servicios, `null` ambos.
  String? tipo;

  List<StockItemEntity> items = [];
  bool loading = false;
  bool loadingMore = false;
  bool hasMore = false;
  int total = 0;
  double costoTotal = 0;
  double totalVenta = 0;
  String? error;
  bool exporting = false;

  PriceListEntity? get priceList {
    for (final p in priceLists) {
      if (p.id == priceListId) return p;
    }
    return null;
  }

  bool get filtersActive => includeZero || tipo != null;

  /// Todos los términos que se mandan al servidor: los confirmados y los que se están escribiendo.
  List<String> get terms => [...searchTerms, ...search];

  /// Se llama cuando cambia la sesión. Al cambiar de empresa se descarta todo.
  /// No notifica: corre mientras se construye el árbol de widgets.
  void syncSession(
    int? companyId, {
    int? defaultWarehouseId,
    int? defaultPriceListId,
    int? userId,
  }) {
    _userId = userId;
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
    tipo = null;
    search = const [];
    searchTerms = const [];
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

  /// Cambia "incluir sin stock" y el tipo a la vez, con un solo pedido al servidor.
  Future<void> setFilters({required bool includeZero, String? tipo}) {
    this.includeZero = includeZero;
    this.tipo = tipo;
    return refresh();
  }

  Future<void> setSearch(String text) {
    search = text.split(RegExp(r'[\s,]+')).where((t) => t.isNotEmpty).toList();
    return refresh();
  }

  Future<void> setTipo(String? value) {
    tipo = value;
    return refresh();
  }

  /// Confirma [text] como un término de búsqueda (como agregar un chip en la web). Los
  /// repetidos y los vacíos se ignoran; lo que se estaba escribiendo pasa a ser el término.
  Future<void> addSearchTerm(String text) {
    final term = text.trim();
    search = const [];
    if (term.isEmpty || searchTerms.contains(term)) return refresh();
    searchTerms = [...searchTerms, term];
    return refresh();
  }

  Future<void> removeSearchTerm(String term) {
    searchTerms = [
      for (final t in searchTerms)
        if (t != term) t,
    ];
    return refresh();
  }

  Future<void> clearSearchTerms() {
    searchTerms = const [];
    return refresh();
  }

  /// Excel del almacén elegido (todos sus productos), con la búsqueda actual.
  Future<Either<Failure, DownloadedFile>> exportCurrent() async {
    final warehouse = warehouseId;
    if (warehouse == null || exporting) {
      return Either.left(const ValidationFailure('Elige un almacén para exportar'));
    }
    var name = 'Stock';
    for (final w in warehouses) {
      if (w.id == warehouse) name = w.name;
    }

    exporting = true;
    notifyListeners();
    final result = await _exportStock(
      warehouseId: warehouse,
      priceListId: priceListId,
      search: terms,
      name: '$name.xlsx',
    );
    exporting = false;
    if (result.isLeft && result.left is AuthenticationFailure) _onSessionExpired?.call();
    notifyListeners();
    return result;
  }

  // ---- Operaciones que cambian el stock ------------------------------------------------

  /// Avisa que venció la sesión si el fallo es de autenticación.
  void _check(Failure failure) {
    if (failure is AuthenticationFailure) _onSessionExpired?.call();
  }

  /// Productos para armar un aumento de stock o una transferencia.
  Future<Either<Failure, List<StockProductEntity>>> searchProducts(String text) async {
    final companyId = _companyId;
    if (companyId == null) {
      return Either.left(const ValidationFailure('No hay una empresa activa'));
    }
    final result = await _searchProducts(companyId: companyId, search: text);
    if (result.isLeft) _check(result.left);
    return result;
  }

  /// Aumenta el stock de [lines] en [warehouseId]. Devuelve `null` si salió bien o el mensaje.
  Future<String?> addStock(int? warehouseId, List<StockEntryLine> lines) async {
    final result = await _addStock(warehouseId: warehouseId, lines: lines);
    if (result.isLeft) {
      _check(result.left);
      return result.left.message;
    }
    if (warehouseId == this.warehouseId) await refresh();
    return null;
  }

  /// Deja el stock de [item] en [newStock] en el almacén elegido (manda la diferencia).
  Future<String?> updateStock(StockItemEntity item, double newStock) async {
    final warehouse = warehouseId;
    if (warehouse == null) return 'Elige un almacén';
    final result = await _updateStock(warehouseId: warehouse, item: item, newStock: newStock);
    if (result.isLeft) {
      _check(result.left);
      return result.left.message;
    }
    await refresh();
    return null;
  }

  /// Plantilla de Excel para subir stocks.
  Future<Either<Failure, DownloadedFile>> downloadStockTemplate() async {
    final result = await _downloadTemplate();
    if (result.isLeft) _check(result.left);
    return result;
  }

  /// Sube el Excel de stocks de [warehouseId]; las filas buenas suman y las malas se devuelven.
  Future<Either<Failure, StockImportResultEntity>> importStock({
    required int? warehouseId,
    required String fileName,
    required Uint8List bytes,
  }) async {
    final companyId = _companyId;
    if (companyId == null) {
      return Either.left(const ValidationFailure('No hay una empresa activa'));
    }
    final result = await _importStock(
      companyId: companyId,
      warehouseId: warehouseId,
      fileName: fileName,
      bytes: bytes,
    );
    if (result.isLeft) {
      _check(result.left);
    } else if (warehouseId == this.warehouseId) {
      await refresh();
    }
    return result;
  }

  /// Transfiere [lines] de [from] a [to]; devuelve el traslado creado.
  Future<Either<Failure, OtherDocumentEntity>> transferStock({
    required int? from,
    required int? to,
    required List<StockTransferLine> lines,
  }) async {
    final companyId = _companyId;
    if (companyId == null) {
      return Either.left(const ValidationFailure('No hay una empresa activa'));
    }
    final result = await _transferStock(
      companyId: companyId,
      userId: _userId,
      from: from,
      to: to,
      lines: lines,
    );
    if (result.isLeft) {
      _check(result.left);
    } else if (from == warehouseId || to == warehouseId) {
      await refresh();
    }
    return result;
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
      search: terms,
      includeZero: includeZero,
      tipo: tipo,
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
