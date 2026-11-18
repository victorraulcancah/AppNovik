import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../../core/errors/failures.dart';
import '../../core/utils/either.dart';
import '../../domain/entities/document_entity.dart' show DownloadedFile;
import '../../domain/entities/seller_payment_entity.dart';
import '../../domain/entities/session_context_entity.dart';
import '../../domain/usecases/seller_payment_usecases.dart';

/// Estado del módulo Pagos vendedores ("Registro de Pagos" de la web): los pagos de los clientes
/// registrados por los ejecutivos, con búsqueda por términos, filtros avanzados (fechas, cliente,
/// ejecutivo, monto, método y estado), totales en soles y dólares, paginación y Excel; y las
/// acciones sobre un pago: registrar, editar, aprobar y eliminar. Los permisos son los de la web
/// (`pagos-vendedores.*`).
class SellerPaymentsProvider extends ChangeNotifier {
  static const pageSize = 50;

  final GetSellerPaymentsUseCase _getPayments;
  final ExportSellerPaymentsUseCase _exportPayments;
  final GetSellerPaymentMethodsUseCase _getMethods;
  final GetSellerPaymentClientsUseCase _getClients;
  final GetSellerPaymentSellersUseCase _getSellers;
  final GetSellerClientDebtUseCase _getClientDebt;
  final CreateSellerPaymentUseCase _create;
  final ApproveSellerPaymentUseCase _approve;
  final EditSellerInstallmentPaymentUseCase _editInstallment;
  final EditSellerPaymentUseCase _edit;
  final DeleteSellerPaymentUseCase _delete;

  /// Se llama cuando el backend responde 401 (token vencido).
  final VoidCallback? _onExpired;
  final DateTime Function() _now;

  SellerPaymentsProvider({
    required GetSellerPaymentsUseCase getPaymentsUseCase,
    required ExportSellerPaymentsUseCase exportPaymentsUseCase,
    required GetSellerPaymentMethodsUseCase getMethodsUseCase,
    required GetSellerPaymentClientsUseCase getClientsUseCase,
    required GetSellerPaymentSellersUseCase getSellersUseCase,
    required GetSellerClientDebtUseCase getClientDebtUseCase,
    required CreateSellerPaymentUseCase createUseCase,
    required ApproveSellerPaymentUseCase approveUseCase,
    required EditSellerInstallmentPaymentUseCase editInstallmentUseCase,
    required EditSellerPaymentUseCase editUseCase,
    required DeleteSellerPaymentUseCase deleteUseCase,
    VoidCallback? onSessionExpired,
    DateTime Function()? now,
  })  : _getPayments = getPaymentsUseCase,
        _exportPayments = exportPaymentsUseCase,
        _getMethods = getMethodsUseCase,
        _getClients = getClientsUseCase,
        _getSellers = getSellersUseCase,
        _getClientDebt = getClientDebtUseCase,
        _create = createUseCase,
        _approve = approveUseCase,
        _editInstallment = editInstallmentUseCase,
        _edit = editUseCase,
        _delete = deleteUseCase,
        _onExpired = onSessionExpired,
        _now = now ?? DateTime.now;

  int? _companyId;
  int? _userId;
  Set<String> _permissions = const {};
  int _page = 0;
  int _request = 0;
  List<SellerPaymentOption>? _sellers;
  List<SellerPaymentOption>? _filterClients;
  List<SellerPaymentOption>? _allClients;
  List<SellerPaymentOption>? _methods;

  /// Los nombres de los métodos de pago que ya aparecieron en la lista: sirven para la etiqueta de
  /// un método elegido que ya no aparece en lo filtrado.
  final Map<int, String> _methodNames = {};

  List<SellerPaymentEntity> items = [];
  bool loading = false;
  bool loadingMore = false;
  bool hasMore = false;
  int total = 0;
  double totalSoles = 0;
  double totalDolares = 0;
  String? error;
  bool exporting = false;

  /// Los métodos de pago que aparecen en lo filtrado (los que ofrece el panel de filtros).
  List<SellerPaymentOption> availableMethods = const [];

  /// Los filtros del panel (la búsqueda va aparte).
  late SellerPaymentFilters filters = SellerPaymentFilters.mes(_now());

  /// Los términos de búsqueda ya confirmados (los chips de la web).
  List<String> searchTerms = const [];

  /// Lo que se está escribiendo en el buscador.
  String typing = '';

  DateTime get now => _now();

  /// Lo que se ve al entrar: los pagos del mes.
  SellerPaymentFilters get baseFilters => SellerPaymentFilters.mes(_now());

  /// Cuántos filtros del panel hay puestos distintos de como se entra.
  int get filtersCount => filters.count(baseFilters);

  /// Todos los términos que se mandan: los confirmados y el que se está escribiendo.
  List<String> get terms => [...searchTerms, if (typing.isNotEmpty) typing];

  bool get hasAnyFilter => filtersCount > 0 || terms.isNotEmpty;

  bool can(String permission) => _permissions.contains(permission);

  /// Los permisos de la web (`pagos-vendedores.index`, `.store`, `.update`...).
  bool get canIndex => can('pagos-vendedores.index');
  bool get canStore => can('pagos-vendedores.store');
  bool get canSeeOthers => can('pagos-vendedores.showOthersSellers');
  bool get canApprove => can('pagos-vendedores.confirmarPago');
  bool get canUpdate => can('pagos-vendedores.update');
  bool get canDestroy => can('pagos-vendedores.destroy');
  bool get canPostConfirmUpdate => can('pagos-vendedores.post-confirm.update');
  bool get canPostConfirmDestroy => can('pagos-vendedores.post-confirm.destroy');

  /// Los ejecutivos ya traídos para el filtro (`null` hasta pedirlos).
  List<SellerPaymentOption>? get sellers => _sellers;

  /// Los clientes del filtro ya traídos (`null` hasta pedirlos).
  List<SellerPaymentOption>? get filterClients => _filterClients;

  /// El nombre de un método de pago que ya apareció en la lista.
  String? methodName(int id) => _methodNames[id];

  SellerPaymentFilters get _requestFilters => filters.copyWith(search: terms);

  /// Se llama cuando cambia la sesión. Al cambiar de empresa o de usuario se descarta todo. No
  /// notifica: corre mientras se arma el árbol de widgets.
  void syncSession(SessionContextEntity? session) {
    _permissions = session?.permissions ?? const {};
    final companyId = session?.company.id;
    final userId = session?.user.id;
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
    availableMethods = const [];
    filters = baseFilters;
    searchTerms = const [];
    typing = '';
    _page = 0;
    _request++;
    _sellers = null;
    _filterClients = null;
    _allClients = null;
    _methods = null;
    _methodNames.clear();
  }

  bool _isExpired(Failure failure) {
    if (failure is AuthenticationFailure) {
      _onExpired?.call();
      return true;
    }
    return false;
  }

  Either<Failure, T> _check<T>(Either<Failure, T> result) {
    if (result.isLeft) _isExpired(result.left);
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

  /// Lo que se escribe en el buscador: se busca mientras se escribe (como en las demás listas).
  Future<void> setSearch(String text) {
    typing = text.trim();
    return refresh();
  }

  /// Confirma [text] como un término de búsqueda (un chip, como en la web). Los repetidos y los
  /// vacíos se ignoran.
  Future<void> addSearchTerm(String text) {
    final term = text.trim();
    typing = '';
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

  Future<void> applyFilters(SellerPaymentFilters value) {
    filters = value.copyWith(search: const []);
    return refresh();
  }

  /// "Restablecer": vuelve a los pagos del mes y quita las búsquedas.
  Future<void> resetFilters() {
    filters = baseFilters;
    searchTerms = const [];
    typing = '';
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

    final result = await _getPayments(page: page, pageSize: pageSize, filters: _requestFilters);

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
        availableMethods = data.methods;
        for (final m in data.methods) {
          _methodNames[m.id] = m.name;
        }
        error = null;
      },
    );
    loading = false;
    loadingMore = false;
    notifyListeners();
  }

  /// Los ejecutivos comerciales para el filtro; se piden una vez por empresa. Si fallan, lanza una
  /// excepción con el mensaje.
  Future<List<SellerPaymentOption>> loadSellers() async {
    final cached = _sellers;
    if (cached != null) return cached;
    final companyId = _companyId;
    if (companyId == null) return const [];
    final result = _check(await _getSellers(companyId: companyId));
    return result.fold(
      (failure) => throw Exception(failure.message),
      (list) => _sellers = list,
    );
  }

  /// Los clientes del filtro (con "solo mi cartera", como los catálogos de los reportes de la web);
  /// se piden una vez por empresa. Si fallan, lanza una excepción con el mensaje.
  Future<List<SellerPaymentOption>> loadFilterClients() async {
    final cached = _filterClients;
    if (cached != null) return cached;
    final companyId = _companyId;
    if (companyId == null) return const [];
    final result = _check(await _getClients(companyId: companyId, onlyMine: true));
    return result.fold(
      (failure) => throw Exception(failure.message),
      (list) => _filterClients = list,
    );
  }

  /// Los clientes para registrar un pago (la web los busca sin recortar a la cartera).
  Future<List<SellerPaymentOption>> loadAllClients() async {
    final cached = _allClients;
    if (cached != null) return cached;
    final companyId = _companyId;
    if (companyId == null) return const [];
    final result = _check(await _getClients(companyId: companyId, onlyMine: false));
    return result.fold(
      (failure) => throw Exception(failure.message),
      (list) => _allClients = list,
    );
  }

  /// Los métodos de pago para registrar o editar un pago (sin Crédito, Contraentrega ni Puntos, como
  /// la web). Se piden una vez por empresa.
  Future<List<SellerPaymentOption>> loadPaymentMethods() async {
    final cached = _methods;
    if (cached != null) return cached;
    final result = _check(await _getMethods());
    return result.fold(
      (failure) => throw Exception(failure.message),
      (list) => _methods = [
        for (final m in list)
          if (!_excludedMethods.contains(m.name)) m,
      ],
    );
  }

  static const _excludedMethods = {'CRÉDITO', 'CONTRAENTREGA', 'PUNTOS'};

  /// La deuda del cliente en soles y en dólares. Si falla no cierra la sesión: el modal solo muestra el
  /// mensaje.
  Future<Either<Failure, SellerClientDebt>> loadClientDebt(int clientId) => _getClientDebt(clientId: clientId);

  /// Registra el pago (la fecha, sin hora, toma la hora de ahora, como la web).
  Future<Either<Failure, void>> createPayment({
    required int clientId,
    required String moneda,
    required List<SellerPaymentLine> lines,
    DateTime? date,
  }) async {
    final n = _now();
    final result = _check(
      await _create(
        payment: SellerPaymentCreate(
          clientId: clientId,
          moneda: moneda,
          lines: lines,
          creado: date == null ? null : DateTime(date.year, date.month, date.day, n.hour, n.minute, n.second),
        ),
      ),
    );
    if (result.isRight) await refresh();
    return result;
  }

  /// "Confirmar Pago": aprueba el pago.
  Future<Either<Failure, void>> approvePayment(SellerPaymentEntity payment) async {
    final result = _check(await _approve(id: payment.id));
    if (result.isRight) await refresh();
    return result;
  }

  /// Edita el pago como la web: un saldo a favor, solo método y descripción; si no, la primera parte
  /// aplicada a una cuota (el monto solo mientras no esté confirmada).
  Future<Either<Failure, void>> editPayment(
    SellerPaymentEntity payment, {
    required int paymentMethodId,
    double? monto,
    String? descripcion,
  }) async {
    final allocation = payment.editAllocation;
    final Either<Failure, void> result;
    if (allocation == null) {
      result = await _edit(id: payment.id, paymentMethodId: paymentMethodId, descripcion: descripcion);
    } else {
      result = await _editInstallment(
        id: allocation.id,
        paymentMethodId: paymentMethodId,
        monto: allocation.confirmed ? null : monto,
        descripcionAdicional: descripcion,
      );
    }
    _check(result);
    if (result.isRight) await refresh();
    return result;
  }

  /// Elimina el pago: uno confirmado por su propia ruta (queda a la vista, marcado como eliminado).
  Future<Either<Failure, void>> deletePayment(SellerPaymentEntity payment) async {
    final result = _check(
      await _delete(id: payment.id, afterConfirm: payment.status == SellerPaymentStatus.aprobado),
    );
    if (result.isRight) await refresh();
    return result;
  }

  /// Excel con lo que se está viendo (la búsqueda y los filtros).
  Future<Either<Failure, DownloadedFile>> exportAll() async {
    if (_companyId == null) return Either.left(const ValidationFailure('No hay una empresa activa'));
    if (exporting) return Either.left(const ValidationFailure('Ya se está exportando'));
    exporting = true;
    notifyListeners();
    final result = await _exportPayments(filters: _requestFilters);
    exporting = false;
    if (result.isLeft) _isExpired(result.left);
    notifyListeners();
    return result.fold(
      Either<Failure, DownloadedFile>.left,
      (Uint8List bytes) => Either.right(DownloadedFile(name: 'Registro de Pagos de Vendedores.xlsx', bytes: bytes)),
    );
  }
}
