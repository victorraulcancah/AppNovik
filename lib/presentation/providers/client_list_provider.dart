import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../../core/errors/failures.dart';
import '../../core/utils/either.dart';
import '../../domain/entities/client_record_entity.dart';
import '../../domain/entities/document_entity.dart' show DownloadedFile;
import '../../domain/entities/session_context_entity.dart';
import '../../domain/usecases/client_record_usecases.dart';

/// Estado del módulo Clientes: lista con búsqueda, filtros y paginación, guardado del formulario,
/// categorías y Excel. (Ventas usa otro, `ClientsProvider`, solo para crear un cliente al vender.)
class ClientListProvider extends ChangeNotifier {
  static const pageSize = 20;

  /// Los únicos roles que pueden ser ejecutivo comercial de un cliente.
  static const executiveRoles = ['Vendedor', 'Ceo Empresa'];

  /// Roles que, aunque también sean Vendedor, sí pueden elegir el ejecutivo y activar o
  /// inactivar clientes.
  static const _privilegedRoles = ['Admin Global', 'Ceo Empresa', 'Admin Empresa', 'Contador', 'JEFE COMERCIAL'];

  final GetClientsUseCase _getClients;
  final GetClientFilterCatalogsUseCase _getFilterCatalogs;
  final GetClientFormCatalogsUseCase _getFormCatalogs;
  final SaveClientUseCase _saveClient;
  final ExportClientsUseCase _exportClients;
  final GetClientCategoriesUseCase _getCategories;
  final SaveClientCategoriesUseCase _saveCategories;

  /// Se llama cuando el backend responde 401 (token vencido).
  final VoidCallback? _onSessionExpired;

  ClientListProvider({
    required GetClientsUseCase getClientsUseCase,
    required GetClientFilterCatalogsUseCase getFilterCatalogsUseCase,
    required GetClientFormCatalogsUseCase getFormCatalogsUseCase,
    required SaveClientUseCase saveClientUseCase,
    required ExportClientsUseCase exportClientsUseCase,
    required GetClientCategoriesUseCase getCategoriesUseCase,
    required SaveClientCategoriesUseCase saveCategoriesUseCase,
    VoidCallback? onSessionExpired,
  })  : _getClients = getClientsUseCase,
        _getFilterCatalogs = getFilterCatalogsUseCase,
        _getFormCatalogs = getFormCatalogsUseCase,
        _saveClient = saveClientUseCase,
        _exportClients = exportClientsUseCase,
        _getCategories = getCategoriesUseCase,
        _saveCategories = saveCategoriesUseCase,
        _onSessionExpired = onSessionExpired;

  int? _companyId;
  int? _userId;
  bool _isOnlySeller = false;
  int _page = 0;
  int _request = 0;
  ClientFilterCatalogsEntity? _filterCatalogs;
  ClientFormCatalogsEntity? _formCatalogs;

  List<ClientRecordEntity> items = [];
  bool loading = false;
  bool loadingMore = false;
  bool hasMore = false;
  int total = 0;
  int totalPersonas = 0;
  int totalEmpresas = 0;
  String? error;
  bool exporting = false;
  ClientFiltersEntity filters = const ClientFiltersEntity();

  int? get userId => _userId;

  /// El contador "Todos" de la cabecera.
  int get allCount => filters.tipo == null ? total : totalPersonas + totalEmpresas;

  /// Un Vendedor (sin otro rol de mando) no elige el ejecutivo comercial ni activa o inactiva
  /// clientes: el cliente que crea queda en su cartera. El backend lo hace cumplir.
  bool get isOnlySeller => _isOnlySeller;

  /// Se llama cuando cambia la sesión. Al cambiar de empresa se descarta todo, para no mostrar
  /// clientes de la empresa anterior. No notifica: corre mientras se arma el árbol de widgets.
  void syncSession(SessionContextEntity? session) {
    final companyId = session?.company.id;
    _userId = session?.user.id;
    _isOnlySeller = session != null &&
        session.hasRole('Vendedor') &&
        !_privilegedRoles.any(session.hasRole);
    if (companyId == _companyId) return;
    _companyId = companyId;
    items = [];
    loading = false;
    loadingMore = false;
    hasMore = false;
    total = 0;
    totalPersonas = 0;
    totalEmpresas = 0;
    error = null;
    filters = const ClientFiltersEntity();
    _page = 0;
    _request++;
    _filterCatalogs = null;
    _formCatalogs = null;
  }

  bool _isExpired(Failure failure) {
    if (failure is AuthenticationFailure) {
      _onSessionExpired?.call();
      return true;
    }
    return false;
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
    filters = filters.copyWith(
      search: text.split(RegExp(r'\s+')).where((t) => t.isNotEmpty).toList(),
    );
    return refresh();
  }

  Future<void> setFilters(ClientFiltersEntity value) {
    filters = value;
    return refresh();
  }

  /// Cambia solo Personas / Empresas (los contadores de la cabecera de la web).
  Future<void> setTipo(String? tipo) =>
      setFilters(tipo == null ? filters.copyWith(clearTipo: true) : filters.copyWith(tipo: tipo));

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

    final result = await _getClients(
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
          error = failure.message;
        }
        _isExpired(failure);
      },
      (data) {
        items = first ? data.items : [...items, ...data.items];
        _page = data.currentPage;
        hasMore = data.hasMore;
        total = data.total;
        // El backend cuenta sobre lo filtrado: con un tipo elegido solo ese tipo trae clientes, así
        // que el otro conserva el último conteo conocido.
        switch (filters.tipo) {
          case null:
            totalPersonas = data.totalPersonas;
            totalEmpresas = data.totalEmpresas;
          case 'p':
            totalPersonas = data.total;
          default:
            totalEmpresas = data.total;
        }
        error = null;
      },
    );
    loading = false;
    loadingMore = false;
    notifyListeners();
  }

  /// Lo que ya se trajo para el panel de filtros (para ponerle nombre a los chips de filtros activos);
  /// `null` hasta que se abre el panel por primera vez.
  ClientFilterCatalogsEntity? get filterCatalogs => _filterCatalogs;

  /// Categorías, ejecutivos y departamentos que ofrece el filtro. Se piden una vez por empresa;
  /// si fallan, el filtro se abre con lo que haya (solo los filtros fijos: tipo y estado).
  Future<ClientFilterCatalogsEntity> loadFilterCatalogs() async {
    final cached = _filterCatalogs;
    if (cached != null) return cached;
    final result = await _getFilterCatalogs();
    if (result.isLeft) {
      _isExpired(result.left);
      return const ClientFilterCatalogsEntity();
    }
    return _filterCatalogs = result.right;
  }

  /// Ejecutivos, listas de precios, métodos de pago y categorías del formulario. Lanza una
  /// excepción con el mensaje si falla.
  Future<ClientFormCatalogsEntity> loadFormCatalogs() async {
    final cached = _formCatalogs;
    if (cached != null) return cached;
    final companyId = _companyId;
    if (companyId == null) throw Exception('No hay una empresa activa');

    final result = await _getFormCatalogs(companyId: companyId);
    return result.fold(
      (failure) {
        _isExpired(failure);
        throw Exception(failure.message);
      },
      (catalogs) => _formCatalogs = catalogs,
    );
  }

  /// Crea el cliente, o lo edita si se pasa [id]. Devuelve `null` si salió bien o el mensaje de
  /// error. El cliente guardado entra a la lista (arriba si es nuevo, en su lugar si se editó).
  Future<String?> saveClient(ClientFormEntity form, {int? id, String? originalEmail}) async {
    final companyId = _companyId;
    if (companyId == null) return 'No hay una empresa activa';

    final result = await _saveClient(
      companyId: companyId,
      form: form,
      id: id,
      originalEmail: originalEmail,
    );
    if (result.isLeft) {
      _isExpired(result.left);
      return result.left.message;
    }

    final saved = result.right;
    if (id != null) {
      items = [for (final c in items) c.id == saved.id ? saved : c];
    } else {
      items = [saved, ...items];
      total++;
      if (saved.esEmpresa) {
        totalEmpresas++;
      } else {
        totalPersonas++;
      }
    }
    notifyListeners();
    return null;
  }

  /// Excel con lo que se está viendo (la búsqueda y los filtros de la lista).
  Future<Either<Failure, DownloadedFile>> exportAll() async {
    final companyId = _companyId;
    if (companyId == null) return Either.left(const ValidationFailure('No hay una empresa activa'));
    if (exporting) return Either.left(const ValidationFailure('Ya se está exportando'));
    exporting = true;
    notifyListeners();
    final result = await _exportClients(companyId: companyId, filters: filters);
    exporting = false;
    if (result.isLeft) _isExpired(result.left);
    notifyListeners();
    return result.fold(
      Either<Failure, DownloadedFile>.left,
      (Uint8List bytes) => Either.right(DownloadedFile(name: 'Lista de Clientes.xlsx', bytes: bytes)),
    );
  }

  /// Las categorías y el ciclo, para mirarlas o configurarlas. Lanza una excepción con el
  /// mensaje si falla.
  Future<CategoriesConfigEntity> loadCategories() async {
    final result = await _getCategories();
    return result.fold(
      (failure) {
        _isExpired(failure);
        throw Exception(failure.message);
      },
      (config) => config,
    );
  }

  /// Guarda la configuración (y con [calculate] también calcula las categorías). Devuelve el
  /// resultado del cálculo si se hizo; lanza una excepción con el mensaje si falla. Si se
  /// recalcularon, la lista y los catálogos se recargan.
  Future<CategoryCalcEntity?> saveCategories({
    required List<ClientCategoryEntity> categorias,
    required String ciclo,
    bool calculate = false,
  }) async {
    final result = await _saveCategories(categorias: categorias, ciclo: ciclo, calculate: calculate);
    final calc = result.fold(
      (failure) {
        _isExpired(failure);
        throw Exception(failure.message);
      },
      (calc) => calc,
    );
    _formCatalogs = null;
    _filterCatalogs = null;
    if (calc?.recalculado ?? false) await refresh();
    return calc;
  }
}
