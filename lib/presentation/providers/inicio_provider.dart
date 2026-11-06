import 'package:flutter/material.dart';

import '../../core/errors/failures.dart';
import '../../domain/entities/inicio_entity.dart';
import '../../domain/entities/session_context_entity.dart';
import '../../domain/usecases/inicio_usecases.dart';
import 'reports_provider.dart' show ReportRange;

/// Las vistas del Inicio. `ceo`, `jefe` y `ejecutivo` son los resúmenes por rol (el switch de la
/// web "CEO | Jefe | Ejecutivo"); `general` es la pantalla de siempre: el resumen de ventas del mes
/// por almacén.
enum InicioView {
  ceo('CEO'),
  jefe('Jefe'),
  ejecutivo('Ejecutivo'),
  general('General');

  final String label;
  const InicioView(this.label);
}

/// Estado del módulo Inicio: qué vista toca según los roles del usuario, el rango (y el almacén en
/// la vista CEO) y los datos de cada resumen.
class InicioProvider extends ChangeNotifier {
  final GetWarehouseSalesUseCase _getWarehouseSales;
  final GetExecutiveSummaryUseCase _getExecutive;
  final GetTeamSummaryUseCase _getTeam;
  final GetCeoSummaryUseCase _getCeo;

  /// Se llama cuando el backend responde 401 (token vencido).
  final VoidCallback? _onSessionExpired;

  /// Hora actual; se puede reemplazar en pruebas.
  final DateTime Function() _now;

  InicioProvider({
    required GetWarehouseSalesUseCase getWarehouseSalesUseCase,
    required GetExecutiveSummaryUseCase getExecutiveSummaryUseCase,
    required GetTeamSummaryUseCase getTeamSummaryUseCase,
    required GetCeoSummaryUseCase getCeoSummaryUseCase,
    VoidCallback? onSessionExpired,
    DateTime Function()? now,
  }) : _getWarehouseSales = getWarehouseSalesUseCase,
       _getExecutive = getExecutiveSummaryUseCase,
       _getTeam = getTeamSummaryUseCase,
       _getCeo = getCeoSummaryUseCase,
       _onSessionExpired = onSessionExpired,
       _now = now ?? DateTime.now;

  int? _companyId;
  int? _userId;
  Set<String> _roles = {};
  int _request = 0;

  /// Vistas cuyos datos ya no corresponden al rango o al almacén elegidos (hay que volver a pedirlos).
  final Set<InicioView> _stale = {...InicioView.values};

  InicioView? _selected;

  ReportRange range = ReportRange.esteMes;
  DateTimeRange? _custom;

  /// Almacén elegido en la vista CEO (`null`: todos).
  int? sucursal;

  List<WarehouseSalesEntity>? warehouses;
  ExecutiveSummaryEntity? executive;
  TeamSummaryEntity? team;
  CeoSummaryEntity? ceo;

  bool loading = false;
  String? error;

  bool _hasRole(String role) => _roles.contains(role.toLowerCase());

  DateTime get now => _now();

  /// Las vistas que el usuario puede ver, del cargo más alto al más bajo (en ese orden se
  /// muestran). Sin ninguna de esas (y para el Jefe de Almacén, que no ve importes), la pantalla
  /// general.
  List<InicioView> get views {
    if (_hasRole('jefe de almacén')) return const [InicioView.general];
    final result = [
      if (_hasRole('ceo empresa')) InicioView.ceo,
      if (_hasRole('jefe comercial')) InicioView.jefe,
      if (_hasRole('vendedor')) InicioView.ejecutivo,
    ];
    return result.isEmpty ? const [InicioView.general] : result;
  }

  /// La vista elegida; si no se eligió ninguna (o ya no está disponible), la del cargo más alto.
  InicioView get view {
    final options = views;
    final chosen = _selected;
    return chosen != null && options.contains(chosen) ? chosen : options.first;
  }

  /// Hay que elegir entre varios perfiles (el switch de la web).
  bool get hasSwitch => views.length > 1;

  /// El rango no aplica a la pantalla general: siempre es el mes en curso.
  bool get usesRange => view != InicioView.general;

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
      ReportRange.esteMes => DateTimeRange(start: DateTime(today.year, today.month), end: today),
      ReportRange.ultimoAnio => DateTimeRange(start: DateTime(today.year - 1), end: DateTime(today.year - 1, 12, 31)),
      ReportRange.esteAnio => DateTimeRange(start: DateTime(today.year), end: today),
      ReportRange.personalizado => _custom ?? DateTimeRange(start: today, end: today),
    };
  }

  /// Se llama cuando cambia la sesión. Al cambiar de empresa o de usuario se descarta todo. No
  /// notifica: corre mientras se construye el árbol de widgets.
  void syncSession(SessionContextEntity? session) {
    _roles = {for (final r in session?.roles ?? const <String>[]) r.toLowerCase()};

    final companyId = session?.company.id;
    final userId = session?.user.id;
    if (companyId == _companyId && userId == _userId) return;
    _companyId = companyId;
    _userId = userId;
    _request++;
    _stale
      ..clear()
      ..addAll(InicioView.values);
    _selected = null;
    range = ReportRange.esteMes;
    _custom = null;
    sucursal = null;
    warehouses = null;
    executive = null;
    team = null;
    ceo = null;
    loading = false;
    error = null;
  }

  /// Carga la vista de la pantalla si aún no tiene datos al día.
  Future<void> ensureLoaded() async {
    if (_companyId == null || loading) return;
    if (!_stale.contains(view) && _hasData(view)) return;
    await refresh();
  }

  bool _hasData(InicioView v) => switch (v) {
    InicioView.general => warehouses != null,
    InicioView.ejecutivo => executive != null,
    InicioView.jefe => team != null,
    InicioView.ceo => ceo != null,
  };

  Future<void> selectView(InicioView value) {
    if (!views.contains(value)) return Future.value();
    _selected = value;
    error = null;
    notifyListeners();
    return ensureLoaded();
  }

  Future<void> selectRange(ReportRange value) {
    range = value;
    return _rangeChanged();
  }

  Future<void> selectCustom(DateTimeRange value) {
    _custom = value;
    range = ReportRange.personalizado;
    return _rangeChanged();
  }

  Future<void> selectSucursal(int? value) {
    sucursal = value;
    _stale.add(InicioView.ceo);
    return refresh();
  }

  Future<void> _rangeChanged() {
    _stale.addAll([InicioView.ejecutivo, InicioView.jefe, InicioView.ceo]);
    return refresh();
  }

  /// Vuelve a pedir la vista de la pantalla.
  Future<void> refresh() async {
    if (_companyId == null) return;
    final current = view;
    final request = ++_request;
    loading = true;
    error = null;
    notifyListeners();

    final r = dates;
    Failure? failure;
    switch (current) {
      case InicioView.general:
        final result = await _getWarehouseSales();
        if (request != _request) return;
        result.fold<void>((f) => failure = f, (data) => warehouses = data);
      case InicioView.ejecutivo:
        final result = await _getExecutive(r.start, r.end);
        if (request != _request) return;
        result.fold<void>((f) => failure = f, (data) => executive = data);
      case InicioView.jefe:
        final result = await _getTeam(r.start, r.end);
        if (request != _request) return;
        result.fold<void>((f) => failure = f, (data) => team = data);
      case InicioView.ceo:
        final result = await _getCeo(r.start, r.end, sucursal: sucursal);
        if (request != _request) return;
        result.fold<void>((f) => failure = f, (data) => ceo = data);
    }

    if (failure != null) {
      error = failure!.message;
      if (failure is AuthenticationFailure) _onSessionExpired?.call();
    } else {
      _stale.remove(current);
    }
    loading = false;
    notifyListeners();
  }
}
