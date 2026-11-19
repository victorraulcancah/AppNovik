import 'package:flutter/material.dart';
import '../../core/errors/failures.dart';
import '../../core/utils/either.dart';
import '../../domain/entities/document_entity.dart' show DocumentEntity;
import '../../domain/entities/gestion_entity.dart';
import '../../domain/entities/inicio_entity.dart' show TaskPeriod;
import '../../domain/entities/session_context_entity.dart';
import '../../domain/usecases/gestion_usecases.dart';
import '../components/app_tabs.dart';
import '../utils/inicio_copy.dart' show periodEnd;

/// Un ejecutivo del selector de tareas del equipo, con cuántas tareas tiene en el mes.
typedef GestionEjecutivo = ({int id, String nombre, int tareas});

/// Estado del módulo Gestión (seguimiento de clientes): las tareas pendientes con sus filtros, el cliente
/// abierto (su ficha y el historial de gestiones) y el registro, la edición y la reprogramación de gestiones.
///
/// Permisos: `clientes.seguimiento` (ver todo) y `clientes.seguimiento.registrar` (crear, editar y
/// reprogramar). Al guardar algo se refrescan la ficha, el historial y las tareas.
class GestionProvider extends ChangeNotifier {
  /// Desde cuántas letras se busca un cliente.
  static const minSearch = 2;

  /// El valor del filtro de ejecutivo para las tareas de clientes sin ejecutivo comercial.
  static const sinEjecutivo = -1;

  final GetGestionCatalogoUseCase _getCatalogo;
  final SearchGestionClientesUseCase _searchClients;
  final GetGestionTareasUseCase _getTareas;
  final GetGestionFichaUseCase _getFicha;
  final GetGestionHistorialUseCase _getHistorial;
  final RegisterGestionUseCase _register;
  final EditGestionUseCase _edit;
  final RescheduleGestionUseCase _reschedule;
  final GetGestionComprasUseCase _getCompras;
  final GetGestionDocumentosUseCase _getDocumentos;
  final GetGestionVentaUseCase _getVenta;
  final GetGestionCotizacionUseCase _getCotizacion;

  /// Se llama cuando el backend responde 401 (token vencido).
  final VoidCallback? _onSessionExpired;
  final DateTime Function() _clock;

  GestionProvider({
    required GetGestionCatalogoUseCase getCatalogoUseCase,
    required SearchGestionClientesUseCase searchClientsUseCase,
    required GetGestionTareasUseCase getTareasUseCase,
    required GetGestionFichaUseCase getFichaUseCase,
    required GetGestionHistorialUseCase getHistorialUseCase,
    required RegisterGestionUseCase registerUseCase,
    required EditGestionUseCase editUseCase,
    required RescheduleGestionUseCase rescheduleUseCase,
    required GetGestionComprasUseCase getComprasUseCase,
    required GetGestionDocumentosUseCase getDocumentosUseCase,
    required GetGestionVentaUseCase getVentaUseCase,
    required GetGestionCotizacionUseCase getCotizacionUseCase,
    VoidCallback? onSessionExpired,
    DateTime Function()? clock,
  })  : _getCompras = getComprasUseCase,
        _getDocumentos = getDocumentosUseCase,
        _getVenta = getVentaUseCase,
        _getCotizacion = getCotizacionUseCase,
        _getCatalogo = getCatalogoUseCase,
        _searchClients = searchClientsUseCase,
        _getTareas = getTareasUseCase,
        _getFicha = getFichaUseCase,
        _getHistorial = getHistorialUseCase,
        _register = registerUseCase,
        _edit = editUseCase,
        _reschedule = rescheduleUseCase,
        _onSessionExpired = onSessionExpired,
        _clock = clock ?? DateTime.now {
    rango = _rangoDelAnio();
    rangoDocumentos = _rangoDelAnio();
  }

  /// La pestaña de la ficha (0 Resumen, 1 Seguimiento, 2 Compras, 3 Documentos).
  final AppTabsController tabs = AppTabsController();

  int? _companyId;
  int? _userId;
  bool _canView = false;
  bool _canRegister = false;
  bool _disposed = false;

  /// Cambia al cambiar de empresa o de usuario: lo que llegue de una sesión anterior se descarta.
  int _epoch = 0;
  int _tareasRequest = 0;
  int _fichaRequest = 0;
  int _historialRequest = 0;
  int _comprasRequest = 0;
  int _documentosRequest = 0;

  // Catálogo de resultados.
  GestionCatalogo? catalogo;
  bool catalogoLoading = false;
  String? catalogoError;

  // Tareas pendientes.
  List<GestionTarea> tareas = [];
  bool equipo = false;
  bool tareasLoading = false;
  bool tareasLoaded = false;
  String? tareasError;
  TaskPeriod periodo = TaskPeriod.hoy;

  /// `todas` o la clave de un tipo de contacto.
  String tipoTareas = 'todas';

  /// Ejecutivo elegido (solo en el equipo): `null` todos, [sinEjecutivo] o un id.
  int? ejecutivo;

  // Cliente abierto.
  int? clienteId;
  String? clienteNombre;
  GestionFicha? ficha;
  bool fichaLoading = false;

  /// Por qué no se pudo abrir la ficha (el mensaje del servidor si el cliente es ajeno a la cartera).
  String? fichaError;

  /// El error de la ficha fue de conexión: se puede reintentar (no es "este cliente no se puede mostrar").
  bool fichaErrorDeRed = false;

  // Historial de gestiones del cliente abierto.
  GestionHistorial historial = const GestionHistorial();
  bool historialLoading = false;
  bool historialLoaded = false;
  String? historialError;
  GestionContacto? filtroTipo;
  String? filtroResultado;
  late DateTimeRange rango;

  // Pestaña Compras del cliente abierto.
  GestionCompras? compras;
  bool comprasLoading = false;
  String? comprasError;

  /// Año de las últimas compras y los top 10 que se pidió; sin elegir, el actual (el que decide el servidor).
  int? anioCompras;

  // Pestaña Documentos del cliente abierto.
  List<GestionDocumento>? documentos;
  bool documentosLoading = false;
  String? documentosError;
  late DateTimeRange rangoDocumentos;

  /// `todos`, `cotizaciones` o `ventas`.
  String vistaDocumentos = 'todos';

  /// Se está trayendo un documento para abrir su comprobante: no se abre otro a la vez.
  bool abriendoDocumento = false;

  /// Si el usuario puede ver Gestión (`clientes.seguimiento`).
  bool get canView => _canView;

  /// Si puede registrar, editar y reprogramar gestiones (`clientes.seguimiento.registrar`).
  bool get canRegister => _canRegister;

  DateTime now() => _clock();

  bool get hasClient => clienteId != null;

  /// Se llama cuando cambia la sesión. Al cambiar de empresa o de usuario se descarta todo. No notifica:
  /// corre mientras se arma el árbol de widgets.
  void syncSession(SessionContextEntity? session) {
    _canView = session?.can('clientes.seguimiento') ?? false;
    _canRegister = session?.can('clientes.seguimiento.registrar') ?? false;
    final companyId = session?.company.id;
    final userId = session?.user.id;
    if (companyId == _companyId && userId == _userId) return;
    _companyId = companyId;
    _userId = userId;
    _epoch++;
    _tareasRequest++;
    _fichaRequest++;
    _historialRequest++;
    catalogo = null;
    catalogoLoading = false;
    catalogoError = null;
    tareas = [];
    equipo = false;
    tareasLoading = false;
    tareasLoaded = false;
    tareasError = null;
    periodo = TaskPeriod.hoy;
    tipoTareas = 'todas';
    ejecutivo = null;
    _clearClient();
    // Fuera del cuadro que se está armando: la barra de pestañas escucha a este controlador.
    if (tabs.index != 0) {
      Future.microtask(() {
        if (!_disposed && !hasClient) tabs.select(0);
      });
    }
  }

  void _clearClient() {
    clienteId = null;
    clienteNombre = null;
    ficha = null;
    fichaLoading = false;
    fichaError = null;
    fichaErrorDeRed = false;
    historial = const GestionHistorial();
    historialLoading = false;
    historialLoaded = false;
    historialError = null;
    filtroTipo = null;
    filtroResultado = null;
    rango = _rangoDelAnio();
    _comprasRequest++;
    _documentosRequest++;
    compras = null;
    comprasLoading = false;
    comprasError = null;
    anioCompras = null;
    documentos = null;
    documentosLoading = false;
    documentosError = null;
    rangoDocumentos = _rangoDelAnio();
    vistaDocumentos = 'todos';
  }

  /// Del 1 de enero a hoy: el rango con el que arranca el historial.
  DateTimeRange _rangoDelAnio() {
    final hoy = now();
    return DateTimeRange(start: DateTime(hoy.year), end: DateTime(hoy.year, hoy.month, hoy.day));
  }

  @override
  void dispose() {
    _disposed = true;
    tabs.dispose();
    super.dispose();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  bool _isExpired(Failure failure) {
    if (failure is AuthenticationFailure) {
      _onSessionExpired?.call();
      return true;
    }
    return false;
  }

  // ---------------------------------------------------------------------------------- catálogo

  /// Pide los resultados una sola vez (el formulario los necesita).
  Future<void> loadCatalogo() async {
    if (catalogo != null || catalogoLoading || _companyId == null) return;
    final epoch = _epoch;
    catalogoLoading = true;
    catalogoError = null;
    _notify();
    final result = await _getCatalogo();
    if (epoch != _epoch) return;
    result.fold(
      (failure) {
        _isExpired(failure);
        catalogoError = failure.message;
      },
      (data) => catalogo = data,
    );
    catalogoLoading = false;
    _notify();
  }

  // ------------------------------------------------------------------------------------ tareas

  /// Carga las tareas la primera vez.
  Future<void> ensureTareas() async {
    if (!tareasLoaded && !tareasLoading) await loadTareas();
  }

  /// Pide las tareas. Con [silent] no se muestra la carga ni se pierde lo que ya se ve.
  Future<void> loadTareas({bool silent = false}) async {
    if (_companyId == null) return;
    final epoch = _epoch;
    final request = ++_tareasRequest;
    if (!silent) {
      tareasLoading = true;
      tareasError = null;
      _notify();
    }
    final result = await _getTareas();
    if (epoch != _epoch || request != _tareasRequest) return;
    result.fold(
      (failure) {
        _isExpired(failure);
        // Con tareas a la vista un fallo al refrescar no las borra.
        if (!tareasLoaded) tareasError = failure.message;
      },
      (data) {
        tareas = data.tareas;
        equipo = data.equipo;
        tareasLoaded = true;
        tareasError = null;
        // El ejecutivo elegido ya no tiene tareas: se vuelve a ver a todos.
        if (ejecutivo != null && !ejecutivos.any((e) => e.id == ejecutivo)) ejecutivo = null;
      },
    );
    tareasLoading = false;
    _notify();
  }

  bool _delEjecutivo(GestionTarea t) =>
      ejecutivo == null || (ejecutivo == sinEjecutivo ? t.ejecutivoId == null : t.ejecutivoId == ejecutivo);

  /// Las tareas llegan hasta fin de mes: el periodo deja las que vencen hasta su último día (y siempre las
  /// vencidas), del ejecutivo elegido.
  List<GestionTarea> get tareasDelPeriodo {
    final fin = periodEnd(periodo, now());
    return [for (final t in tareas) if (!t.fecha.isAfter(fin) && _delEjecutivo(t)) t];
  }

  /// Las del periodo, del tipo de contacto elegido.
  List<GestionTarea> get tareasVisibles {
    final delPeriodo = tareasDelPeriodo;
    return tipoTareas == 'todas' ? delPeriodo : [for (final t in delPeriodo) if (t.tipo == tipoTareas) t];
  }

  /// Cuántas tareas del periodo hay de un tipo de contacto (`todas` cuenta todas).
  int conteoTareas(String tipo) =>
      tipo == 'todas' ? tareasDelPeriodo.length : tareasDelPeriodo.where((t) => t.tipo == tipo).length;

  /// Los ejecutivos que tienen tareas en el mes, con cuántas tiene cada uno, por orden alfabético.
  List<GestionEjecutivo> get ejecutivos {
    final porId = <int, GestionEjecutivo>{};
    for (final t in tareas) {
      final id = t.ejecutivoId ?? sinEjecutivo;
      final actual = porId[id];
      porId[id] = (
        id: id,
        nombre: actual?.nombre ?? t.ejecutivo ?? 'Sin ejecutivo',
        tareas: (actual?.tareas ?? 0) + 1,
      );
    }
    return porId.values.toList()..sort((a, b) => a.nombre.toLowerCase().compareTo(b.nombre.toLowerCase()));
  }

  void setPeriodo(TaskPeriod value) {
    periodo = value;
    _notify();
  }

  void setTipoTareas(String value) {
    tipoTareas = value;
    _notify();
  }

  void setEjecutivo(int? value) {
    ejecutivo = value;
    _notify();
  }

  // ----------------------------------------------------------------------------------- cliente

  /// Busca clientes por nombre, documento o código (desde [minSearch] letras).
  Future<Either<Failure, List<GestionClienteBuscado>>> buscarClientes(String query) async {
    final text = query.trim();
    if (text.length < minSearch) return Either.right(const []);
    final result = await _searchClients(text);
    if (result.isLeft) _isExpired(result.left);
    return result;
  }

  /// Abre la ficha de un cliente; con [tab] la abre en esa pestaña (1 es Seguimiento), y sin ella se queda
  /// en la pestaña en la que se estaba (útil para atender varios seguimientos seguidos).
  Future<void> openClient(int id, String nombre, {int? tab}) async {
    if (tab != null) tabs.select(tab);
    if (clienteId == id && ficha != null) {
      _notify();
      return;
    }
    _clearClient();
    clienteId = id;
    clienteNombre = nombre;
    fichaLoading = true;
    historialLoading = true;
    _notify();
    await Future.wait([_loadFicha(), _loadHistorial()]);
  }

  /// Vuelve a las tareas pendientes (sin cliente elegido); la ficha siguiente abre en Resumen.
  void closeClient() {
    _fichaRequest++;
    _historialRequest++;
    _clearClient();
    tabs.select(0);
    _notify();
  }

  /// Vuelve a pedir la ficha y el historial del cliente abierto sin mostrar la carga (al jalar para
  /// refrescar).
  Future<void> refreshClient() => Future.wait([
        _loadFicha(silent: true),
        _loadHistorial(silent: true),
        if (compras != null) loadCompras(silent: true),
        if (documentos != null) loadDocumentos(silent: true),
      ]);

  /// Reintenta cargar la ficha del cliente abierto tras un error.
  Future<void> retryClient() async {
    if (clienteId == null) return;
    fichaLoading = true;
    fichaError = null;
    historialLoading = true;
    _notify();
    await Future.wait([_loadFicha(), _loadHistorial()]);
  }

  Future<void> _loadFicha({bool silent = false}) async {
    final id = clienteId;
    if (id == null) return;
    final epoch = _epoch;
    final request = ++_fichaRequest;
    if (!silent) {
      fichaLoading = true;
      fichaError = null;
      _notify();
    }
    final result = await _getFicha(id);
    if (epoch != _epoch || request != _fichaRequest) return;
    result.fold(
      (failure) {
        _isExpired(failure);
        // Con la ficha a la vista un fallo al refrescar no la borra.
        if (ficha == null) {
          fichaError = failure.message;
          fichaErrorDeRed = failure is NetworkFailure;
        }
      },
      (data) {
        ficha = data;
        fichaError = null;
        fichaErrorDeRed = false;
      },
    );
    fichaLoading = false;
    _notify();
  }

  Future<void> _loadHistorial({bool silent = false}) async {
    final id = clienteId;
    if (id == null) return;
    final epoch = _epoch;
    final request = ++_historialRequest;
    if (!silent) {
      historialLoading = true;
      historialError = null;
      _notify();
    }
    final result = await _getHistorial(id);
    if (epoch != _epoch || request != _historialRequest) return;
    result.fold(
      (failure) {
        _isExpired(failure);
        if (!historialLoaded) historialError = failure.message;
      },
      (data) {
        historial = data;
        historialLoaded = true;
        historialError = null;
      },
    );
    historialLoading = false;
    _notify();
  }

  // ------------------------------------------------------------------------------------ compras

  /// Pide las compras la primera vez que se abre la pestaña.
  Future<void> ensureCompras() async {
    if (compras == null && !comprasLoading) await loadCompras();
  }

  /// Pide la pestaña Compras. [anio] elige de qué año son las últimas compras y los top 10; sin él se queda el
  /// que ya estaba elegido (o el actual). Con [silent] no se muestra la carga.
  Future<void> loadCompras({int? anio, bool silent = false}) async {
    final id = clienteId;
    if (id == null) return;
    final epoch = _epoch;
    final request = ++_comprasRequest;
    if (anio != null) anioCompras = anio;
    if (!silent) {
      comprasLoading = true;
      comprasError = null;
      _notify();
    }
    final result = await _getCompras(id, anio: anioCompras);
    if (epoch != _epoch || request != _comprasRequest) return;
    result.fold(
      (failure) {
        _isExpired(failure);
        // Con datos a la vista un fallo al cambiar de año no los borra: se vuelve al año que se veía.
        if (compras == null) {
          comprasError = failure.message;
        } else {
          anioCompras = compras!.anioListas;
          comprasError = failure.message;
        }
      },
      (data) {
        compras = data;
        comprasError = null;
      },
    );
    comprasLoading = false;
    _notify();
  }

  /// Cambia el año de las últimas compras y los top 10 (los gráficos muestran siempre los dos años).
  Future<void> setAnioCompras(int anio) => loadCompras(anio: anio);

  // --------------------------------------------------------------------------------- documentos

  Future<void> ensureDocumentos() async {
    if (documentos == null && !documentosLoading) await loadDocumentos();
  }

  Future<void> loadDocumentos({bool silent = false}) async {
    final id = clienteId;
    if (id == null) return;
    final epoch = _epoch;
    final request = ++_documentosRequest;
    if (!silent) {
      documentosLoading = true;
      documentosError = null;
      _notify();
    }
    final result = await _getDocumentos(id, desde: rangoDocumentos.start, hasta: rangoDocumentos.end);
    if (epoch != _epoch || request != _documentosRequest) return;
    result.fold(
      (failure) {
        _isExpired(failure);
        // Sin la lista de ese rango no se muestra la de otro: queda el mensaje y se puede reintentar.
        if (!silent) {
          documentosError = failure.message;
          documentos = null;
        }
      },
      (data) {
        documentos = data;
        documentosError = null;
      },
    );
    documentosLoading = false;
    _notify();
  }

  /// Cambia el rango de fechas: vuelve a "Todos" y pide los documentos de ese rango.
  Future<void> setRangoDocumentos(DateTimeRange value) {
    rangoDocumentos = value;
    vistaDocumentos = 'todos';
    return loadDocumentos();
  }

  void setVistaDocumentos(String value) {
    vistaDocumentos = value;
    _notify();
  }

  List<GestionDocumento> get _cotizaciones => [for (final d in documentos ?? const <GestionDocumento>[]) if (d.esCotizacion) d];

  /// Cuántos documentos hay de cada vista (`todos`, `cotizaciones` o `ventas`: facturas, boletas y tickets).
  int conteoDocumentos(String vista) {
    final todos = documentos ?? const <GestionDocumento>[];
    return switch (vista) {
      'cotizaciones' => _cotizaciones.length,
      'ventas' => todos.length - _cotizaciones.length,
      _ => todos.length,
    };
  }

  List<GestionDocumento> get documentosVisibles {
    final todos = documentos ?? const <GestionDocumento>[];
    return switch (vistaDocumentos) {
      'cotizaciones' => _cotizaciones,
      'ventas' => [for (final d in todos) if (!d.esCotizacion) d],
      _ => todos,
    };
  }

  /// Trae una venta o una cotización completa para abrir su comprobante. Una sola a la vez.
  Future<Either<Failure, DocumentEntity>> abrirDocumento({required bool cotizacion, required int id, int nroDocumento = 0}) async {
    if (abriendoDocumento) return Either.left(const ValidationFailure('Ya se está abriendo un documento'));
    final companyId = _companyId;
    if (cotizacion && companyId == null) return Either.left(const ValidationFailure('No hay una empresa activa'));
    abriendoDocumento = true;
    _notify();
    final result = cotizacion
        ? await _getCotizacion(companyId: companyId!, id: id, nroDocumento: nroDocumento)
        : await _getVenta(id);
    abriendoDocumento = false;
    if (result.isLeft) _isExpired(result.left);
    _notify();
    return result;
  }

  // ------------------------------------------------------------------------ filtros del historial

  void setFiltroTipo(GestionContacto? value) {
    filtroTipo = value;
    _notify();
  }

  void setFiltroResultado(String? value) {
    filtroResultado = value;
    _notify();
  }

  void setRango(DateTimeRange value) {
    rango = value;
    _notify();
  }

  /// Hay algún filtro distinto del de siempre (todos los tipos y resultados, del 1 de enero a hoy).
  bool get filtrando {
    final base = _rangoDelAnio();
    return filtroTipo != null || filtroResultado != null || rango.start != base.start || rango.end != base.end;
  }

  void clearFiltros() {
    filtroTipo = null;
    filtroResultado = null;
    rango = _rangoDelAnio();
    _notify();
  }

  /// Las gestiones que pasan los filtros de tipo, resultado y fechas.
  List<GestionRegistro> get gestionesVisibles {
    final desde = DateTime(rango.start.year, rango.start.month, rango.start.day);
    final hasta = DateTime(rango.end.year, rango.end.month, rango.end.day, 23, 59, 59, 999);
    return [
      for (final g in historial.gestiones)
        if ((filtroTipo == null || g.tipo == filtroTipo) &&
            (filtroResultado == null || g.resultado == filtroResultado) &&
            !g.fecha.isBefore(desde) &&
            !g.fecha.isAfter(hasta))
          g,
    ];
  }

  // ------------------------------------------------------------------------ registrar y editar

  /// Registra una gestión del cliente abierto; el seguimiento que estaba programado pasa a cumplido. Al
  /// terminar se refrescan la ficha, el historial y las tareas.
  Future<Either<Failure, void>> registrar(GestionNueva gestion) async {
    final id = clienteId;
    if (id == null) return Either.left(const ValidationFailure('Elige un cliente'));
    if (!_canRegister) return Either.left(const ValidationFailure('No tienes permiso para registrar gestiones'));
    return _afterChange(await _register(id, gestion));
  }

  /// Corrige una gestión ya registrada (tipo, resultado, comentario y siguiente contacto).
  Future<Either<Failure, void>> editar(int gestionId, GestionEdicion gestion) async {
    if (!_canRegister) return Either.left(const ValidationFailure('No tienes permiso para editar gestiones'));
    return _afterChange(await _edit(gestionId, gestion));
  }

  /// Cambia la fecha del siguiente contacto programado.
  Future<Either<Failure, void>> reprogramar(int gestionId, DateTime proximo) async {
    if (!_canRegister) return Either.left(const ValidationFailure('No tienes permiso para reprogramar gestiones'));
    return _afterChange(await _reschedule(gestionId, proximo));
  }

  Future<Either<Failure, void>> _afterChange(Either<Failure, void> result) async {
    if (result.isLeft) {
      _isExpired(result.left);
      return result;
    }
    await Future.wait([
      _loadFicha(silent: true),
      _loadHistorial(silent: true),
      loadTareas(silent: true),
    ]);
    return result;
  }
}
