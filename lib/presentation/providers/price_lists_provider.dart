import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../core/errors/failures.dart';
import '../../core/utils/either.dart';
import '../../domain/entities/document_entity.dart' show DownloadedFile;
import '../../domain/entities/import_entity.dart';
import '../../domain/entities/price_list_entity.dart';
import '../../domain/usecases/price_list_usecases.dart';

/// Estado del módulo Lista de precios: las listas de la empresa (búsqueda por nombre con chips,
/// filtros de moneda y estado, paginación, crear y editar) y, de la lista que se abre, sus
/// productos con el precio de cada uno (búsqueda, filtro de tipo, cambiar el precio, descargar la
/// plantilla y subir los precios desde Excel).
class PriceListsProvider extends ChangeNotifier {
  static const pageSize = 30;

  /// La web trae los productos de a 50.
  static const productPageSize = 50;

  final GetPriceListPageUseCase _getPriceLists;
  final SavePriceListUseCase _savePriceList;
  final GetPriceListProductsUseCase _getProducts;
  final UpdatePriceListPriceUseCase _updatePrice;
  final ExportPriceListTemplateUseCase _exportTemplate;
  final ImportPriceListUseCase _importPrices;

  /// Se llama cuando el backend responde 401 (token vencido).
  final VoidCallback? _onSessionExpired;

  PriceListsProvider({
    required GetPriceListPageUseCase getPriceListsUseCase,
    required SavePriceListUseCase savePriceListUseCase,
    required GetPriceListProductsUseCase getProductsUseCase,
    required UpdatePriceListPriceUseCase updatePriceUseCase,
    required ExportPriceListTemplateUseCase exportTemplateUseCase,
    required ImportPriceListUseCase importPricesUseCase,
    VoidCallback? onSessionExpired,
  }) : _getPriceLists = getPriceListsUseCase,
       _savePriceList = savePriceListUseCase,
       _getProducts = getProductsUseCase,
       _updatePrice = updatePriceUseCase,
       _exportTemplate = exportTemplateUseCase,
       _importPrices = importPricesUseCase,
       // ignore: prefer_initializing_formals
       _onSessionExpired = onSessionExpired;

  int? _companyId;
  int _page = 0;
  int _request = 0;

  // Las listas.
  List<PriceListEntity> items = [];
  bool loading = false;
  bool loadingMore = false;
  bool hasMore = false;
  int total = 0;
  String? error;

  /// Lo que se está escribiendo en el buscador.
  String search = '';

  /// Términos ya confirmados (con "buscar"), como los chips de la web.
  List<String> searchTerms = const [];

  /// Moneda (`s`/`d`) y estado elegidos en el panel de filtros.
  String? currency;
  bool? active;

  // El detalle de la lista que se abrió.
  PriceListEntity? current;
  List<PriceListProductEntity> products = [];
  bool loadingProducts = false;
  bool loadingMoreProducts = false;
  bool hasMoreProducts = false;
  int productsTotal = 0;
  String? productsError;
  PriceListProductFiltersEntity productFilters =
      const PriceListProductFiltersEntity();
  bool exporting = false;
  bool importing = false;
  int _productPage = 0;
  int _productRequest = 0;

  bool get filtersActive => currency != null || active != null;

  /// Todos los términos que se mandan al servidor: los confirmados y el que se está escribiendo.
  List<String> get terms => [...searchTerms, if (search.isNotEmpty) search];

  PriceListFiltersEntity get filters =>
      PriceListFiltersEntity(terms: terms, currency: currency, active: active);

  /// Se llama cuando cambia la sesión. Al cambiar de empresa se descarta todo, para no mostrar
  /// listas de la empresa anterior. No notifica: corre mientras se arma el árbol de widgets.
  void syncCompany(int? companyId) {
    if (companyId == _companyId) return;
    _companyId = companyId;
    items = [];
    loading = false;
    loadingMore = false;
    hasMore = false;
    total = 0;
    error = null;
    search = '';
    searchTerms = const [];
    currency = null;
    active = null;
    _page = 0;
    _request++;
    _resetDetail();
  }

  void _resetDetail() {
    current = null;
    products = [];
    loadingProducts = false;
    loadingMoreProducts = false;
    hasMoreProducts = false;
    productsTotal = 0;
    productsError = null;
    productFilters = const PriceListProductFiltersEntity();
    _productPage = 0;
    _productRequest++;
  }

  bool _isExpired(Failure failure) {
    if (failure is AuthenticationFailure) {
      _onSessionExpired?.call();
      return true;
    }
    return false;
  }

  // ---------------------------------------------------------------- Las listas

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
    search = text.trim();
    return refresh();
  }

  /// Confirma [text] como un término de búsqueda (como agregar un chip en la web). Los repetidos y
  /// los vacíos se ignoran; lo que se estaba escribiendo pasa a ser el término.
  Future<void> addSearchTerm(String text) {
    final term = text.trim();
    search = '';
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

  /// Cambia la moneda y el estado a la vez, con un solo pedido al servidor.
  Future<void> setFilters({String? currency, bool? active}) {
    this.currency = currency;
    this.active = active;
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

    final result = await _getPriceLists(
      companyId: companyId,
      page: page,
      pageSize: pageSize,
      filters: filters,
    );

    // Llegó tarde: ya se pidió otra cosa (otra búsqueda, otra empresa).
    if (request != _request) return;

    result.fold(
      (failure) {
        if (first) {
          items = [];
          hasMore = false;
          total = 0;
          error = failure.message;
        }
        _isExpired(failure);
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

  /// Crea la lista, o la edita si se pasa [id], y recarga la lista. Devuelve `null` si salió bien o
  /// el mensaje de error.
  Future<String?> save(PriceListFormEntity form, {int? id}) async {
    final companyId = _companyId;
    if (companyId == null) return 'No hay una empresa activa';

    final result = await _savePriceList(
      companyId: companyId,
      form: form,
      id: id,
    );
    return result.fold(
      (failure) {
        _isExpired(failure);
        return failure.message;
      },
      (_) {
        refresh();
        return null;
      },
    );
  }

  // ---------------------------------------------------------------- El detalle

  /// Abre el detalle de [list]: descarta lo de la lista anterior y trae sus productos.
  Future<void> openList(PriceListEntity list) {
    _resetDetail();
    current = list;
    return refreshProducts();
  }

  Future<void> refreshProducts() => _fetchProducts(page: 1);

  Future<void> loadMoreProducts() async {
    if (loadingProducts || loadingMoreProducts || !hasMoreProducts) return;
    await _fetchProducts(page: _productPage + 1);
  }

  /// La web busca de un solo texto a la vez en el detalle (vacío = sin búsqueda).
  Future<void> setProductSearch(String text) {
    productFilters = productFilters.copyWith(search: text.trim());
    return refreshProducts();
  }

  Future<void> setProductTipo(String? tipo) {
    productFilters = tipo == null
        ? productFilters.copyWith(clearTipo: true)
        : productFilters.copyWith(tipo: tipo);
    return refreshProducts();
  }

  Future<void> _fetchProducts({required int page}) async {
    final list = current;
    if (list == null) return;

    final request = ++_productRequest;
    final first = page == 1;
    if (first) {
      loadingProducts = true;
      productsError = null;
    } else {
      loadingMoreProducts = true;
    }
    notifyListeners();

    final result = await _getProducts(
      listPriceId: list.id,
      page: page,
      pageSize: productPageSize,
      filters: productFilters,
    );

    // Llegó tarde: ya se pidió otra cosa (otra búsqueda u otra lista).
    if (request != _productRequest) return;

    result.fold(
      (failure) {
        if (first) {
          products = [];
          hasMoreProducts = false;
          productsTotal = 0;
          productsError = failure.message;
        }
        _isExpired(failure);
      },
      (data) {
        products = first ? data.items : [...products, ...data.items];
        _productPage = data.currentPage;
        hasMoreProducts = data.hasMore;
        productsTotal = data.total;
        productsError = null;
      },
    );
    loadingProducts = false;
    loadingMoreProducts = false;
    notifyListeners();
  }

  /// Cambia el precio de [product] en la lista abierta. Devuelve `null` si salió bien o el mensaje
  /// de error. El producto de la lista queda con el precio que confirmó el servidor.
  Future<String?> updatePrice(
    PriceListProductEntity product,
    double precio,
  ) async {
    final list = current;
    if (list == null) return 'No hay una lista abierta';

    final result = await _updatePrice(
      listPriceId: list.id,
      productId: product.id,
      precio: precio,
    );
    return result.fold(
      (failure) {
        _isExpired(failure);
        return failure.message;
      },
      (updated) {
        // Si el servidor no devuelve el precio, vale el que se mandó.
        final value = updated.precio ?? precio;
        if (current?.id == list.id) {
          products = [
            for (final p in products)
              if (p.id == product.id) p.withPrice(value) else p,
          ];
          notifyListeners();
        }
        return null;
      },
    );
  }

  /// Excel con todos los productos y su precio en la lista abierta (la plantilla), con el nombre que
  /// le pone la web: `Lista de {nombre}.xlsx`.
  Future<Either<Failure, DownloadedFile>> downloadTemplate() async {
    final list = current;
    if (list == null) {
      return Either.left(const ValidationFailure('No hay una lista abierta'));
    }
    if (exporting) {
      return Either.left(const ValidationFailure('Ya se está descargando'));
    }
    exporting = true;
    notifyListeners();
    final result = await _exportTemplate(listPriceId: list.id);
    exporting = false;
    if (result.isLeft) _isExpired(result.left);
    notifyListeners();
    return result.fold(
      Either<Failure, DownloadedFile>.left,
      (Uint8List bytes) => Either.right(
        DownloadedFile(name: 'Lista de ${list.name}.xlsx', bytes: bytes),
      ),
    );
  }

  /// Sube el Excel con los precios a la lista abierta. Al terminar bien, los productos se vuelven a
  /// pedir para ver los precios nuevos.
  Future<Either<Failure, ImportResultEntity>> importPrices({
    required String fileName,
    required Uint8List bytes,
  }) async {
    final list = current;
    final companyId = _companyId;
    if (list == null || companyId == null) {
      return Either.left(const ValidationFailure('No hay una lista abierta'));
    }
    if (importing) {
      return Either.left(
        const ValidationFailure('Ya se está subiendo un archivo'),
      );
    }

    importing = true;
    notifyListeners();
    final result = await _importPrices(
      listPriceId: list.id,
      companyId: companyId,
      fileName: fileName,
      bytes: bytes,
    );
    importing = false;
    if (result.isLeft) _isExpired(result.left);
    notifyListeners();
    if (result.isRight && current?.id == list.id) await refreshProducts();
    return result;
  }
}
