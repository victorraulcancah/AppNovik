import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../../core/errors/failures.dart';
import '../../core/utils/either.dart';
import '../../domain/entities/account_statement_entity.dart';
import '../../domain/entities/document_entity.dart' show DownloadedFile;
import '../../domain/entities/sale_entity.dart' show ClientEntity;
import '../../domain/entities/session_context_entity.dart';
import '../../domain/usecases/account_statement_usecases.dart';

/// Lo cargado de una pestaña: sus filas, el total y si falta cargar más.
class StatementList {
  List<StatementRowEntity> rows = [];
  int total = 0;
  int page = 0;
  bool loading = false;
  bool loadingMore = false;
  String? error;

  /// Ya se pidió con la consulta actual (para no repetirlo al volver a la pestaña).
  bool loaded = false;
  int request = 0;

  bool get hasMore => rows.length < total;

  void reset() {
    rows = [];
    total = 0;
    page = 0;
    loading = false;
    loadingMore = false;
    error = null;
    loaded = false;
    request++;
  }
}

/// Estado del módulo Estado de cuenta: el cliente, el rango de fechas, la pestaña (Estado de
/// Cuenta, Pedidos o Pagos), el modo agrupado, la búsqueda de producto y las exportaciones.
///
/// Igual que la web, al cambiar de cliente o de fechas se vacía todo (cabecera incluida) y se pide
/// de nuevo; la cabecera llega con la pestaña principal, que siempre se pide primero.
class AccountStatementProvider extends ChangeNotifier {
  static const pageSize = 30;

  final SearchStatementClientsUseCase _searchClients;
  final GetStatementUseCase _getStatement;
  final GetStatementOrdersUseCase _getOrders;
  final GetStatementPaymentsUseCase _getPayments;
  final ExportStatementExcelUseCase _exportExcel;
  final ExportStatementPdfUseCase _exportPdf;

  /// Se llama cuando el backend responde 401 (token vencido).
  final VoidCallback? _onSessionExpired;

  /// Hora actual; se puede reemplazar en pruebas.
  final DateTime Function() _now;

  AccountStatementProvider({
    required SearchStatementClientsUseCase searchClientsUseCase,
    required GetStatementUseCase getStatementUseCase,
    required GetStatementOrdersUseCase getOrdersUseCase,
    required GetStatementPaymentsUseCase getPaymentsUseCase,
    required ExportStatementExcelUseCase exportExcelUseCase,
    required ExportStatementPdfUseCase exportPdfUseCase,
    VoidCallback? onSessionExpired,
    DateTime Function()? now,
  })  : _searchClients = searchClientsUseCase,
        _getStatement = getStatementUseCase,
        _getOrders = getOrdersUseCase,
        _getPayments = getPaymentsUseCase,
        _exportExcel = exportExcelUseCase,
        _exportPdf = exportPdfUseCase,
        _onSessionExpired = onSessionExpired,
        _now = now ?? DateTime.now;

  int? _companyId;

  ClientEntity? client;
  StatementRange range = StatementRange.esteMes;
  ({DateTime start, DateTime end})? _custom;
  StatementTab tab = StatementTab.estadoDeCuenta;

  /// Vista agrupada por venta (una fila por venta, sin productos).
  bool agrupado = false;

  /// Lo escrito en el buscador de producto (solo en la vista por producto).
  String search = '';

  StatementSummaryEntity? summary;
  bool exporting = false;

  final Map<StatementTab, StatementList> lists = {
    for (final t in StatementTab.values) t: StatementList(),
  };

  StatementList get current => lists[tab]!;

  ({DateTime start, DateTime end}) get dates => range.datesFor(_now(), custom: _custom);

  /// Hay cliente elegido: sin él no se consulta nada.
  bool get hasClient => client != null;

  /// La cabecera de un cliente elegido que todavía no llegó (la web muestra un indicador).
  bool get summaryLoading => hasClient && summary == null && lists[StatementTab.estadoDeCuenta]!.error == null;

  StatementQuery? get _query {
    final c = client;
    if (c == null) return null;
    final d = dates;
    return StatementQuery(
      clientId: c.id,
      from: d.start,
      to: d.end,
      agrupado: agrupado,
      search: search,
    );
  }

  /// Se llama cuando cambia la sesión. Al cambiar de empresa se descarta todo. No notifica: corre
  /// mientras se arma el árbol de widgets.
  void syncSession(SessionContextEntity? session) {
    final companyId = session?.company.id;
    if (companyId == _companyId) return;
    _companyId = companyId;
    client = null;
    range = StatementRange.esteMes;
    _custom = null;
    tab = StatementTab.estadoDeCuenta;
    agrupado = false;
    search = '';
    summary = null;
    exporting = false;
    for (final l in lists.values) {
      l.reset();
    }
  }

  bool _isExpired(Failure failure) {
    if (failure is AuthenticationFailure) {
      _onSessionExpired?.call();
      return true;
    }
    return false;
  }

  void _resetAll() {
    summary = null;
    for (final l in lists.values) {
      l.reset();
    }
  }

  /// Clientes para elegir (la lista de la web: solo los propios sin el permiso de ver los de
  /// otros vendedores; lo decide el servidor).
  Future<Either<Failure, List<ClientEntity>>> searchClients(String text) async {
    final companyId = _companyId;
    if (companyId == null) return Either.right(const []);
    final result = await _searchClients(companyId, text);
    if (result.isLeft) _isExpired(result.left);
    return result;
  }

  Future<void> selectClient(ClientEntity? value) {
    client = value;
    _resetAll();
    notifyListeners();
    return _loadMain();
  }

  Future<void> selectRange(StatementRange value) {
    range = value;
    return _queryChanged();
  }

  Future<void> selectCustom(({DateTime start, DateTime end}) value) {
    _custom = value;
    range = StatementRange.personalizado;
    return _queryChanged();
  }

  Future<void> _queryChanged() {
    _resetAll();
    notifyListeners();
    return _loadMain();
  }

  Future<void> setAgrupado(bool value) {
    if (agrupado == value) return Future.value();
    agrupado = value;
    final main = lists[StatementTab.estadoDeCuenta]!;
    main.reset();
    notifyListeners();
    return _loadMain();
  }

  Future<void> setSearch(String text) {
    final value = text.trim();
    if (value == search) return Future.value();
    search = value;
    final main = lists[StatementTab.estadoDeCuenta]!;
    main.reset();
    notifyListeners();
    return _loadMain();
  }

  /// Cambia de pestaña; la que todavía no se pidió con esta consulta se pide ahora.
  Future<void> selectTab(StatementTab value) {
    tab = value;
    notifyListeners();
    return ensureLoaded();
  }

  /// Pide la pestaña actual si hay cliente y todavía no se pidió.
  Future<void> ensureLoaded() async {
    final list = current;
    if (!hasClient || list.loaded || list.loading) return;
    await _fetch(tab, page: 1);
  }

  Future<void> refresh() async {
    if (!hasClient) return;
    // Al refrescar la principal también se renueva la cabecera.
    await _fetch(tab, page: 1);
  }

  Future<void> loadMore() async {
    final list = current;
    if (list.loading || list.loadingMore || !list.hasMore) return;
    await _fetch(tab, page: list.page + 1);
  }

  /// La pestaña principal va primero (trae la cabecera) y siempre.
  Future<void> _loadMain() async {
    if (!hasClient) return;
    await _fetch(StatementTab.estadoDeCuenta, page: 1);
    // Si se estaba en otra pestaña, también se pide de nuevo.
    if (tab != StatementTab.estadoDeCuenta) await ensureLoaded();
  }

  Future<void> _fetch(StatementTab target, {required int page}) async {
    final query = _query;
    if (query == null) return;
    final list = lists[target]!;
    final request = ++list.request;
    final clientId = query.clientId;
    if (page == 1) {
      list.loading = true;
      list.error = null;
    } else {
      list.loadingMore = true;
    }
    notifyListeners();

    final result = switch (target) {
      StatementTab.estadoDeCuenta => await _getStatement(query, page: page, pageSize: pageSize),
      StatementTab.pedidos => await _getOrders(query, page: page, pageSize: pageSize),
      StatementTab.pagos => await _getPayments(query, page: page, pageSize: pageSize),
    };

    // Una respuesta tardía de otro cliente, otras fechas u otra consulta se descarta.
    if (request != list.request || client?.id != clientId) return;
    list.loading = false;
    list.loadingMore = false;
    result.fold(
      (failure) {
        if (_isExpired(failure)) return;
        list.error = failure.message;
        if (page == 1) {
          list.rows = [];
          list.total = 0;
        }
      },
      (data) {
        list.loaded = true;
        list.page = page;
        list.total = data.total;
        list.rows = page == 1 ? data.rows : [...list.rows, ...data.rows];
        if (target == StatementTab.estadoDeCuenta && data.summary != null) summary = data.summary;
      },
    );
    notifyListeners();
  }

  String get _clientFileName => client?.name ?? '';

  /// El Excel de la pestaña actual (con el nombre del cliente en el archivo).
  Future<Either<Failure, DownloadedFile>> exportExcel() async {
    final query = _query;
    if (query == null || exporting) return Either.left(const ValidationFailure('Elige un cliente'));
    exporting = true;
    notifyListeners();
    final result = await _exportExcel(tab, query);
    exporting = false;
    notifyListeners();
    if (result.isLeft) {
      _isExpired(result.left);
      return result;
    }
    return Either.right(DownloadedFile(name: '${tab.fileName} - $_clientFileName.xlsx', bytes: result.right.bytes));
  }

  /// El PDF del estado de cuenta; el servidor lo arma con las fechas y el modo agrupado.
  Future<Either<Failure, Uint8List>> exportPdf() async {
    final query = _query;
    if (query == null || exporting) return Either.left(const ValidationFailure('Elige un cliente'));
    exporting = true;
    notifyListeners();
    final result = await _exportPdf(query);
    exporting = false;
    notifyListeners();
    if (result.isLeft) _isExpired(result.left);
    return result;
  }

  /// Nombre del archivo del PDF.
  String get pdfFileName => 'Estado de cuenta - $_clientFileName.pdf';
}
