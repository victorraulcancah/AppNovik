import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../../core/errors/failures.dart';
import '../../core/utils/either.dart';
import '../../domain/entities/document_entity.dart' show DownloadedFile;
import '../../domain/entities/import_entity.dart';
import '../../domain/entities/product_entity.dart';
import '../../domain/entities/product_form_entity.dart';
import '../../domain/usecases/product_usecases.dart';

/// Estado de la lista de productos: búsqueda, filtro de tipo y paginación.
class ProductsProvider extends ChangeNotifier {
  static const pageSize = 20;

  final GetProductsUseCase _getProducts;
  final GetProductCatalogsUseCase _getCatalogs;
  final SaveProductUseCase _saveProduct;
  final ExportProductsUseCase _exportProducts;
  final ImportCatalogUseCase _importCatalog;
  final CreateCatalogItemUseCase _createCatalogItem;

  /// Se llama cuando el backend responde 401 (token vencido).
  final VoidCallback? _onSessionExpired;

  ProductsProvider({
    required GetProductsUseCase getProductsUseCase,
    required GetProductCatalogsUseCase getCatalogsUseCase,
    required SaveProductUseCase saveProductUseCase,
    required ExportProductsUseCase exportProductsUseCase,
    required ImportCatalogUseCase importCatalogUseCase,
    required CreateCatalogItemUseCase createCatalogItemUseCase,
    VoidCallback? onSessionExpired,
  })  : _getProducts = getProductsUseCase,
        _getCatalogs = getCatalogsUseCase,
        _saveProduct = saveProductUseCase,
        _exportProducts = exportProductsUseCase,
        _importCatalog = importCatalogUseCase,
        _createCatalogItem = createCatalogItemUseCase,
        _onSessionExpired = onSessionExpired;

  int? _companyId;
  ProductCatalogsEntity? _catalogs;
  int _page = 0;
  int _request = 0;

  List<ProductEntity> items = [];
  bool loading = false;
  bool loadingMore = false;
  bool hasMore = false;
  int total = 0;

  /// Productos y servicios que hay con la búsqueda y los filtros actuales.
  int totalProductos = 0;
  int totalServicios = 0;
  String? error;
  bool exporting = false;
  bool importing = false;

  /// Lo que se está escribiendo en el buscador (cada palabra es un término).
  List<String> search = const [];

  /// Términos ya confirmados (con "buscar"), como los chips de la web.
  List<String> searchTerms = const [];

  /// `'p'` productos, `'s'` servicios, `null` ambos.
  String? tipo;

  /// `true` solo activos, `false` solo inactivos, `null` todos.
  bool? activo;

  bool get filtersActive => tipo != null || activo != null;

  /// Todos los términos que se mandan al servidor: los confirmados y los que se están escribiendo.
  List<String> get terms => [...searchTerms, ...search];

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
    totalProductos = 0;
    totalServicios = 0;
    search = const [];
    searchTerms = const [];
    tipo = null;
    activo = null;
    _page = 0;
    _request++;
    _catalogs = null;
  }

  /// Catálogos del formulario (marcas, categorías...). Se piden una vez por
  /// empresa; lanza una excepción con el mensaje si falla.
  Future<ProductCatalogsEntity> loadCatalogs() async {
    final cached = _catalogs;
    if (cached != null) return cached;

    final result = await _getCatalogs();
    return result.fold(
      (failure) {
        if (failure is AuthenticationFailure) _onSessionExpired?.call();
        throw Exception(failure.message);
      },
      (catalogs) => _catalogs = catalogs,
    );
  }

  /// Crea una marca, categoría, unidad de medida, canal o giro (el "+" del formulario) y lo deja
  /// al principio del catálogo guardado. Lanza una excepción con el mensaje si falla.
  Future<CatalogItemEntity> createCatalogItem(CatalogKind kind, String name) async {
    final result = await _createCatalogItem(kind: kind, name: name);
    return result.fold(
      (failure) {
        if (failure is AuthenticationFailure) _onSessionExpired?.call();
        throw Exception(failure.message);
      },
      (item) {
        final c = _catalogs;
        if (c != null) {
          List<CatalogItemEntity> add(List<CatalogItemEntity> list) => [item, ...list];
          _catalogs = ProductCatalogsEntity(
            marcas: kind == CatalogKind.marca ? add(c.marcas) : c.marcas,
            categorias: kind == CatalogKind.categoria ? add(c.categorias) : c.categorias,
            medidas: kind == CatalogKind.medida ? add(c.medidas) : c.medidas,
            proveedores: c.proveedores,
            canales: kind == CatalogKind.canal ? add(c.canales) : c.canales,
            giros: kind == CatalogKind.giro ? add(c.giros) : c.giros,
          );
        }
        return item;
      },
    );
  }

  /// Crea el producto, o lo edita si se pasa [id], y recarga la lista.
  /// Devuelve `null` si salió bien o el mensaje de error.
  Future<String?> saveProduct(ProductFormEntity form, {int? id}) async {
    final companyId = _companyId;
    if (companyId == null) return 'No hay una empresa activa';

    final result = await _saveProduct(companyId: companyId, form: form, id: id);
    return result.fold(
      (failure) {
        if (failure is AuthenticationFailure) _onSessionExpired?.call();
        return failure.message;
      },
      (_) {
        refresh();
        return null;
      },
    );
  }

  /// Excel con todos los productos de la empresa.
  Future<Either<Failure, DownloadedFile>> exportAll() async {
    if (exporting) return Either.left(const ValidationFailure('Ya se está exportando'));
    exporting = true;
    notifyListeners();
    final result = await _exportProducts();
    exporting = false;
    if (result.isLeft && result.left is AuthenticationFailure) _onSessionExpired?.call();
    notifyListeners();
    return result;
  }

  /// Sube un Excel de productos, marcas o categorías. Al terminar, la lista de productos se
  /// recarga y los catálogos del formulario (marcas, categorías) se vuelven a pedir.
  Future<Either<Failure, ImportResultEntity>> importFile(
    ImportKind kind, {
    required String fileName,
    required Uint8List bytes,
  }) async {
    final companyId = _companyId;
    if (companyId == null) return Either.left(const ValidationFailure('No hay una empresa activa'));
    if (importing) return Either.left(const ValidationFailure('Ya se está subiendo un archivo'));

    importing = true;
    notifyListeners();
    final result = await _importCatalog(
      companyId: companyId,
      kind: kind,
      fileName: fileName,
      bytes: bytes,
    );
    importing = false;
    if (result.isLeft && result.left is AuthenticationFailure) _onSessionExpired?.call();
    if (result.isRight) {
      _catalogs = null;
      notifyListeners();
      await refresh();
    } else {
      notifyListeners();
    }
    return result;
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

  /// Cambia el tipo y el estado a la vez, con un solo pedido al servidor.
  Future<void> setFilters({String? tipo, bool? activo}) {
    this.tipo = tipo;
    this.activo = activo;
    return refresh();
  }

  Future<void> setActivo(bool? value) {
    activo = value;
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
      search: terms,
      tipo: tipo,
      activo: activo,
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
        totalProductos = data.totalProductos;
        totalServicios = data.totalServicios;
        error = null;
      },
    );
    loading = false;
    loadingMore = false;
    notifyListeners();
  }
}
