import 'package:flutter/material.dart';

import '../../core/errors/failures.dart';
import '../../core/utils/either.dart';
import '../../domain/entities/document_entity.dart';
import '../../domain/entities/report_entity.dart';
import '../../domain/entities/session_context_entity.dart';
import '../../domain/usecases/report_usecases.dart';

/// Rangos de fechas del reporte: los mismos atajos que la web. `esteMes` es el predeterminado.
enum ReportRange {
  ultimaSemana('Última semana'),
  estaSemana('Esta semana'),
  ultimoMes('Último mes'),
  esteMes('Este mes'),
  ultimoAnio('Último año'),
  esteAnio('Este año'),
  personalizado('Elegir fechas');

  final String label;
  const ReportRange(this.label);
}

/// Campos por los que se ordenan los productos del reporte (`sortField` de la API).
enum ReportSort {
  venta('Venta total'),
  cantidad('Cantidad'),
  subtotal('Subtotal'),
  descuento('Descuento');

  final String label;
  const ReportSort(this.label);
}

/// Estado del reporte Ventas General: el rango y los filtros, las cifras, la gráfica, los
/// productos (paginados) y, si se pide, lo mismo del año anterior para compararlo.
class ReportsProvider extends ChangeNotifier {
  static const pageSize = 15;

  final GetSalesReportUseCase _getReport;
  final ExportSalesReportUseCase _export;
  final GetReportCatalogsUseCase _getCatalogs;
  final GetReportSaleUseCase _getSale;

  /// Se llama cuando el backend responde 401 (token vencido).
  final VoidCallback? _onSessionExpired;

  /// Hora actual; se puede reemplazar en pruebas.
  final DateTime Function() _now;

  ReportsProvider({
    required GetSalesReportUseCase getSalesReportUseCase,
    required ExportSalesReportUseCase exportSalesReportUseCase,
    required GetReportCatalogsUseCase getCatalogsUseCase,
    required GetReportSaleUseCase getSaleUseCase,
    VoidCallback? onSessionExpired,
    DateTime Function()? now,
  }) : _getReport = getSalesReportUseCase,
       _export = exportSalesReportUseCase,
       _getCatalogs = getCatalogsUseCase,
       _getSale = getSaleUseCase,
       _onSessionExpired = onSessionExpired,
       _now = now ?? DateTime.now;

  int? _companyId;
  int? _userId;
  Set<String> _roles = {};
  Set<String> _permissions = {};
  int _request = 0;
  bool _loadedOnce = false;

  /// Última página de productos pedida.
  int _page = 1;

  /// IGV y renta de la empresa (fracciones), para el margen neto.
  double igv = 0;
  double renta = 0;

  ReportRange range = ReportRange.esteMes;
  DateTimeRange? _custom;
  SalesReportFilters _advanced = SalesReportFilters(
    desde: DateTime(2000),
    hasta: DateTime(2000),
  );

  ReportSort sort = ReportSort.venta;
  bool sortDescending = true;
  bool compare = false;

  SalesReportEntity? report;
  SalesReportEntity? previous;
  bool loading = false;
  bool loadingMore = false;
  String? error;

  SalesReportCatalogs catalogs = const SalesReportCatalogs();
  bool catalogsLoaded = false;
  bool catalogsLoading = false;
  String? catalogsError;

  bool exporting = false;

  bool _hasRole(String role) => _roles.contains(role.toLowerCase());

  /// El Jefe de Almacén ve movimiento (qué salió y cuánto), no importes ni margen.
  bool get ocultarImportes => _hasRole('jefe de almacén');

  /// El margen solo lo ve el CEO; el Jefe de Almacén, el Vendedor y el Jefe Comercial no.
  bool get ocultarMargen =>
      !_hasRole('ceo empresa') &&
      (_hasRole('jefe de almacén') ||
          _hasRole('vendedor') ||
          _hasRole('jefe comercial'));

  /// Un Vendedor sin permiso para ver a los demás solo trabaja con lo suyo.
  bool get soloMiCartera =>
      _hasRole('vendedor') &&
      !_permissions.contains('reportes.ventas.ver-otros-vendedores');

  DateTime get now => _now();

  /// Primer y último día del rango elegido.
  DateTimeRange get dates {
    final today = DateUtils.dateOnly(_now());
    final monday = today.subtract(Duration(days: today.weekday - 1));
    return switch (range) {
      ReportRange.ultimaSemana => DateTimeRange(
        start: monday.subtract(const Duration(days: 7)),
        end: monday.subtract(const Duration(days: 1)),
      ),
      ReportRange.estaSemana => DateTimeRange(start: monday, end: today),
      ReportRange.ultimoMes => DateTimeRange(
        start: DateTime(today.year, today.month - 1),
        end: DateTime(today.year, today.month, 0),
      ),
      ReportRange.esteMes => DateTimeRange(
        start: DateTime(today.year, today.month),
        end: today,
      ),
      ReportRange.ultimoAnio => DateTimeRange(
        start: DateTime(today.year - 1),
        end: DateTime(today.year - 1, 12, 31),
      ),
      ReportRange.esteAnio => DateTimeRange(
        start: DateTime(today.year),
        end: today,
      ),
      ReportRange.personalizado =>
        _custom ?? DateTimeRange(start: today, end: today),
    };
  }

  /// Los filtros que se mandan al servidor: el rango más los avanzados.
  SalesReportFilters get filters {
    final r = dates;
    return _advanced.copyWith(desde: r.start, hasta: r.end);
  }

  int get advancedCount => _advanced.advancedCount;

  bool get hasMore =>
      report != null && report!.products.length < report!.totalProducts;

  /// Se llama cuando cambia la sesión. Al cambiar de empresa o de usuario se descarta todo. No
  /// notifica: corre mientras se construye el árbol de widgets.
  void syncSession(SessionContextEntity? session) {
    _roles = {
      for (final r in session?.roles ?? const <String>[]) r.toLowerCase(),
    };
    _permissions = session?.permissions ?? {};
    igv = session?.company.igv ?? 0;
    renta = session?.company.renta ?? 0;

    final companyId = session?.company.id;
    final userId = session?.user.id;
    if (companyId == _companyId && userId == _userId) return;
    _companyId = companyId;
    _userId = userId;
    _request++;
    _loadedOnce = false;
    range = ReportRange.esteMes;
    _custom = null;
    _advanced = SalesReportFilters(
      desde: DateTime(2000),
      hasta: DateTime(2000),
    );
    sort = ReportSort.venta;
    sortDescending = true;
    compare = false;
    report = null;
    previous = null;
    loading = false;
    loadingMore = false;
    error = null;
    catalogs = const SalesReportCatalogs();
    catalogsLoaded = false;
    catalogsLoading = false;
    catalogsError = null;
  }

  Future<void> ensureLoaded() async {
    if (_companyId == null || _loadedOnce || loading) return;
    await refresh();
  }

  Future<void> selectRange(ReportRange value) {
    range = value;
    return refresh();
  }

  Future<void> selectCustom(DateTimeRange value) {
    _custom = value;
    range = ReportRange.personalizado;
    return refresh();
  }

  /// Aplica el rango y los filtros avanzados elegidos en el panel de filtros.
  Future<void> applyFilters(SalesReportFilters value) {
    _advanced = value;
    final isSameRange = value.desde == dates.start && value.hasta == dates.end;
    if (!isSameRange) {
      _custom = DateTimeRange(start: value.desde, end: value.hasta);
      range = ReportRange.personalizado;
    }
    return refresh();
  }

  Future<void> clearAdvancedFilters() {
    _advanced = SalesReportFilters(
      desde: DateTime(2000),
      hasta: DateTime(2000),
    );
    return refresh();
  }

  Future<void> setCompare(bool value) {
    compare = value;
    if (!value) {
      previous = null;
      notifyListeners();
      return Future.value();
    }
    return _loadPrevious();
  }

  /// Ordena por [value]; si ya estaba, invierte el sentido.
  Future<void> selectSort(ReportSort value) {
    if (sort == value) {
      sortDescending = !sortDescending;
    } else {
      sort = value;
      sortDescending = true;
    }
    return refresh();
  }

  Future<void> refresh() async {
    if (_companyId == null) return;
    final request = ++_request;
    loading = true;
    loadingMore = false;
    error = null;
    notifyListeners();

    final result = await _getReport(
      filters: filters,
      page: 1,
      pageSize: pageSize,
      sortField: sort.name,
      sortDescending: sortDescending,
    );
    // Llegó tarde: ya se pidió otro rango o cambió la empresa.
    if (request != _request) return;

    result.fold(
      (failure) {
        report = null;
        error = failure.message;
        if (failure is AuthenticationFailure) _onSessionExpired?.call();
      },
      (data) {
        report = data;
        _page = 1;
      },
    );
    _loadedOnce = true;
    loading = false;
    notifyListeners();

    if (compare && report != null) await _loadPrevious(request: request);
  }

  Future<void> _loadPrevious({int? request}) async {
    final current = request ?? _request;
    final result = await _getReport(
      filters: filters.yearBefore,
      page: 1,
      pageSize: 50,
    );
    if (current != _request || !compare) return;
    result.fold((failure) {
      if (failure is AuthenticationFailure) _onSessionExpired?.call();
      previous = null;
    }, (data) => previous = data);
    notifyListeners();
  }

  Future<void> loadMore() async {
    final current = report;
    if (current == null || loading || loadingMore || !hasMore) return;

    final request = _request;
    loadingMore = true;
    notifyListeners();

    final nextPage = _page + 1;
    final result = await _getReport(
      filters: filters,
      page: nextPage,
      pageSize: pageSize,
      sortField: sort.name,
      sortDescending: sortDescending,
    );
    if (request != _request) return;

    loadingMore = false;
    result.fold(
      (failure) {
        error = failure.message;
        if (failure is AuthenticationFailure) _onSessionExpired?.call();
      },
      (data) {
        _page = nextPage;
        report = SalesReportEntity(
          days: current.days,
          documents: current.documents,
          products: [...current.products, ...data.products],
          totalProducts: data.totalProducts,
          countVentas: current.countVentas,
          unidades: current.unidades,
          totalVentas: current.totalVentas,
          totalCostos: current.totalCostos,
        );
      },
    );
    notifyListeners();
  }

  /// Pide los catálogos de los filtros avanzados la primera vez que se abre el panel.
  Future<void> ensureCatalogs() async {
    final companyId = _companyId;
    final userId = _userId;
    if (companyId == null ||
        userId == null ||
        catalogsLoaded ||
        catalogsLoading)
      return;

    catalogsLoading = true;
    catalogsError = null;
    notifyListeners();

    final result = await _getCatalogs(
      companyId: companyId,
      userId: userId,
      soloMiCartera: soloMiCartera,
    );
    if (companyId != _companyId) return;

    catalogsLoading = false;
    result.fold(
      (failure) {
        catalogsError = failure.message;
        if (failure is AuthenticationFailure) _onSessionExpired?.call();
      },
      (data) {
        catalogs = data;
        catalogsLoaded = true;
      },
    );
    notifyListeners();
  }

  /// Excel del reporte con lo que se ve.
  Future<Either<Failure, DownloadedFile>> exportCurrent() async {
    if (exporting)
      return Either.left(const ValidationFailure('Ya se está exportando'));
    exporting = true;
    notifyListeners();
    final result = await _export(filters);
    exporting = false;
    if (result.isLeft && result.left is AuthenticationFailure)
      _onSessionExpired?.call();
    notifyListeners();
    return result;
  }

  /// Una venta completa, para abrir su comprobante.
  Future<Either<Failure, DocumentEntity>> loadSale(int id) async {
    final result = await _getSale(id);
    if (result.isLeft && result.left is AuthenticationFailure)
      _onSessionExpired?.call();
    return result;
  }
}
