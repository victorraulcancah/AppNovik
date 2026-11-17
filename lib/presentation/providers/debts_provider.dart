import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../../core/errors/failures.dart';
import '../../core/utils/either.dart';
import '../../domain/entities/debt_entity.dart';
import '../../domain/entities/document_entity.dart' show DownloadedFile;
import '../../domain/entities/session_context_entity.dart';
import '../../domain/usecases/debt_usecases.dart';

/// Estado del módulo Deudas: el resumen de deuda pendiente por cliente (soles y dólares, línea
/// de crédito usada y crédito), con búsqueda, filtros de cliente y ejecutivo comercial, totales,
/// paginación y Excel. Igual que la web, quien no ve a todos los vendedores queda filtrado por sí
/// mismo y no elige ejecutivo.
class DebtsProvider extends ChangeNotifier {
  static const pageSize = 30;

  final GetDebtsUseCase _getDebts;
  final SearchDebtClientsUseCase _searchClientsUseCase;
  final GetDebtSellersUseCase _getSellersUseCase;
  final ExportDebtsUseCase _exportDebts;

  /// Se llama cuando el backend responde 401 (token vencido).
  final VoidCallback? _onSessionExpired;

  DebtsProvider({
    required GetDebtsUseCase getDebtsUseCase,
    required SearchDebtClientsUseCase searchClientsUseCase,
    required GetDebtSellersUseCase getSellersUseCase,
    required ExportDebtsUseCase exportDebtsUseCase,
    VoidCallback? onSessionExpired,
  })  : _getDebts = getDebtsUseCase,
        _searchClientsUseCase = searchClientsUseCase,
        _getSellersUseCase = getSellersUseCase,
        _exportDebts = exportDebtsUseCase,
        _onSessionExpired = onSessionExpired;

  int? _companyId;
  int? _userId;
  bool _canSeeAll = false;
  int _page = 0;
  int _request = 0;
  List<DebtOption>? _sellers;
  List<DebtOption>? _clients;

  List<DebtClientEntity> items = [];
  bool loading = false;
  bool loadingMore = false;
  bool hasMore = false;
  int total = 0;
  double totalSoles = 0;
  double totalDolares = 0;
  String? error;
  bool exporting = false;
  DebtFiltersEntity filters = const DebtFiltersEntity();

  /// Si el usuario puede ver las deudas de todos los vendedores (y elegir ejecutivo).
  bool get canSeeAll => _canSeeAll;

  /// Los ejecutivos ya traídos para el filtro (`null` hasta pedirlos).
  List<DebtOption>? get sellers => _sellers;

  /// Los filtros tal como se mandan: sin ver a todos, siempre por el propio usuario.
  DebtFiltersEntity get _requestFilters => _canSeeAll || _userId == null
      ? filters
      : DebtFiltersEntity(
          search: filters.search,
          client: filters.client,
          seller: DebtOption(id: _userId!, name: ''),
        );

  /// Se llama cuando cambia la sesión. Al cambiar de empresa o de usuario se descarta todo. No
  /// notifica: corre mientras se arma el árbol de widgets.
  void syncSession(SessionContextEntity? session) {
    final companyId = session?.company.id;
    final userId = session?.user.id;
    _canSeeAll = session != null &&
        (session.can('pagos.todos_los_vendedores') || session.can('deudas.todos_los_vendedores'));
    if (companyId == _companyId && userId == _userId) return;
    _companyId = companyId;
    _userId = userId;
    items = [];
    loading = false;
    loadingMore = false;
    hasMore = false;
    total = 0;
    totalSoles = 0;
    totalDolares = 0;
    error = null;
    filters = const DebtFiltersEntity();
    _page = 0;
    _request++;
    _sellers = null;
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
    filters = filters.copyWith(search: text.trim());
    return refresh();
  }

  Future<void> setFilters(DebtFiltersEntity value) {
    filters = value;
    return refresh();
  }

  Future<void> _fetch({required int page}) async {
    if (_companyId == null) return;

    final request = ++_request;
    final first = page == 1;
    if (first) {
      loading = true;
      error = null;
    } else {
      loadingMore = true;
    }
    notifyListeners();

    final result = await _getDebts(page: page, pageSize: pageSize, filters: _requestFilters);

    // Llegó tarde: ya se pidió otra cosa (otra búsqueda, otra empresa).
    if (request != _request) return;

    result.fold(
      (failure) {
        if (first) {
          items = [];
          hasMore = false;
          total = 0;
          totalSoles = 0;
          totalDolares = 0;
          error = failure.message;
        }
        _isExpired(failure);
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
    loading = false;
    loadingMore = false;
    notifyListeners();
  }

  /// Busca clientes para el filtro (solo los de la cartera del usuario si no ve a todos).
  Future<Either<Failure, List<DebtOption>>> searchClients(String query) async {
    final companyId = _companyId;
    if (companyId == null) return Either.right(const []);
    final result = await _searchClientsUseCase(
      companyId: companyId,
      search: query,
      onlyMine: !_canSeeAll,
    );
    if (result.isLeft) _isExpired(result.left);
    return result;
  }

  /// Los ejecutivos comerciales para el filtro; se piden una vez por empresa. Si fallan, lanza
  /// una excepción con el mensaje.
  Future<List<DebtOption>> loadSellers() async {
    final cached = _sellers;
    if (cached != null) return cached;
    final companyId = _companyId;
    if (companyId == null) return const [];
    final result = await _getSellersUseCase(companyId: companyId);
    return result.fold(
      (failure) {
        _isExpired(failure);
        throw Exception(failure.message);
      },
      (list) => _sellers = list,
    );
  }

  /// Todos los clientes para el filtro (se piden una vez por empresa; con "solo mi cartera" si el
  /// usuario no ve a todos). Si fallan, lanza una excepción con el mensaje.
  Future<List<DebtOption>> loadClients() async {
    final cached = _clients;
    if (cached != null) return cached;
    final result = await searchClients('');
    return result.fold(
      (failure) => throw Exception(failure.message),
      (list) => _clients = list,
    );
  }

  /// Excel con lo que se está viendo.
  Future<Either<Failure, DownloadedFile>> exportAll() async {
    if (_companyId == null) return Either.left(const ValidationFailure('No hay una empresa activa'));
    if (exporting) return Either.left(const ValidationFailure('Ya se está exportando'));
    exporting = true;
    notifyListeners();
    final result = await _exportDebts(filters: _requestFilters);
    exporting = false;
    if (result.isLeft) _isExpired(result.left);
    notifyListeners();
    return result.fold(
      Either<Failure, DownloadedFile>.left,
      (Uint8List bytes) => Either.right(DownloadedFile(name: 'Deudas Pendientes.xlsx', bytes: bytes)),
    );
  }
}
