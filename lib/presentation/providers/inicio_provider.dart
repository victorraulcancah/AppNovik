import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/errors/failures.dart';
import '../../core/utils/either.dart';
import '../../domain/entities/inicio_entity.dart';
import '../../domain/entities/session_context_entity.dart';
import '../../domain/entities/user_entity.dart';
import '../../domain/usecases/inicio_cache_usecases.dart';
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

/// Lo que respondió el servidor para una vista: o falló, o trae sus datos.
typedef _Outcome = ({Failure? failure, Object? data});

/// Un pedido de datos adelantado: se lanzó con los roles y la empresa del login, antes de que `/auth`
/// terminara. Si al llegar la sesión coincide con lo que realmente toca, se reutiliza en vez de pedir
/// de nuevo.
class _Prefetch {
  final int userId;
  final int companyId;
  final InicioView view;
  final DateTime desde;
  final DateTime hasta;
  final DateTime startedAt;
  final Future<_Outcome> future;

  _Prefetch({
    required this.userId,
    required this.companyId,
    required this.view,
    required this.desde,
    required this.hasta,
    required this.startedAt,
    required this.future,
  });
}

/// Estado del módulo Inicio: qué vista toca según los roles del usuario, el rango (y el almacén en
/// la vista CEO) y los datos de cada resumen.
///
/// Para que se vea rápido al entrar:
/// - [prefetch] pide los datos apenas el login devuelve los roles, en paralelo con `/auth`;
/// - con lo último que se vio guardado (ver [InicioCacheRepository]) se muestra al instante mientras
///   llega lo nuevo ([showingCache]).
class InicioProvider extends ChangeNotifier {
  final GetWarehouseSalesUseCase _getWarehouseSales;
  final GetExecutiveSummaryUseCase _getExecutive;
  final GetTeamSummaryUseCase _getTeam;
  final GetCeoSummaryUseCase _getCeo;

  /// Lo último que se vio de cada vista; sin esto no hay adelanto desde el disco.
  final GetCachedInicioUseCase? _readCache;
  final ClearInicioCacheUseCase? _clearCache;

  /// Se llama cuando el backend responde 401 (token vencido).
  final VoidCallback? _onSessionExpired;

  /// Hora actual; se puede reemplazar en pruebas.
  final DateTime Function() _now;

  InicioProvider({
    required GetWarehouseSalesUseCase getWarehouseSalesUseCase,
    required GetExecutiveSummaryUseCase getExecutiveSummaryUseCase,
    required GetTeamSummaryUseCase getTeamSummaryUseCase,
    required GetCeoSummaryUseCase getCeoSummaryUseCase,
    GetCachedInicioUseCase? getCachedInicioUseCase,
    ClearInicioCacheUseCase? clearInicioCacheUseCase,
    VoidCallback? onSessionExpired,
    DateTime Function()? now,
  }) : _getWarehouseSales = getWarehouseSalesUseCase,
       _getExecutive = getExecutiveSummaryUseCase,
       _getTeam = getTeamSummaryUseCase,
       _getCeo = getCeoSummaryUseCase,
       _readCache = getCachedInicioUseCase,
       _clearCache = clearInicioCacheUseCase,
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

  _Prefetch? _prefetch;

  /// Vistas cuyo primer dibujo vino de lo guardado: sus cifras no deben contar desde cero.
  final Set<InicioView> _cachedFirst = {};
  bool _displayingCache = false;

  /// Lo que se ve ahora son los últimos datos guardados y se está pidiendo lo nuevo (o no se pudo).
  bool get showingCache => _displayingCache && _hasData(view);

  /// Las cifras cuentan desde cero solo cuando el dato llegó recién del servidor; si ya había uno
  /// guardado a la vista, pasan del valor viejo al nuevo.
  bool get animateFromZero => !_cachedFirst.contains(view);

  DateTime get now => _now();

  /// Las vistas que el usuario puede ver, del cargo más alto al más bajo (en ese orden se
  /// muestran). Sin ninguna de esas (y para el Jefe de Almacén, que no ve importes), la pantalla
  /// general.
  List<InicioView> get views => _viewsFor(_roles);

  /// [roles] va en minúsculas.
  static List<InicioView> _viewsFor(Set<String> roles) {
    if (roles.contains('jefe de almacén')) return const [InicioView.general];
    final result = [
      if (roles.contains('ceo empresa')) InicioView.ceo,
      if (roles.contains('jefe comercial')) InicioView.jefe,
      if (roles.contains('vendedor')) InicioView.ejecutivo,
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

  DateTimeRange get dates => _datesFor(range, _custom);

  DateTimeRange _datesFor(ReportRange range, DateTimeRange? custom) {
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
      ReportRange.personalizado => custom ?? DateTimeRange(start: today, end: today),
    };
  }

  /// Se llama cuando cambia la sesión. Al cambiar de empresa o de usuario se descarta todo. No
  /// notifica: corre mientras se construye el árbol de widgets.
  void syncSession(SessionContextEntity? session) {
    _roles = {for (final r in session?.roles ?? const <String>[]) r.toLowerCase()};

    final companyId = session?.company.id;
    final userId = session?.user.id;
    if (companyId == _companyId && userId == _userId) return;

    // Al cerrar sesión o cambiar de usuario o empresa se borra lo guardado: nada de una cuenta
    // debe quedar a la vista de otra.
    if (_companyId != null) {
      final clear = _clearCache;
      if (clear != null) unawaited(clear().catchError((Object _) {}));
    }

    _companyId = companyId;
    _userId = userId;
    // Un pedido adelantado de otra cuenta no sirve.
    final early = _prefetch;
    if (early != null && (early.userId != userId || early.companyId != companyId)) _prefetch = null;
    _request++;
    _cachedFirst.clear();
    _displayingCache = false;
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

  /// Adelanta el pedido de la vista de arranque con los roles y la empresa que dio el login, mientras
  /// `/auth` todavía responde. Cuando llega la sesión, [refresh] reutiliza ese mismo pedido (sin
  /// repetirlo) si coincide el usuario, la empresa, la vista y las fechas; si no, lo descarta.
  /// Con [hint] `null` (el login falló o se canceló) descarta el que hubiera.
  void prefetch(UserEntity? hint) {
    if (_companyId != null) return; // ya hay sesión: Inicio pide lo suyo
    final companyId = hint?.companyId;
    if (hint == null || companyId == null) {
      _prefetch = null;
      return;
    }
    final current = _prefetch;
    if (current != null && current.userId == hint.id && current.companyId == companyId) return;

    final roles = {for (final r in hint.roles) r.toLowerCase()};
    final firstView = _viewsFor(roles).first;
    final r = _datesFor(ReportRange.esteMes, null);
    _prefetch = _Prefetch(
      userId: hint.id,
      companyId: companyId,
      view: firstView,
      desde: r.start,
      hasta: r.end,
      startedAt: _now(),
      future: _fetch(firstView, r, null),
    );
  }

  /// El pedido adelantado, si sirve exactamente para lo que se va a pedir; si no, `null` (y se
  /// descarta). Solo se usa una vez.
  Future<_Outcome>? _takePrefetch(InicioView view, DateTimeRange r, int? sucursal) {
    final early = _prefetch;
    _prefetch = null;
    if (early == null) return null;
    final fresh = _now().difference(early.startedAt).abs() < const Duration(minutes: 2);
    final same =
        early.userId == _userId &&
        early.companyId == _companyId &&
        early.view == view &&
        sucursal == null &&
        early.desde == r.start &&
        early.hasta == r.end;
    return fresh && same ? early.future : null;
  }

  static _Outcome _outcome<T extends Object>(Either<Failure, T> result) =>
      result.fold((f) => (failure: f, data: null), (d) => (failure: null, data: d));

  Future<_Outcome> _fetch(InicioView v, DateTimeRange r, int? sucursal) async {
    return switch (v) {
      InicioView.general => _outcome(await _getWarehouseSales()),
      InicioView.ejecutivo => _outcome(await _getExecutive(r.start, r.end)),
      InicioView.jefe => _outcome(await _getTeam(r.start, r.end)),
      InicioView.ceo => _outcome(await _getCeo(r.start, r.end, sucursal: sucursal)),
    };
  }

  void _assign(InicioView v, Object data) {
    switch (v) {
      case InicioView.general:
        warehouses = data as List<WarehouseSalesEntity>;
      case InicioView.ejecutivo:
        executive = data as ExecutiveSummaryEntity;
      case InicioView.jefe:
        team = data as TeamSummaryEntity;
      case InicioView.ceo:
        ceo = data as CeoSummaryEntity;
    }
  }

  bool _sameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

  /// Lo guardado sirve si es del mismo rango: igual inicio y, o igual final, o el rango llega hasta
  /// hoy (el final de "Este mes" avanza cada día). La vista CEO solo guarda "todos los almacenes".
  bool _cacheApplies(InicioView v, Object cached, DateTimeRange r) {
    final today = DateUtils.dateOnly(_now());
    bool sameRange(DateTime desde, DateTime hasta) =>
        _sameDay(desde, r.start) && (_sameDay(hasta, r.end) || _sameDay(r.end, today));
    return switch (v) {
      InicioView.general => true,
      InicioView.ejecutivo => sameRange((cached as ExecutiveSummaryEntity).desde, cached.hasta),
      InicioView.jefe => sameRange((cached as TeamSummaryEntity).desde, cached.hasta),
      InicioView.ceo => sucursal == null && sameRange((cached as CeoSummaryEntity).desde, cached.hasta),
    };
  }

  /// Muestra lo último guardado de [v] mientras llega lo nuevo. No hace nada si lo nuevo ya llegó,
  /// si cambió el pedido, si ya hay datos a la vista o si lo guardado es de otro rango.
  Future<void> _showCached(InicioView v, int request, DateTimeRange r, bool Function() networkDone) async {
    final cache = _readCache;
    if (cache == null) return;
    Object? cached;
    try {
      cached = switch (v) {
        InicioView.general => await cache.warehouses(),
        InicioView.ejecutivo => await cache.executive(),
        InicioView.jefe => await cache.team(),
        InicioView.ceo => await cache.ceo(),
      };
    } catch (_) {
      return;
    }
    if (cached == null || networkDone() || request != _request || _hasData(v)) return;
    if (!_cacheApplies(v, cached, r)) return;
    _assign(v, cached);
    _cachedFirst.add(v);
    _displayingCache = true;
    notifyListeners();
  }

  /// Vuelve a pedir la vista de la pantalla.
  Future<void> refresh() async {
    if (_companyId == null) return;
    final current = view;
    final request = ++_request;
    loading = true;
    error = null;
    _displayingCache = false;
    notifyListeners();

    final r = dates;

    // Con lo último que se vio guardado, se muestra ya mientras llega lo nuevo.
    var networkDone = false;
    if (!_hasData(current)) unawaited(_showCached(current, request, r, () => networkDone));

    // El pedido adelantado en el login, si sirve, ya va en camino (o llegó).
    final outcome = await (_takePrefetch(current, r, sucursal) ?? _fetch(current, r, sucursal));
    networkDone = true;
    if (request != _request) return;

    final failure = outcome.failure;
    if (failure != null) {
      error = failure.message;
      // Si lo que hay a la vista es lo guardado, se sigue viendo y la pantalla avisa que no se pudo
      // actualizar.
      _displayingCache = _displayingCache || (_cachedFirst.contains(current) && _hasData(current));
      if (failure is AuthenticationFailure) _onSessionExpired?.call();
    } else {
      _assign(current, outcome.data!);
      _displayingCache = false;
      _stale.remove(current);
    }
    loading = false;
    notifyListeners();
  }
}
