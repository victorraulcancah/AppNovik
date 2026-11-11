import 'dart:async';
import 'dart:io';
import 'dart:convert';

import 'package:app_novik/core/errors/exceptions.dart';
import 'package:app_novik/core/errors/failures.dart';
import 'package:app_novik/core/utils/either.dart';
import 'package:app_novik/data/datasources/auth_local_datasource.dart';
import 'package:app_novik/data/datasources/inicio_cache_datasource.dart';
import 'package:app_novik/data/datasources/inicio_remote_datasource.dart';
import 'package:app_novik/data/datasources/theme_local_datasource.dart';
import 'package:app_novik/data/models/inicio_model.dart';
import 'package:app_novik/data/models/user_model.dart';
import 'package:app_novik/data/repositories/inicio_repository_impl.dart';
import 'package:app_novik/domain/entities/module_entity.dart';
import 'package:app_novik/domain/entities/company_entity.dart';
import 'package:app_novik/domain/entities/inicio_entity.dart';
import 'package:app_novik/domain/entities/saved_credentials_entity.dart';
import 'package:app_novik/domain/entities/session_context_entity.dart';
import 'package:app_novik/domain/entities/user_entity.dart';
import 'package:app_novik/domain/repositories/auth_repository.dart';
import 'package:app_novik/domain/repositories/inicio_cache_repository.dart';
import 'package:app_novik/domain/repositories/inicio_repository.dart';
import 'package:app_novik/domain/usecases/auth_usecases.dart';
import 'package:app_novik/domain/usecases/inicio_cache_usecases.dart';
import 'package:app_novik/domain/usecases/inicio_usecases.dart';
import 'package:app_novik/presentation/components/app_motion.dart' show AppCountUp;
import 'package:app_novik/presentation/pages/inicio_page.dart';
import 'package:app_novik/presentation/providers/auth_provider.dart';
import 'package:app_novik/presentation/providers/inicio_provider.dart';
import 'package:app_novik/presentation/providers/reports_provider.dart' show ReportRange;
import 'package:app_novik/presentation/providers/shell_navigation.dart';
import 'package:app_novik/presentation/providers/theme_provider.dart';
import 'package:app_novik/presentation/utils/inicio_copy.dart';
import 'package:app_novik/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show ByteData, FontLoader;
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';

import 'support/fake_secure_storage.dart';

// ---------------------------------------------------------------- datos de ejemplo

/// Forma de `GET /ventas/reporte-almacenes`.
List<Map<String, dynamic>> _warehousesJson() => [
  {'id': 1, 'name': 'LIMA', 'total_ventas_convertidas': '1500.5'},
  {'id': 2, 'name': 'AREQUIPA', 'total_ventas_convertidas': 300},
];

Map<String, dynamic> _meta({double avance = 62.5, String semaforo = 'ambar'}) => {
  'aplica': true,
  'anio': 2026,
  'mes': 10,
  'monto': 10000,
  'venta': 6250,
  'falta': 3750,
  'avance': avance,
  'semaforo': semaforo,
};

Map<String, dynamic> _evolution() => {
  'anio_actual': 2026,
  'anio_anterior': 2025,
  'meses': [
    for (var m = 1; m <= 12; m++) {'mes': m, 'anterior': 100.0 * m, 'actual': 120.0 * m},
  ],
};

Map<String, dynamic> _ventas() => {
  'total': 6250.5,
  'total_anterior': 5000,
  'variacion_pct': 25.0,
  'numero': 12,
  'numero_anterior': 10,
  'numero_variacion_pct': 20.0,
  'ticket': 520.88,
  'ticket_anterior': 500,
  'ticket_variacion_pct': 4.2,
};

/// Forma de `GET /ventas/resumen-ejecutivo`.
Map<String, dynamic> _executiveJson() => {
  'success': true,
  'vendedor': 'KEDER ALONSO RUIZ',
  'desde': '2026-10-01',
  'hasta': '2026-10-31',
  'desde_anterior': '2025-10-01',
  'hasta_anterior': '2025-10-31',
  'ventas': _ventas(),
  'por_almacen': [
    {'id': 1, 'nombre': 'LIMA', 'monto': 5000},
    {'id': 2, 'nombre': 'AREQUIPA', 'monto': 1250.5},
  ],
  'meta': _meta(),
  'cotizaciones': {'cantidad': 2, 'monto': 880.5},
  'cotizaciones_lista': [
    {'id': 5, 'documento': 'C001-5', 'cliente': 'CLIENTE UNO', 'monto': 500, 'dias': 9, 'prioridad': 'alta'},
    {'id': 6, 'documento': 'C001-6', 'cliente': 'CLIENTE DOS', 'monto': 380.5, 'dias': 2, 'prioridad': 'baja'},
  ],
  'evolucion': _evolution(),
  'top_productos': [
    {'id': 1, 'codigo': 'SUB-12', 'nombre': 'SUBWOOFER 12"', 'monto': 3000},
  ],
  'top_clientes': [
    {'id': 8, 'nombre': 'MARTA SAC', 'monto': 2500},
  ],
  'departamentos': [
    {'id': 15, 'nombre': 'LIMA', 'monto': 4000},
  ],
  'clientes_sin_compra': {
    'total': 9,
    'estados': [
      {'clave': 'critico', 'etiqueta': 'Crítico', 'rango': '71 % o más', 'cantidad': 2},
      {'clave': 'riesgo', 'etiqueta': 'En riesgo', 'rango': '26 - 70 %', 'cantidad': 3},
      {'clave': 'seguimiento', 'etiqueta': 'En seguimiento', 'rango': '11 - 25 %', 'cantidad': 4},
      {'clave': 'normal', 'etiqueta': 'Normal', 'rango': 'hasta 10 %', 'cantidad': 50},
    ],
  },
  'productos_sin_venta': {
    'total': 1,
    'estados': [
      {'clave': 'critico', 'etiqueta': 'Crítico', 'rango': '71 % o más', 'cantidad': 1},
      {'clave': 'riesgo', 'etiqueta': 'En riesgo', 'rango': '26 - 70 %', 'cantidad': 0},
    ],
  },
  'tareas': [
    {
      'id': 1,
      'cliente_id': 8,
      'cliente': 'MARTA SAC',
      'tipo': 'llamada',
      'tipo_etiqueta': 'Llamada',
      'accion': 'Confirmar pedido',
      'fecha': '2026-10-31 15:30:00',
      'vencida': false,
    },
    {
      'id': 2,
      'cliente_id': 9,
      'cliente': 'JUAN EIRL',
      'tipo': 'visita',
      'tipo_etiqueta': 'Visita',
      'accion': null,
      'fecha': '2026-10-29 09:00:00',
      'vencida': true,
    },
    {
      'id': 3,
      'cliente_id': 10,
      'cliente': 'LUCIA SAC',
      'tipo': 'whatsapp',
      'tipo_etiqueta': 'WhatsApp',
      'accion': null,
      'fecha': '2026-11-03 11:00:00',
      'vencida': false,
    },
  ],
  'atencion': {
    'con_caida': {
      'total': 3,
      'totales': {'anterior': 9000, 'actual': 4000, 'variacion': -5000},
      'filas': [
        {
          'id': 20,
          'cliente': 'CAIDA UNO',
          'ultima_compra': '2026-09-01',
          'anterior': 5000,
          'actual': 1000,
          'caida': 4000,
          'caida_pct': 80,
          'estado': 'critico',
        },
      ],
    },
    'sin_compra': {'total': 0, 'filas': []},
    'en_seguimiento': {'total': 0, 'filas': []},
  },
  'cumpleanos': [
    {'id': 30, 'nombre': 'ROSA PÉREZ', 'telefono': '999111222', 'fecha': '2026-10-31', 'dia': 31, 'mes': 10, 'es_hoy': true, 'ya_paso': false},
    {'id': 31, 'nombre': 'PEDRO LUNA', 'telefono': null, 'fecha': '2026-10-05', 'dia': 5, 'mes': 10, 'es_hoy': false, 'ya_paso': true},
  ],
};

/// Forma de `GET /ventas/resumen-equipo`.
Map<String, dynamic> _teamJson() => {
  'success': true,
  'jefe': 'MARIO GOMEZ',
  'desde': '2026-10-01',
  'hasta': '2026-10-31',
  'desde_anterior': '2025-10-01',
  'hasta_anterior': '2025-10-31',
  'ventas': _ventas(),
  'meta': _meta(avance: 130, semaforo: 'verde'),
  'evolucion': _evolution(),
  'vendedores': [
    {'id': 1, 'nombre': 'ANA TORRES', 'venta': 4000, 'meta': 5000, 'avance': 80, 'semaforo': 'ambar'},
    {'id': 2, 'nombre': 'LUIS RAMOS', 'venta': 2250.5, 'meta': null, 'avance': null, 'semaforo': 'gris'},
  ],
  'top_productos': [
    {'id': 1, 'codigo': 'SUB-12', 'nombre': 'SUBWOOFER 12"', 'monto': 3000, 'unidades': 6},
  ],
  'departamentos': [
    {'id': 15, 'nombre': 'LIMA', 'monto': 4000, 'participacion': 64},
  ],
  'clientes_caida': {
    'critico': 2,
    'riesgo': 1,
    'seguimiento': 0,
    'total': 3,
    'totales': {'anterior': 9000, 'actual': 4000, 'variacion': -5000},
    'filas': [
      {
        'id': 20,
        'cliente': 'CAIDA UNO',
        'vendedor': 'ANA TORRES',
        'ultima_compra': null,
        'anterior': 5000,
        'actual': 1000,
        'caida': 4000,
        'caida_pct': 80,
        'estado': 'critico',
      },
    ],
  },
  'productos_sin_ventas': {
    'critico': 1,
    'riesgo': 1,
    'seguimiento': 1,
    'total': 3,
    'mayor_caida': [
      {'id': 4, 'codigo': 'CAB-1', 'producto': 'CABLE RCA', 'anterior': 800, 'actual': 200, 'variacion': -600, 'caida_pct': 75},
    ],
  },
  'cotizaciones': {
    'cantidad': 2,
    'monto': 1200,
    'soles': 700,
    'dolares': 150,
    'filas': [
      {'id': 5, 'cliente': 'CLIENTE UNO', 'vendedor': 'ANA TORRES', 'monto': 700, 'dias': 9, 'prioridad': 'alta', 'moneda': 'soles', 'monto_moneda': 700},
      {'id': 6, 'cliente': 'CLIENTE DOS', 'vendedor': 'LUIS RAMOS', 'monto': 500, 'dias': 1, 'prioridad': 'baja', 'moneda': 'dolares', 'monto_moneda': 150},
    ],
  },
  'gestiones': {
    'hoy': [
      {'tipo': 'correo', 'hechas': 1, 'programadas': 2, 'pct': 50},
      {'tipo': 'llamada', 'hechas': 8, 'programadas': 10, 'pct': 80},
    ],
    'semana': [
      {'tipo': 'llamada', 'hechas': 20, 'programadas': 40, 'pct': 50},
    ],
    'mes': <Map<String, dynamic>>[],
  },
};

/// Forma de `GET /ventas/resumen-ceo`.
Map<String, dynamic> _ceoJson({int? sucursal}) => {
  'success': true,
  'ceo': 'CARLA CEO',
  'empresa': 'ACME SAC',
  'desde': '2026-10-01',
  'hasta': '2026-10-31',
  'desde_anterior': '2025-10-01',
  'hasta_anterior': '2025-10-31',
  'sucursal': sucursal,
  'sucursales': [
    {'id': 1, 'name': 'LIMA'},
    {'id': 2, 'name': 'AREQUIPA'},
  ],
  'ventas': {
    'total': 9000,
    'total_anterior': 8000,
    'variacion_pct': 12.5,
    'mes_anterior': 7500,
    'mes_anterior_pct': 20,
    'mes_anterior_desde': '2026-09-01',
    'mes_anterior_hasta': '2026-09-30',
    'proyeccion': 9500,
    'numero': 20,
    'ticket': 450,
  },
  'meta': _meta(avance: 90),
  'evolucion': _evolution(),
  'indicadores': {
    'ventas_acumuladas': 80000,
    'ventas_acumuladas_anterior': 70000,
    'ventas_acumuladas_pct': 14.3,
    'utilidad_estimada': 25000,
    'margen_pct': 31.3,
    'cotizaciones_monto': 4000,
    'cotizaciones_cantidad': 7,
    'clientes_activos': 33,
    'clientes_activos_anterior': 30,
    'clientes_activos_pct': 10,
  },
  'vendedores': [
    {'id': 1, 'nombre': 'ANA TORRES', 'venta': 4000, 'meta': 5000, 'avance': 80, 'semaforo': 'ambar'},
  ],
  'departamentos': [
    {'id': 15, 'nombre': 'LIMA', 'monto': 4000, 'participacion': 64},
  ],
  'canales': [
    {'id': 1, 'codigo': 'A', 'nombre': 'MAYORISTA', 'clientes': 6, 'monto': 5000},
    {'id': 2, 'codigo': 'B', 'nombre': 'MINORISTA', 'clientes': 4, 'monto': 2000},
  ],
  'cuentas_por_cobrar': {'total': 12000, 'por_vencer': 9000, 'por_vencer_pct': 75, 'vencido': 3000, 'vencido_pct': 25},
  'cobro_por_vendedor': [
    {'id': 1, 'nombre': 'ANA TORRES', 'cobrado': 2200, 'soles': 2000, 'dolares': 50, 'pendiente': 100},
  ],
  'ingresos': {
    'total': 6000,
    'total_soles': 5000,
    'total_dolares': 300,
    'total_anterior': 5500,
    'variacion_pct': 9.1,
    'total_soles_anterior': 4000,
    'total_dolares_anterior': 0,
    'variacion_soles_pct': 25,
    'variacion_dolares_pct': null,
    'desde_anterior': '2026-09-01',
    'hasta_anterior': '2026-09-30',
    'metodos': [
      {'metodo': 'EFECTIVO', 'entidad': '', 'monto': 3000, 'soles': 3000, 'dolares': 0, 'monto_anterior': 2000, 'soles_anterior': 2000, 'dolares_anterior': 0},
      {'metodo': 'BCP 7POWER', 'entidad': 'BCP', 'monto': 3000, 'soles': 2000, 'dolares': 300, 'monto_anterior': 3500, 'soles_anterior': 2000, 'dolares_anterior': 0},
    ],
  },
  'nuevos_clientes': {
    'cantidad': 4,
    'cantidad_pct': 33.3,
    'ventas': 1800,
    'ventas_pct': null,
    'top': [
      {'id': 50, 'nombre': 'NUEVO UNO', 'monto': 1000},
    ],
  },
  'clientes_caida': {
    'total': 1,
    'totales': {'anterior': 5000, 'actual': 1000, 'variacion': -4000},
    'filas': [
      {'id': 20, 'cliente': 'CAIDA UNO', 'anterior': 5000, 'actual': 1000, 'caida': 4000, 'caida_pct': 80, 'estado': 'critico'},
    ],
  },
  'productos_sin_ventas': {
    'mayor_caida': [
      {'id': 4, 'codigo': null, 'producto': 'CABLE RCA', 'anterior': 800, 'actual': 200, 'variacion': -600, 'caida_pct': 75},
    ],
  },
};

// ---------------------------------------------------------------- doble del repositorio

class _FakeRepo implements InicioRepository {
  final warehouseCalls = <int>[];
  final executiveCalls = <(DateTime, DateTime)>[];
  final teamCalls = <(DateTime, DateTime)>[];
  final ceoCalls = <(DateTime, DateTime, int?)>[];

  Failure? failure;

  @override
  Future<Either<Failure, List<WarehouseSalesEntity>>> getWarehouseSales() async {
    warehouseCalls.add(warehouseCalls.length);
    if (failure != null) return Either.left(failure!);
    return Either.right(warehouseSalesFromJson(_warehousesJson()));
  }

  @override
  Future<Either<Failure, ExecutiveSummaryEntity>> getExecutiveSummary(DateTime desde, DateTime hasta) async {
    executiveCalls.add((desde, hasta));
    if (failure != null) return Either.left(failure!);
    return Either.right(executiveSummaryFromJson(_executiveJson()));
  }

  @override
  Future<Either<Failure, TeamSummaryEntity>> getTeamSummary(DateTime desde, DateTime hasta) async {
    teamCalls.add((desde, hasta));
    if (failure != null) return Either.left(failure!);
    return Either.right(teamSummaryFromJson(_teamJson()));
  }

  @override
  Future<Either<Failure, CeoSummaryEntity>> getCeoSummary(DateTime desde, DateTime hasta, {int? sucursal}) async {
    ceoCalls.add((desde, hasta, sucursal));
    if (failure != null) return Either.left(failure!);
    return Either.right(ceoSummaryFromJson(_ceoJson(sucursal: sucursal)));
  }
}

SessionContextEntity _session({
  List<String> roles = const ['Vendedor'],
  int companyId = 7,
  Set<String>? permissions,
  bool documentos = false,
}) =>
    SessionContextEntity(
      user: const UserEntity(id: 9, name: 'Ana', usuario: 'ana'),
      company: CompanyEntity(id: companyId, razonSocial: 'ACME', igv: 0.18, renta: 0.015),
      modules: [if (documentos) const ModuleEntity(id: 5, name: 'Documentos')],
      permissions: permissions ?? const {},
      roles: roles,
      warehouses: const [],
    );

/// Sábado 31 de octubre de 2026, 10 a. m.
DateTime _now() => DateTime(2026, 10, 31, 10);

InicioProvider _provider(_FakeRepo repo, {List<String> roles = const ['Vendedor'], VoidCallback? onExpired}) =>
    InicioProvider(
      getWarehouseSalesUseCase: GetWarehouseSalesUseCase(repository: repo),
      getExecutiveSummaryUseCase: GetExecutiveSummaryUseCase(repository: repo),
      getTeamSummaryUseCase: GetTeamSummaryUseCase(repository: repo),
      getCeoSummaryUseCase: GetCeoSummaryUseCase(repository: repo),
      onSessionExpired: onExpired,
      now: _now,
    )..syncSession(_session(roles: roles));

class _FakeThemeStorage implements ThemeLocalDataSource {
  @override
  Future<ThemeMode?> read() async => null;

  @override
  Future<void> write(ThemeMode mode) async {}
}

class _FakeAuthRepository implements AuthRepository {
  @override
  Future<Either<Failure, UserEntity>> login(String usuario, String password) async =>
      Either.right(const UserEntity(id: 9, name: 'Ana', usuario: 'ana'));

  @override
  Future<Either<Failure, void>> logout() async => Either.rightVoid();

  @override
  Future<Either<Failure, SessionContextEntity?>> getSessionContext() async => Either.right(null);

  @override
  Future<String?> getToken() async => null;

  @override
  Future<Either<Failure, SavedCredentialsEntity?>> getSavedCredentials() async => Either.right(null);

  @override
  Future<Either<Failure, void>> saveCredentials(String usuario, String password) async => Either.rightVoid();

  @override
  Future<Either<Failure, void>> clearSavedCredentials() async => Either.rightVoid();
}

AuthProvider _auth(SessionContextEntity session) {
  final repo = _FakeAuthRepository();
  return AuthProvider(
    loginUseCase: LoginUseCase(repository: repo),
    logoutUseCase: LogoutUseCase(repository: repo),
    getSessionContextUseCase: GetSessionContextUseCase(repository: repo),
    getSavedCredentialsUseCase: GetSavedCredentialsUseCase(repository: repo),
    saveCredentialsUseCase: SaveCredentialsUseCase(repository: repo),
    clearSavedCredentialsUseCase: ClearSavedCredentialsUseCase(repository: repo),
  )..session = session;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('modelos', () {
    test('la pantalla general lee el total de cada almacén (viene como texto o número)', () {
      final list = warehouseSalesFromJson(_warehousesJson());

      expect(list.map((w) => w.nombre), ['LIMA', 'AREQUIPA']);
      expect(list.map((w) => w.total), [1500.5, 300]);
    });

    test('el resumen del Ejecutivo trae ventas, meta, cartera, tareas y cumpleaños', () {
      final e = executiveSummaryFromJson(_executiveJson());

      expect(e.vendedor, 'KEDER ALONSO RUIZ');
      expect(e.desde, DateTime(2026, 10, 1));
      expect(e.hastaAnterior, DateTime(2025, 10, 31));
      expect(e.ventas.total, 6250.5);
      expect(e.ventas.variacionPct, 25);
      expect(e.ventas.numeroAnterior, 10);
      expect(e.porAlmacen.map((a) => a.nombre), ['LIMA', 'AREQUIPA']);

      expect(e.meta.hasGoal, isTrue);
      expect(e.meta.avance, 62.5);
      expect(e.meta.semaforo, GoalLight.ambar);
      expect(e.meta.falta, 3750);

      expect(e.cotizacionesCantidad, 2);
      expect(e.cotizaciones.first.prioridad, QuotePriority.alta);
      expect(e.cotizaciones.last.prioridad, QuotePriority.baja);
      expect(e.evolucion.meses, hasLength(12));
      expect(e.topClientes.single.nombre, 'MARTA SAC');
      expect(e.topProductos.single.codigo, 'SUB-12');

      // Las donas de la web dan los conteos de las oportunidades.
      expect(e.clientesSinCompra.critico, 2);
      expect(e.clientesSinCompra.enCaida, 9); // 2 + 3 + 4, sin contar "normal"
      expect(e.productosSinVenta.enCaida, 1);

      expect(e.conCaida.total, 3);
      expect(e.conCaida.totales.variacion, -5000);
      expect(e.conCaida.filas.single.variacion, -4000);
      expect(e.conCaida.filas.single.estado, 'critico');

      expect(e.tareas, hasLength(3));
      expect(e.tareas[1].vencida, isTrue);
      expect(e.tareas.first.fecha, DateTime(2026, 10, 31, 15, 30));
      expect(e.cumpleanos.first.esHoy, isTrue);
      expect(e.cumpleanos.last.yaPaso, isTrue);
      expect(e.cumpleanos.last.telefono, isNull);
    });

    test('una meta que no aplica (varios meses) no cuenta como meta', () {
      final e = executiveSummaryFromJson({
        ..._executiveJson(),
        'meta': {'aplica': false, 'anio': 2026, 'mes': 10, 'monto': 0, 'venta': 0, 'falta': 0, 'avance': null, 'semaforo': 'gris'},
      });

      expect(e.meta.hasGoal, isFalse);
      expect(e.meta.avance, isNull);
      expect(e.meta.semaforo, GoalLight.gris);
    });

    test('el resumen del Jefe trae vendedores, gestiones por periodo y cotizaciones con su moneda', () {
      final t = teamSummaryFromJson(_teamJson());

      expect(t.jefe, 'MARIO GOMEZ');
      expect(t.meta.semaforo, GoalLight.verde);
      expect(t.vendedores.last.meta, isNull);
      expect(t.vendedores.last.avance, isNull);
      expect(t.topProductos.single.unidades, 6);
      expect(t.departamentos.single.participacion, 64);
      expect(t.clientesCaidaEstados.enCaida, 3);
      expect(t.clientesCaida.filas.single.vendedor, 'ANA TORRES');
      expect(t.productosSinVentasEstados.enCaida, 3);
      expect(t.productosMayorCaida.single.variacion, -600);

      expect(t.cotizacionesSoles, 700);
      expect(t.cotizacionesDolares, 150);
      expect(t.cotizaciones.last.enDolares, isTrue);
      expect(t.cotizaciones.last.montoMoneda, 150);
      expect(t.cotizaciones.last.monto, 500);

      expect(t.gestiones[TaskPeriod.hoy], hasLength(2));
      expect(t.gestiones[TaskPeriod.hoy]!.first.programadas, 2);
      expect(t.gestiones[TaskPeriod.semana]!.single.pct, 50);
      expect(t.gestiones[TaskPeriod.mes], isEmpty);
    });

    test('el resumen del CEO trae ingresos, canales, cuentas por cobrar y nuevos clientes', () {
      final c = ceoSummaryFromJson(_ceoJson(sucursal: 2));

      expect(c.empresa, 'ACME SAC');
      expect(c.sucursal, 2);
      expect(c.sucursales.map((s) => s.name), ['LIMA', 'AREQUIPA']);
      expect(c.ventas.proyeccion, 9500);
      expect(c.ventas.mesAnteriorDesde, DateTime(2026, 9, 1));
      expect(c.indicadores.utilidadEstimada, 25000);
      expect(c.indicadores.margenPct, 31.3);
      expect(c.indicadores.clientesActivosAnterior, 30);
      expect(c.canales.map((x) => x.codigo), ['A', 'B']);
      expect(c.cuentasPorCobrar.vencidoPct, 25);
      expect(c.cobroPorVendedor.single.pendiente, 100);
      expect(c.ingresos.metodos, hasLength(2));
      expect(c.ingresos.variacionDolaresPct, isNull);
      expect(c.ingresos.desdeAnterior, DateTime(2026, 9, 1));
      expect(c.nuevosClientes.cantidad, 4);
      expect(c.nuevosClientes.ventasPct, isNull);
      expect(c.nuevosClientes.top.single.nombre, 'NUEVO UNO');
      expect(c.clientesCaida.total, 1);
      expect(c.productosMayorCaida.single.codigo, isNull);
    });

    test('un cuerpo vacío o raro no rompe', () {
      expect(warehouseSalesFromJson({'error': 'x'}), isEmpty);
      final e = executiveSummaryFromJson({});
      expect(e.ventas.total, 0);
      expect(e.tareas, isEmpty);
      final c = ceoSummaryFromJson({});
      expect(c.sucursales, isEmpty);
      expect(c.ingresos.metodos, isEmpty);
    });
  });

  group('textos del Inicio', () {
    test('el saludo cambia según la hora', () {
      expect(greetingFor(InicioView.ejecutivo, 'Keder', 8).title, '¡Buenos días, Keder!');
      expect(greetingFor(InicioView.ejecutivo, 'Keder', 12).title, '¡Buenas tardes, Keder!');
      expect(greetingFor(InicioView.ejecutivo, 'Keder', 18).title, '¡Buenas tardes, Keder!');
      expect(greetingFor(InicioView.ejecutivo, 'Keder', 19).title, '¡Buenas noches, Keder!');
      // El texto de abajo cambia según el rol.
      expect(greetingFor(InicioView.jefe, 'Mario', 9).text, contains('equipo'));
      expect(greetingFor(InicioView.ceo, 'Carla', 9).text, contains('decisiones'));
    });

    test('el mensaje motivador cambia por tramo de avance y por rol', () {
      expect(goalMessage(InicioView.ejecutivo, 10, 'Keder').title, '¡Vamos, Keder!');
      expect(goalMessage(InicioView.ejecutivo, 25, 'Keder').icon, '💪');
      expect(goalMessage(InicioView.ejecutivo, 62.5, 'Keder').title, '¡Vas muy bien, Keder!');
      expect(goalMessage(InicioView.ejecutivo, 99.9, 'Keder').icon, '🎯');
      expect(goalMessage(InicioView.ejecutivo, 100, 'Keder').title, '¡Meta cumplida, Keder!');
      expect(goalMessage(InicioView.ejecutivo, 120, 'Keder').title, '¡Imparable, Keder!');
      expect(goalMessage(InicioView.jefe, 130, 'Mario').title, '¡Excelente liderazgo, Mario!');
      expect(goalMessage(InicioView.ceo, 90, 'Carla').title, '¡Estamos muy cerca, Carla!');
    });

    test('el primer nombre sale con mayúscula inicial', () {
      expect(firstName('KEDER ALONSO RUIZ'), 'Keder');
      expect(firstName('  ana  '), 'Ana');
      expect(firstName(''), '');
    });

    test('el periodo de las tareas termina hoy, el domingo o a fin de mes', () {
      final sat = DateTime(2026, 10, 31, 10); // sábado
      expect(periodEnd(TaskPeriod.hoy, sat), DateTime(2026, 10, 31, 23, 59, 59));
      expect(periodEnd(TaskPeriod.semana, sat), DateTime(2026, 11, 1, 23, 59, 59));
      expect(periodEnd(TaskPeriod.mes, sat), DateTime(2026, 10, 31, 23, 59, 59));
      final sun = DateTime(2026, 11, 1, 10); // domingo: la semana termina hoy
      expect(periodEnd(TaskPeriod.semana, sun), DateTime(2026, 11, 1, 23, 59, 59));
      final wed = DateTime(2026, 10, 28, 10);
      expect(periodEnd(TaskPeriod.semana, wed), DateTime(2026, 11, 1, 23, 59, 59));
    });

    test('la fecha de una tarea: vencida, de hoy o de otro día', () {
      final now = _now();
      TaskEntity task(DateTime f, {bool vencida = false}) => TaskEntity(
        id: 1,
        clienteId: 1,
        cliente: 'X',
        tipo: 'llamada',
        tipoEtiqueta: 'Llamada',
        fecha: f,
        vencida: vencida,
      );
      expect(taskWhen(task(DateTime(2026, 10, 29, 9), vencida: true), now), 'Vencida 29/10');
      expect(taskWhen(task(DateTime(2026, 10, 31, 15, 30)), now), 'Hoy 15:30');
      expect(taskWhen(task(DateTime(2026, 11, 3, 11)), now), '03/11 11:00');
    });

    test('el rango se nombra por mes si cae en uno solo', () {
      expect(rangeLabel(DateTime(2026, 10, 1), DateTime(2026, 10, 31)), 'Octubre 2026');
      expect(rangeLabel(DateTime(2026, 9, 1), DateTime(2026, 10, 15)), '01/09/2026 - 15/10/2026');
    });

    test('los montos usan miles y se pueden pedir con decimales', () {
      expect(soles(1234.5), 'S/ 1,235');
      expect(soles(1234.5, 2), 'S/ 1,234.50');
      expect(dolares(99.5, 2), r'$ 99.50');
      expect(thousands(1500000), '1,500,000');
    });
  });

  group('InicioRemoteDataSource', () {
    InicioRemoteDataSourceImpl source(http.Client client) => InicioRemoteDataSourceImpl(client: client);

    test('pantalla general: GET /ventas/reporte-almacenes con el token', () async {
      late http.Request seen;
      final ds = source(MockClient((request) async {
        seen = request;
        return http.Response(jsonEncode(_warehousesJson()), 200);
      }));

      final list = await ds.getWarehouseSales('tok');

      expect(seen.method, 'GET');
      expect(seen.url.path, endsWith('/api/ventas/reporte-almacenes'));
      expect(seen.headers['Authorization'], 'Bearer tok');
      expect(list, hasLength(2));
    });

    test('Ejecutivo: manda el rango como la web (fechas[] con hora de inicio y fin)', () async {
      late http.Request seen;
      final ds = source(MockClient((request) async {
        seen = request;
        return http.Response(jsonEncode(_executiveJson()), 200);
      }));

      final e = await ds.getExecutiveSummary('tok', DateTime(2026, 10, 1), DateTime(2026, 10, 31));

      expect(seen.url.path, endsWith('/api/ventas/resumen-ejecutivo'));
      expect(seen.url.queryParametersAll['fechas[]'], ['2026-10-01 00:00:00', '2026-10-31 23:59:59']);
      expect(e.vendedor, 'KEDER ALONSO RUIZ');
    });

    test('Jefe: GET /ventas/resumen-equipo', () async {
      late http.Request seen;
      final ds = source(MockClient((request) async {
        seen = request;
        return http.Response(jsonEncode(_teamJson()), 200);
      }));

      final t = await ds.getTeamSummary('tok', DateTime(2026, 9, 1), DateTime(2026, 9, 30));

      expect(seen.url.path, endsWith('/api/ventas/resumen-equipo'));
      expect(seen.url.queryParametersAll['fechas[]'], ['2026-09-01 00:00:00', '2026-09-30 23:59:59']);
      expect(t.jefe, 'MARIO GOMEZ');
    });

    test('CEO: el almacén va como sucursal, y solo si se eligió uno', () async {
      final seen = <http.Request>[];
      final ds = source(MockClient((request) async {
        seen.add(request);
        return http.Response(jsonEncode(_ceoJson()), 200);
      }));

      await ds.getCeoSummary('tok', DateTime(2026, 10, 1), DateTime(2026, 10, 31));
      await ds.getCeoSummary('tok', DateTime(2026, 10, 1), DateTime(2026, 10, 31), sucursal: 2);

      expect(seen.first.url.path, endsWith('/api/ventas/resumen-ceo'));
      expect(seen.first.url.queryParameters.containsKey('sucursal'), isFalse);
      expect(seen.last.url.queryParameters['sucursal'], '2');
    });

    test('un rol sin acceso (403) y un token vencido (401) se traducen a excepciones', () async {
      final forbidden = source(MockClient((_) async => http.Response('{"message":"no"}', 403)));
      await expectLater(
        forbidden.getCeoSummary('tok', DateTime(2026, 10, 1), DateTime(2026, 10, 31)),
        throwsA(isA<ServerException>()),
      );

      final expired = source(MockClient((_) async => http.Response('{"message":"Unauthenticated."}', 401)));
      await expectLater(
        expired.getWarehouseSales('tok'),
        throwsA(isA<AuthException>()),
      );
    });
  });

  group('InicioProvider · qué vista toca según los roles', () {
    List<InicioView> viewsOf(List<String> roles) => _provider(_FakeRepo(), roles: roles).views;

    test('Vendedor → Ejecutivo; Jefe Comercial → Jefe; Ceo Empresa → CEO', () {
      expect(viewsOf(['Vendedor']), [InicioView.ejecutivo]);
      expect(viewsOf(['JEFE COMERCIAL']), [InicioView.jefe]);
      expect(viewsOf(['Ceo Empresa']), [InicioView.ceo]);
    });

    test('con varios perfiles van del cargo más alto al más bajo y arranca en el primero', () {
      final p = _provider(_FakeRepo(), roles: ['Vendedor', 'JEFE COMERCIAL', 'Ceo Empresa']);

      expect(p.views, [InicioView.ceo, InicioView.jefe, InicioView.ejecutivo]);
      expect(p.view, InicioView.ceo);
      expect(p.hasSwitch, isTrue);
      expect(_provider(_FakeRepo(), roles: ['JEFE COMERCIAL', 'Vendedor']).view, InicioView.jefe);
    });

    test('el Jefe de Almacén y los demás roles ven la pantalla general', () {
      expect(viewsOf(['jefe de almacén']), [InicioView.general]);
      // El Jefe de Almacén no ve importes aunque tenga otro rol.
      expect(viewsOf(['jefe de almacén', 'Vendedor']), [InicioView.general]);
      expect(viewsOf(['Cajero']), [InicioView.general]);
      expect(viewsOf([]), [InicioView.general]);
      expect(_provider(_FakeRepo(), roles: ['Cajero']).hasSwitch, isFalse);
      expect(_provider(_FakeRepo(), roles: ['Cajero']).usesRange, isFalse);
    });

    test('los nombres de rol se comparan sin importar mayúsculas', () {
      expect(viewsOf(['vendedor']), [InicioView.ejecutivo]);
      expect(viewsOf(['ceo empresa']), [InicioView.ceo]);
    });
  });

  group('InicioProvider · datos', () {
    test('carga solo la vista de la pantalla, con el mes en curso hasta hoy', () async {
      final repo = _FakeRepo();
      final p = _provider(repo, roles: ['Ceo Empresa', 'Vendedor']);

      await p.ensureLoaded();

      expect(p.ceo?.empresa, 'ACME SAC');
      expect(p.executive, isNull);
      expect(repo.ceoCalls.single, (DateTime(2026, 10, 1), DateTime(2026, 10, 31), null));
      expect(repo.executiveCalls, isEmpty);
      expect(p.loading, isFalse);
    });

    test('cambiar de vista pide la otra, y volver no repite la petición', () async {
      final repo = _FakeRepo();
      final p = _provider(repo, roles: ['Ceo Empresa', 'Vendedor']);
      await p.ensureLoaded();

      await p.selectView(InicioView.ejecutivo);
      expect(p.view, InicioView.ejecutivo);
      expect(p.executive?.vendedor, 'KEDER ALONSO RUIZ');
      expect(repo.executiveCalls, hasLength(1));

      await p.selectView(InicioView.ceo);
      await p.ensureLoaded();
      expect(repo.ceoCalls, hasLength(1));
      expect(repo.executiveCalls, hasLength(1));
    });

    test('una vista que el usuario no tiene no se puede elegir', () async {
      final repo = _FakeRepo();
      final p = _provider(repo, roles: ['Vendedor']);

      await p.selectView(InicioView.ceo);

      expect(p.view, InicioView.ejecutivo);
      expect(repo.ceoCalls, isEmpty);
    });

    test('cambiar el rango vuelve a pedir esa vista y deja las otras por actualizar', () async {
      final repo = _FakeRepo();
      final p = _provider(repo, roles: ['Ceo Empresa', 'Vendedor']);
      await p.ensureLoaded();
      await p.selectView(InicioView.ejecutivo);

      await p.selectRange(ReportRange.ultimoMes);

      expect(repo.executiveCalls.last, (DateTime(2026, 9, 1), DateTime(2026, 9, 30)));
      // El CEO ya no corresponde al rango: al volver se pide de nuevo.
      await p.selectView(InicioView.ceo);
      expect(repo.ceoCalls, hasLength(2));
      expect(repo.ceoCalls.last.$1, DateTime(2026, 9, 1));
    });

    test('los atajos de fecha son los de la web', () {
      final p = _provider(_FakeRepo());

      DateTimeRange dates(ReportRange r) {
        p.range = r;
        return p.dates;
      }

      // Hoy es sábado 31/10/2026.
      expect(dates(ReportRange.estaSemana), DateTimeRange(start: DateTime(2026, 10, 26), end: DateTime(2026, 10, 31)));
      expect(dates(ReportRange.ultimaSemana), DateTimeRange(start: DateTime(2026, 10, 19), end: DateTime(2026, 10, 25)));
      expect(dates(ReportRange.ultimoMes), DateTimeRange(start: DateTime(2026, 9), end: DateTime(2026, 9, 30)));
      expect(dates(ReportRange.esteAnio), DateTimeRange(start: DateTime(2026), end: DateTime(2026, 10, 31)));
      expect(dates(ReportRange.ultimoAnio), DateTimeRange(start: DateTime(2025), end: DateTime(2025, 12, 31)));
    });

    test('un rango elegido a mano se usa tal cual', () async {
      final repo = _FakeRepo();
      final p = _provider(repo);

      await p.selectCustom(DateTimeRange(start: DateTime(2026, 8, 5), end: DateTime(2026, 8, 20)));

      expect(p.range, ReportRange.personalizado);
      expect(repo.executiveCalls.single, (DateTime(2026, 8, 5), DateTime(2026, 8, 20)));
    });

    test('el CEO filtra por almacén y se vuelve a pedir con ese almacén', () async {
      final repo = _FakeRepo();
      final p = _provider(repo, roles: ['Ceo Empresa']);
      await p.ensureLoaded();

      await p.selectSucursal(2);

      expect(p.sucursal, 2);
      expect(repo.ceoCalls.last.$3, 2);
      expect(p.ceo?.sucursal, 2);

      await p.selectSucursal(null);
      expect(repo.ceoCalls.last.$3, isNull);
    });

    test('la pantalla general no usa el rango y pide los almacenes', () async {
      final repo = _FakeRepo();
      final p = _provider(repo, roles: ['jefe de almacén']);

      await p.ensureLoaded();

      expect(p.warehouses, hasLength(2));
      expect(repo.warehouseCalls, hasLength(1));
      expect(repo.executiveCalls, isEmpty);
    });

    test('un error deja el mensaje y no deja datos viejos como buenos', () async {
      final repo = _FakeRepo()..failure = const ServerFailure('Error del servidor');
      final p = _provider(repo);

      await p.ensureLoaded();

      expect(p.executive, isNull);
      expect(p.error, 'Error del servidor');
      expect(p.loading, isFalse);

      // Al reintentar sin falla se recupera.
      repo.failure = null;
      await p.refresh();
      expect(p.error, isNull);
      expect(p.executive, isNotNull);
    });

    test('un 401 avisa para cerrar la sesión', () async {
      var expired = 0;
      final repo = _FakeRepo()..failure = const AuthenticationFailure('Sesión expirada');
      final p = _provider(repo, onExpired: () => expired++);

      await p.ensureLoaded();

      expect(expired, 1);
    });

    test('un rango al revés se rechaza antes de pedir', () async {
      final repo = _FakeRepo();
      final p = _provider(repo);

      await p.selectCustom(DateTimeRange(start: DateTime(2026, 8, 5), end: DateTime(2026, 8, 20)));
      final result = await GetExecutiveSummaryUseCase(repository: repo)(DateTime(2026, 9), DateTime(2026, 8));

      expect(result.isLeft, isTrue);
      expect(result.left, isA<ValidationFailure>());
      expect(repo.executiveCalls, hasLength(1));
    });

    test('al cambiar de empresa o de usuario se descarta todo', () async {
      final repo = _FakeRepo();
      final p = _provider(repo);
      await p.ensureLoaded();
      await p.selectRange(ReportRange.esteAnio);
      expect(p.executive, isNotNull);

      p.syncSession(_session(companyId: 8));

      expect(p.executive, isNull);
      expect(p.range, ReportRange.esteMes);
      expect(p.error, isNull);
      await p.ensureLoaded();
      expect(repo.executiveCalls, hasLength(3));
    });

    test('una respuesta tardía de otro rango se ignora', () async {
      final repo = _FakeRepo();
      final p = _provider(repo);

      final first = p.selectRange(ReportRange.ultimoMes);
      final second = p.selectRange(ReportRange.esteAnio);
      await Future.wait([first, second]);

      expect(p.range, ReportRange.esteAnio);
      expect(p.loading, isFalse);
      expect(repo.executiveCalls, hasLength(2));
    });
  });

  group('InicioPage', () {
    final shell = ShellNavigation();

    Future<_FakeRepo> pump(
      WidgetTester tester, {
      List<String> roles = const ['Vendedor'],
      Set<String>? permissions,
      bool documentos = false,
    }) async {
      // Las pruebas dibujan con la fuente Ahem (casi el doble de ancha que una real).
      tester.view.physicalSize = const Size(360 * 3, 4000 * 3);
      tester.view.devicePixelRatio = 3;
      tester.platformDispatcher.textScaleFactorTestValue = 0.55;
      addTearDown(() {
        tester.view.reset();
        tester.platformDispatcher.clearTextScaleFactorTestValue();
      });

      final repo = _FakeRepo();
      final session = _session(roles: roles, permissions: permissions, documentos: documentos);
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<ThemeProvider>(create: (_) => ThemeProvider(storage: _FakeThemeStorage())),
            ChangeNotifierProvider<AuthProvider>.value(value: _auth(session)),
            ChangeNotifierProvider<ShellNavigation>.value(value: shell),
            ChangeNotifierProvider<InicioProvider>.value(value: _provider(repo, roles: roles)),
          ],
          child: MaterialApp(theme: AppTheme.light, home: const Scaffold(body: InicioPage())),
        ),
      );
      await tester.pumpAndSettle();
      return repo;
    }

    testWidgets('Vendedor: saludo, ventas contra la meta con su mensaje y las tarjetas del Ejecutivo', (tester) async {
      await pump(tester);

      expect(find.text('Inicio'), findsOneWidget);
      expect(find.text('¡Buenos días, Keder!'), findsOneWidget);
      expect(find.text('Ventas'), findsOneWidget);
      expect(find.text('S/ 6,250.50'), findsOneWidget);
      expect(find.text('62.5%'), findsOneWidget);
      expect(find.text('Meta: S/ 10,000'), findsOneWidget);
      expect(find.text('Faltan S/ 3,750.00'), findsOneWidget);
      expect(find.textContaining('¡Vas muy bien, Keder!', findRichText: true), findsOneWidget);
      expect(find.text('N.º de ventas'), findsOneWidget);
      expect(find.text('Ticket promedio'), findsOneWidget);
      expect(find.text('Evolución de mis ventas'), findsOneWidget);
      expect(find.text('Ventas por cliente'), findsOneWidget);
      expect(find.text('Oportunidades comerciales'), findsOneWidget);
      expect(find.text('Clientes con mayor caída'), findsOneWidget);
      expect(find.text('Cotizaciones pendientes'), findsWidgets);
      expect(find.text('Cumpleaños de octubre'), findsOneWidget);
      // Sin más de un perfil no hay switch.
      expect(find.byType(SegmentedButton<InicioView>), findsNothing);
    });

    testWidgets('Ejecutivo: las oportunidades cuentan lo que está en caída', (tester) async {
      await pump(tester);

      expect(find.text('Clientes con caída'), findsOneWidget);
      expect(find.text('2 críticos · 3 en riesgo · 4 en seguimiento'), findsOneWidget);
      expect(find.text('Productos sin ventas'), findsOneWidget);
      expect(find.text('S/ 880.50'), findsOneWidget);
    });

    testWidgets('Ejecutivo: Mis tareas filtra por periodo (hoy no incluye las de la semana siguiente)', (tester) async {
      await pump(tester);

      // Hoy: la de hoy y la vencida; la del 03/11 es de la semana siguiente.
      expect(find.text('Mis tareas (2)'), findsOneWidget);
      expect(find.text('Llamar – MARTA SAC'), findsOneWidget);
      expect(find.text('Visita – JUAN EIRL'), findsOneWidget);
      expect(find.text('Hoy 15:30'), findsOneWidget);
      expect(find.text('Vencida 29/10'), findsOneWidget);
      expect(find.text('WhatsApp – LUCIA SAC'), findsNothing);
    });

    testWidgets('Ejecutivo: el filtro por tipo deja solo ese tipo', (tester) async {
      await pump(tester);

      await tester.ensureVisible(find.text('Visitas (1)'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Visitas (1)'));
      await tester.pumpAndSettle();

      expect(find.text('Visita – JUAN EIRL'), findsOneWidget);
      expect(find.text('Llamar – MARTA SAC'), findsNothing);
    });

    testWidgets('Ejecutivo: los cumpleaños marcan el de hoy y el que ya pasó', (tester) async {
      await pump(tester);

      expect(find.text('ROSA PÉREZ'), findsOneWidget);
      expect(find.text('999111222'), findsOneWidget);
      expect(find.text('31'), findsOneWidget);
      expect(find.text('PEDRO LUNA'), findsOneWidget);
    });

    testWidgets('la ayuda del mensaje muestra todos los tramos y resalta el actual', (tester) async {
      await pump(tester);

      await tester.tap(find.byTooltip('Mensajes según el avance'));
      await tester.pumpAndSettle();

      expect(find.text('Mensajes según el avance de la meta'), findsOneWidget);
      expect(find.text('0% - 24%'), findsOneWidget);
      expect(find.text('120% o más'), findsOneWidget);
      expect(find.textContaining('¡Imparable, Keder!', findRichText: true), findsOneWidget);
    });

    testWidgets('Jefe: ventas del equipo, cumplimiento por vendedor y gestiones por periodo', (tester) async {
      await pump(tester, roles: ['JEFE COMERCIAL']);

      expect(find.text('¡Buenos días, Mario!'), findsOneWidget);
      expect(find.text('Ventas del equipo'), findsOneWidget);
      expect(find.text('Evolución de ventas del equipo'), findsOneWidget);
      expect(find.text('Cumplimiento de metas por vendedor'), findsOneWidget);
      expect(find.text('1. Ana'), findsOneWidget);
      expect(find.text('2. Luis'), findsOneWidget);
      expect(find.text('Productos más vendidos del equipo'), findsOneWidget);
      expect(find.text('Oportunidades comerciales del equipo'), findsOneWidget);
      expect(find.text('Gestiones del equipo (hoy)'), findsOneWidget);
      // Las gestiones salen en el orden de la web: llamadas, luego correos.
      expect(find.text('8 / 10'), findsOneWidget);
      expect(find.text('1 / 2'), findsOneWidget);
      expect(find.text('80%'), findsWidgets);
      expect(find.text('Cotizaciones pendientes del equipo (2)'), findsOneWidget);
      expect(find.text(r'Dólares: $ 150.00', findRichText: true), findsOneWidget);
      expect(find.text('Productos con mayor caída'), findsOneWidget);
    });

    testWidgets('Jefe: cambiar de periodo muestra las gestiones de ese periodo', (tester) async {
      await pump(tester, roles: ['JEFE COMERCIAL']);

      await tester.tap(find.text('Semana'));
      await tester.pumpAndSettle();

      expect(find.text('Gestiones del equipo (semana)'), findsOneWidget);
      expect(find.text('20 / 40'), findsOneWidget);
      expect(find.text('8 / 10'), findsNothing);

      await tester.tap(find.text('Mes'));
      await tester.pumpAndSettle();
      expect(find.text('Sin gestiones programadas'), findsOneWidget);
    });

    testWidgets('CEO: ventas del periodo, indicadores con la utilidad oculta y el filtro de almacén', (tester) async {
      await pump(tester, roles: ['Ceo Empresa']);

      expect(find.text('¡Buenos días, Carla!'), findsOneWidget);
      expect(find.text('Ventas (Octubre 2026)'), findsOneWidget);
      expect(find.text('S/ 9,000'), findsWidgets); // el total de ventas y lo "por vencer"
      expect(find.text('Proyección de cierre'), findsOneWidget);
      expect(find.text('Indicadores estratégicos (YTD)'), findsOneWidget);
      expect(find.text('••••••'), findsOneWidget);
      expect(find.text('Almacén'), findsOneWidget);
      expect(find.text('Cuentas por cobrar'), findsOneWidget);
      expect(find.text('Cobro por vendedor'), findsOneWidget);
      expect(find.text('Ingresos por entidad bancaria'), findsOneWidget);
      expect(find.text('Ventas por canal'), findsOneWidget);
      expect(find.text('Nuevos clientes'), findsOneWidget);

      await tester.tap(find.byTooltip('Mostrar utilidad'));
      await tester.pumpAndSettle();
      expect(find.text('S/ 25,000'), findsOneWidget);
      expect(find.text('Margen 31.3%'), findsOneWidget);
    });

    testWidgets('CEO: Ingresos pasa de soles a dólares', (tester) async {
      await pump(tester, roles: ['Ceo Empresa']);

      // En soles salen los dos métodos; en dólares solo el que cobró dólares.
      expect(find.text('EFECTIVO'), findsOneWidget);
      await tester.tap(find.text('Dólares'));
      await tester.pumpAndSettle();

      expect(find.text('EFECTIVO'), findsNothing);
      expect(find.text('BCP 7POWER'), findsOneWidget);
    });

    testWidgets('CEO: elegir un almacén vuelve a pedir el resumen con ese almacén', (tester) async {
      final repo = await pump(tester, roles: ['Ceo Empresa']);

      await tester.tap(find.byType(DropdownButtonFormField<int>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('AREQUIPA').last);
      await tester.pumpAndSettle();

      expect(repo.ceoCalls.last.$3, 2);
    });

    testWidgets('con CEO y Vendedor hay switch, arranca en CEO y el otro perfil se pide al elegirlo', (tester) async {
      final repo = await pump(tester, roles: ['Vendedor', 'Ceo Empresa']);

      expect(find.byType(SegmentedButton<InicioView>), findsOneWidget);
      expect(find.text('CEO'), findsOneWidget);
      expect(find.text('Ejecutivo'), findsOneWidget);
      expect(find.text('Ventas (Octubre 2026)'), findsOneWidget);
      expect(repo.executiveCalls, isEmpty);

      await tester.tap(find.text('Ejecutivo'));
      await tester.pumpAndSettle();

      expect(find.text('Evolución de mis ventas'), findsOneWidget);
      expect(find.text('Ventas (Octubre 2026)'), findsNothing);
      expect(repo.executiveCalls, hasLength(1));
    });

    testWidgets('los atajos de fecha están, con Este mes elegido; elegir otro vuelve a pedir', (tester) async {
      final repo = await pump(tester);

      for (final label in ['Última semana', 'Esta semana', 'Último mes']) {
        expect(find.text(label), findsOneWidget, reason: label);
      }
      // Los demás atajos quedan a la derecha: se desliza la fila.
      await tester.drag(find.byType(ListView).first, const Offset(-400, 0));
      await tester.pumpAndSettle();
      for (final label in ['Este mes', 'Último año', 'Este año']) {
        expect(find.text(label), findsOneWidget, reason: label);
      }
      expect(tester.widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Este mes')).selected, isTrue);

      await tester.drag(find.byType(ListView).first, const Offset(400, 0));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Último mes'));
      await tester.pumpAndSettle();

      expect(repo.executiveCalls.last, (DateTime(2026, 9, 1), DateTime(2026, 9, 30)));
    });

    testWidgets('Jefe de Almacén: la pantalla de siempre, sin rango ni switch', (tester) async {
      await pump(tester, roles: ['jefe de almacén']);

      expect(find.text('Resumen de Ventas OCTUBRE / 2026'), findsOneWidget);
      expect(find.text('S/. 1,800.50'), findsOneWidget);
      expect(find.text('Almacén LIMA'), findsOneWidget);
      expect(find.text('S/. 1,500.50'), findsOneWidget);
      expect(find.text('Almacén AREQUIPA'), findsOneWidget);
      expect(find.text('Este mes'), findsNothing);
      expect(find.byType(SegmentedButton<InicioView>), findsNothing);
    });

    testWidgets('un error sin datos ofrece reintentar', (tester) async {
      tester.view.physicalSize = const Size(360 * 3, 1200 * 3);
      tester.view.devicePixelRatio = 3;
      tester.platformDispatcher.textScaleFactorTestValue = 0.55;
      addTearDown(() {
        tester.view.reset();
        tester.platformDispatcher.clearTextScaleFactorTestValue();
      });
      final repo = _FakeRepo()..failure = const ServerFailure('Error del servidor');
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<ThemeProvider>(create: (_) => ThemeProvider(storage: _FakeThemeStorage())),
            ChangeNotifierProvider<AuthProvider>.value(value: _auth(_session())),
            ChangeNotifierProvider<ShellNavigation>.value(value: shell),
            ChangeNotifierProvider<InicioProvider>.value(value: _provider(repo)),
          ],
          child: MaterialApp(theme: AppTheme.light, home: const Scaffold(body: InicioPage())),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('No se pudo cargar el resumen'), findsOneWidget);
      expect(find.text('Error del servidor'), findsOneWidget);

      repo.failure = null;
      await tester.tap(find.text('Reintentar'));
      await tester.pumpAndSettle();

      expect(find.text('Evolución de mis ventas'), findsOneWidget);
    });

    testWidgets('las cotizaciones llevan a Documentos solo con permiso y módulo', (tester) async {
      // Sin el módulo en la sesión de prueba no hay enlace: tocar el mosaico no hace nada.
      await pump(tester, permissions: {'documentos.cotizaciones.index'});
      await tester.tap(find.text('Cotizaciones pendientes').first);
      await tester.pumpAndSettle();

      expect(shell.requested, isNull);
      expect(shell.pendingQuotes, isNull);
    });

    testWidgets('con módulo y permiso, tocar las cotizaciones pendientes abre Documentos con el rango del resumen', (tester) async {
      await pump(tester, permissions: {'documentos.cotizaciones.index'}, documentos: true);
      await tester.tap(find.text('Cotizaciones pendientes').first);
      await tester.pumpAndSettle();

      expect(shell.requested, 'documentos');
      expect(shell.pendingQuotes, isNotNull);
      expect(shell.pendingQuotes!.desde, DateTime(2026, 10, 1));
      expect(shell.pendingQuotes!.hasta, DateTime(2026, 10, 31));
      shell
        ..take()
        ..takePendingQuotes();
    });

    testWidgets('con el módulo pero sin el permiso de cotizaciones no hay enlace', (tester) async {
      await pump(tester, permissions: {'documentos.ventas.index'}, documentos: true);
      await tester.tap(find.text('Cotizaciones pendientes').first);
      await tester.pumpAndSettle();

      expect(shell.requested, isNull);
    });
  });

  group('InicioPage: ayudas (?), modo oscuro y letra grande', () {
    var fontLoaded = false;

    /// Con la letra real (Roboto) y no Ahem, para que los anchos sean los de un celular.
    Future<void> loadRoboto() async {
      if (fontLoaded) return;
      final bytes = File('assets/fonts/Roboto-Regular.ttf').readAsBytesSync();
      final loader = FontLoader('Roboto')..addFont(Future.value(ByteData.view(bytes.buffer)));
      await loader.load();
      fontLoaded = true;
    }

    ThemeData withRoboto(ThemeData base) => base.copyWith(
      textTheme: base.textTheme.apply(fontFamily: 'Roboto'),
      primaryTextTheme: base.primaryTextTheme.apply(fontFamily: 'Roboto'),
    );

    Future<void> pumpPage(
      WidgetTester tester, {
      required List<String> roles,
      bool dark = false,
      double scale = 1,
      Size size = const Size(360, 4000),
    }) async {
      await loadRoboto();
      tester.view.physicalSize = Size(size.width * 3, size.height * 3);
      tester.view.devicePixelRatio = 3;
      tester.platformDispatcher.textScaleFactorTestValue = scale;
      addTearDown(() {
        tester.view.reset();
        tester.platformDispatcher.clearTextScaleFactorTestValue();
      });

      final repo = _FakeRepo();
      final session = _session(roles: roles);
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<ThemeProvider>(create: (_) => ThemeProvider(storage: _FakeThemeStorage())),
            ChangeNotifierProvider<AuthProvider>.value(value: _auth(session)),
            ChangeNotifierProvider<ShellNavigation>.value(value: ShellNavigation()),
            ChangeNotifierProvider<InicioProvider>.value(value: _provider(repo, roles: roles)),
          ],
          child: MaterialApp(
            theme: withRoboto(AppTheme.light),
            darkTheme: withRoboto(AppTheme.dark),
            themeMode: dark ? ThemeMode.dark : ThemeMode.light,
            home: const Scaffold(body: InicioPage()),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    const views = {
      'Ejecutivo (Vendedor)': ['Vendedor'],
      'Jefe (JEFE COMERCIAL)': ['JEFE COMERCIAL'],
      'CEO (Ceo Empresa)': ['Ceo Empresa'],
      'general (jefe de almacén)': ['jefe de almacén'],
    };

    for (final entry in views.entries) {
      for (final dark in [false, true]) {
        testWidgets('${entry.key}: ${dark ? 'modo oscuro' : 'modo claro'} con letra 1.3x y 360 px, sin desbordes', (tester) async {
          await pumpPage(tester, roles: entry.value, dark: dark, scale: 1.3);

          expect(tester.takeException(), isNull);
          final scheme = Theme.of(tester.element(find.byType(InicioPage))).colorScheme;
          expect(scheme.brightness, dark ? Brightness.dark : Brightness.light);
          // Nada de fondos blancos fijos: el color de la pantalla sigue al tema.
          final scaffold = tester.widget<Scaffold>(find.byType(Scaffold).first);
          expect(scaffold.backgroundColor, isNull);
        });
      }
    }

    for (final entry in views.entries) {
      for (final dark in [false, true]) {
        testWidgets('${entry.key}: los textos tienen contraste suficiente en ${dark ? 'modo oscuro' : 'modo claro'}', (tester) async {
          final handle = tester.ensureSemantics();
          await pumpPage(tester, roles: entry.value, dark: dark, size: const Size(360, 2400));
          await expectLater(tester, meetsGuideline(textContrastGuideline));
          handle.dispose();
        });
      }
    }

    testWidgets('control: la prueba de contraste sí detecta un texto ilegible', (tester) async {
      final handle = tester.ensureSemantics();
      await loadRoboto();
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            backgroundColor: Color(0xFF222222),
            body: Center(child: Text('texto ilegible', style: TextStyle(color: Color(0xFF2A2A2A), fontSize: 12))),
          ),
        ),
      );
      final result = await textContrastGuideline.evaluate(tester);
      expect(result.passed, isFalse);
      handle.dispose();
    }, timeout: const Timeout(Duration(seconds: 60)));

    testWidgets('el Ejecutivo también cabe en una pantalla angosta de 320 px con letra 1.3x', (tester) async {
      await pumpPage(tester, roles: const ['Vendedor'], dark: true, scale: 1.3, size: const Size(320, 4000));
      expect(tester.takeException(), isNull);
    });

    testWidgets('el CEO también cabe en una pantalla angosta de 320 px con letra 1.3x', (tester) async {
      await pumpPage(tester, roles: const ['Ceo Empresa'], dark: true, scale: 1.3, size: const Size(320, 4000));
      expect(tester.takeException(), isNull);
    });

    // Cada sección con (?) en la web lo tiene acá; los íconos "Ayuda" son los de las secciones.
    const helpCounts = {
      'Ejecutivo (Vendedor)': 10,
      'Jefe (JEFE COMERCIAL)': 9,
      'CEO (Ceo Empresa)': 10,
    };
    for (final entry in helpCounts.entries) {
      testWidgets('${entry.key}: trae ${entry.value} ayudas (?)', (tester) async {
        await pumpPage(tester, roles: views[entry.key]!);
        expect(find.byTooltip('Ayuda'), findsNWidgets(entry.value));
      });
    }

    testWidgets('la pantalla general (jefe de almacén) no tiene ayudas', (tester) async {
      await pumpPage(tester, roles: const ['jefe de almacén']);
      expect(find.byTooltip('Ayuda'), findsNothing);
    });

    Future<void> openHelp(WidgetTester tester, int index) async {
      final button = find.byTooltip('Ayuda').at(index);
      await tester.ensureVisible(button);
      await tester.tap(button);
      await tester.pumpAndSettle();
    }

    testWidgets('Ejecutivo: la ayuda de Ventas explica los conceptos y se cierra', (tester) async {
      await pumpPage(tester, roles: const ['Vendedor'], scale: 1);
      await openHelp(tester, 0);

      expect(find.text('Ventas y meta'), findsOneWidget);
      expect(find.textContaining('Tus ventas del rango elegido'), findsOneWidget);
      expect(find.text('Ticket promedio'), findsWidgets);
      expect(find.text('Ventas ÷ N.º de ventas.'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.tapAt(const Offset(180, 20));
      await tester.pumpAndSettle();
      expect(find.text('Ventas y meta'), findsNothing);
    });

    testWidgets('Ejecutivo: la ayuda de Cotizaciones pendientes trae la prioridad por días', (tester) async {
      await pumpPage(tester, roles: const ['Vendedor']);
      await openHelp(tester, 8); // ayudas en orden: ventas, evolución, 3 tops, oportunidades, tareas, caída, pendientes

      expect(find.text('Prioridad según los días desde la emisión'), findsOneWidget);
      expect(find.text('0 - 3 días'), findsOneWidget);
      expect(find.descendant(of: find.byType(BottomSheet), matching: find.text('Baja')), findsOneWidget);
      expect(find.text('8 días o más'), findsOneWidget);
      expect(find.text('Urge cerrarla antes de que se enfríe.'), findsOneWidget);
    });

    testWidgets('Jefe: la ayuda de Cumplimiento de metas por vendedor trae sus tres columnas', (tester) async {
      await pumpPage(tester, roles: const ['JEFE COMERCIAL']);
      await openHelp(tester, 1);

      expect(find.text('Cumplimiento de metas por vendedor'), findsWidgets);
      expect(find.text('Avance'), findsWidgets);
      expect(find.text('Ventas ÷ meta. Verde desde el 100 %, ámbar del 50 % al 99 %, rojo debajo del 50 %.'), findsOneWidget);
    });

    testWidgets('CEO: la ayuda de Ingresos por entidad bancaria y su filtro conviven en el título', (tester) async {
      await pumpPage(tester, roles: const ['Ceo Empresa'], dark: true, scale: 1.3);
      // Ingresos es la séptima sección con ayuda: indicadores, cumplimiento, departamentos, canal, por cobrar,
      // cobro por vendedor, ingresos.
      await openHelp(tester, 6);

      expect(find.text('Ingresos por entidad bancaria'), findsWidgets);
      expect(find.text('Depósitos de clientes'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('las ayudas de un solo párrafo (los tooltips de texto de la web) se abren sin tabla', (tester) async {
      await pumpPage(tester, roles: const ['Ceo Empresa']);
      await openHelp(tester, 4); // Cuentas por cobrar lleva tabla; la 3 (canal) es de texto

      expect(find.text('Cuentas por cobrar'), findsWidgets);
    });
  });

  // ------------------------------------------------------------ velocidad: prefetch, caché, datos guardados

  group('Inicio rápido: pedido adelantado en el login (prefetch)', () {
    const hint = UserEntity(id: 9, name: 'Ana', usuario: 'ana', roles: ['Vendedor'], companyId: 7);

    test('se pide la vista de arranque al instante y, al llegar la sesión, se reutiliza: una sola petición', () async {
      final repo = _GatedRepo()..gate = Completer<void>();
      final p = _bare(repo)..prefetch(hint);

      // Todavía no hay sesión (`/auth` en camino) y ya se está pidiendo el resumen del Ejecutivo.
      expect(repo.started, ['ejecutivo']);

      p.syncSession(_session());
      final load = p.ensureLoaded();
      await _settle();
      expect(p.loading, isTrue);

      repo.gate!.complete();
      await load;

      expect(repo.started, ['ejecutivo'], reason: 'el pedido adelantado se usó, no se repitió');
      expect(p.executive, isNotNull);
      expect(p.loading, isFalse);
      expect(p.error, isNull);
    });

    test('si el pedido adelantado ya llegó, mostrar Inicio no espera nada más', () async {
      final repo = _GatedRepo();
      final p = _bare(repo)..prefetch(hint);
      await _settle(); // el servidor respondió mientras llegaba /auth

      p.syncSession(_session());
      await p.ensureLoaded();

      expect(repo.started, ['ejecutivo']);
      expect(p.executive, isNotNull);
    });

    test('los roles de la sesión son otros: el pedido adelantado se descarta y se pide lo que toca', () async {
      final repo = _GatedRepo();
      final p = _bare(repo)..prefetch(hint); // el login dijo Vendedor
      p.syncSession(_session(roles: const ['Ceo Empresa'])); // /auth dice CEO

      await p.ensureLoaded();

      expect(repo.started, ['ejecutivo', 'ceo']);
      expect(p.ceo, isNotNull);
      expect(p.executive, isNull, reason: 'lo adelantado no sirvió y no se mezcla');
    });

    test('la empresa es otra: se descarta', () async {
      final repo = _GatedRepo();
      final p = _bare(repo)..prefetch(hint); // empresa 7
      p.syncSession(_session(companyId: 8));

      await p.ensureLoaded();

      expect(repo.started, ['ejecutivo', 'ejecutivo']);
    });

    test('el usuario es otro: se descarta', () async {
      final repo = _GatedRepo();
      final p = _bare(repo)..prefetch(const UserEntity(id: 10, name: 'Otro', usuario: 'otro', roles: ['Vendedor'], companyId: 7));
      p.syncSession(_session()); // usuario 9

      await p.ensureLoaded();

      expect(repo.started, ['ejecutivo', 'ejecutivo']);
    });

    test('si el login falló o se canceló (hint nulo) se descarta lo adelantado', () async {
      final repo = _GatedRepo();
      final p = _bare(repo)
        ..prefetch(hint)
        ..prefetch(null);
      p.syncSession(_session());

      await p.ensureLoaded();

      expect(repo.started, ['ejecutivo', 'ejecutivo']);
    });

    test('sin empresa en la respuesta del login no se adelanta nada', () async {
      final repo = _GatedRepo();
      _bare(repo).prefetch(const UserEntity(id: 9, name: 'Ana', usuario: 'ana', roles: ['Vendedor']));

      expect(repo.started, isEmpty);
    });

    test('con la sesión ya armada, prefetch no hace nada (y no borra nada)', () async {
      final repo = _GatedRepo();
      final p = _bare(repo)..syncSession(_session());
      await p.ensureLoaded();
      repo.started.clear();

      p.prefetch(hint);

      expect(repo.started, isEmpty);
    });

    test('el mismo login avisado varias veces no duplica la petición', () async {
      final repo = _GatedRepo()..gate = Completer<void>();
      _bare(repo)
        ..prefetch(hint)
        ..prefetch(hint)
        ..prefetch(hint);

      expect(repo.started, ['ejecutivo']);
      repo.gate!.complete();
    });

    test('se usa una sola vez: un refresco posterior pide de nuevo', () async {
      final repo = _GatedRepo();
      final p = _bare(repo)..prefetch(hint);
      p.syncSession(_session());
      await p.ensureLoaded();

      await p.refresh();

      expect(repo.started, ['ejecutivo', 'ejecutivo']);
    });

    test('elige la vista como Inicio: CEO si tiene varios perfiles, y general para el jefe de almacén', () async {
      final both = _GatedRepo();
      _bare(both).prefetch(const UserEntity(id: 9, name: 'Ana', usuario: 'ana', roles: ['Vendedor', 'Ceo Empresa'], companyId: 7));
      expect(both.started, ['ceo']);

      final warehouse = _GatedRepo();
      _bare(warehouse).prefetch(const UserEntity(id: 9, name: 'Ana', usuario: 'ana', roles: ['Jefe de Almacén'], companyId: 7));
      expect(warehouse.started, ['general']);

      final boss = _GatedRepo();
      _bare(boss).prefetch(const UserEntity(id: 9, name: 'Ana', usuario: 'ana', roles: ['JEFE COMERCIAL'], companyId: 7));
      expect(boss.started, ['jefe']);
    });

    test('si el pedido adelantado falla, se ve el error y Reintentar pide de nuevo', () async {
      final repo = _GatedRepo()..failure = const ServerFailure('Error del servidor');
      final p = _bare(repo)..prefetch(hint);
      p.syncSession(_session());
      await p.ensureLoaded();

      expect(p.error, 'Error del servidor');
      expect(p.executive, isNull);

      repo.failure = null;
      await p.refresh();
      expect(p.error, isNull);
      expect(p.executive, isNotNull);
      expect(repo.started, ['ejecutivo', 'ejecutivo']);
    });

    test('un 401 en el pedido adelantado cierra la sesión igual que uno normal', () async {
      var expired = 0;
      final repo = _GatedRepo()..failure = const AuthenticationFailure('Sesión expirada');
      final p = _bare(repo, onExpired: () => expired++)..prefetch(hint);
      p.syncSession(_session());

      await p.ensureLoaded();

      expect(expired, 1);
    });
  });

  group('Inicio rápido: lo último que se vio, al instante (caché)', () {
    ExecutiveSummaryEntity saved({String? desde, String? hasta}) =>
        executiveSummaryFromJson({..._executiveJson(), 'desde': ?desde, 'hasta': ?hasta});

    test('muestra lo guardado mientras llega lo nuevo, y lo nuevo lo reemplaza', () async {
      final repo = _GatedRepo()..gate = Completer<void>();
      final cache = _FakeCache()..executive = saved();
      final p = _bare(repo, cache: cache)..syncSession(_session());

      final load = p.ensureLoaded();
      await _settle();

      expect(p.executive, same(cache.executive), reason: 'ya se ve lo último guardado');
      expect(p.showingCache, isTrue);
      expect(p.loading, isTrue, reason: 'y se sigue pidiendo lo nuevo');
      expect(p.animateFromZero, isFalse, reason: 'las cifras no cuentan desde cero');

      repo.gate!.complete();
      await load;

      expect(p.executive, isNot(same(cache.executive)));
      expect(p.showingCache, isFalse);
      expect(p.loading, isFalse);
      expect(p.animateFromZero, isFalse, reason: 'esta vista nació de lo guardado: sus cifras pasan del valor viejo al nuevo');
    });

    test('sin nada guardado todo es como antes: espera el servidor y cuenta desde cero', () async {
      final repo = _GatedRepo()..gate = Completer<void>();
      final p = _bare(repo, cache: _FakeCache())..syncSession(_session());

      final load = p.ensureLoaded();
      await _settle();
      expect(p.executive, isNull);
      expect(p.showingCache, isFalse);

      repo.gate!.complete();
      await load;
      expect(p.executive, isNotNull);
      expect(p.animateFromZero, isTrue);
    });

    test('lo guardado de otro rango no se muestra', () async {
      final repo = _GatedRepo()..gate = Completer<void>();
      final cache = _FakeCache()..executive = saved(desde: '2026-09-01', hasta: '2026-09-30');
      final p = _bare(repo, cache: cache)..syncSession(_session());

      final load = p.ensureLoaded();
      await _settle();
      expect(p.executive, isNull);

      repo.gate!.complete();
      await load;
    });

    test('un rango que llega hasta hoy sirve aunque lo guardado terminara ayer ("Este mes" avanza cada día)', () async {
      final repo = _GatedRepo()..gate = Completer<void>();
      final cache = _FakeCache()..executive = saved(hasta: '2026-10-30');
      final p = _bare(repo, cache: cache)..syncSession(_session());

      final load = p.ensureLoaded();
      await _settle();
      expect(p.executive, same(cache.executive));

      repo.gate!.complete();
      await load;
    });

    test('si lo nuevo llega antes que la lectura del disco, lo guardado no pisa lo nuevo', () async {
      final repo = _GatedRepo();
      final cache = _FakeCache()
        ..executive = saved()
        ..gate = Completer<void>();
      final p = _bare(repo, cache: cache)..syncSession(_session());

      await p.ensureLoaded();
      final fresh = p.executive;
      expect(fresh, isNotNull);

      cache.gate!.complete();
      await _settle();

      expect(p.executive, same(fresh));
      expect(p.showingCache, isFalse);
    });

    test('si la red falla, lo guardado sigue a la vista y se avisa que no se pudo actualizar', () async {
      final repo = _GatedRepo()..failure = const NetworkFailure('Sin conexión a internet');
      final cache = _FakeCache()..executive = saved();
      final p = _bare(repo, cache: cache)..syncSession(_session());

      await p.ensureLoaded();

      expect(p.executive, same(cache.executive));
      expect(p.showingCache, isTrue);
      expect(p.error, 'Sin conexión a internet');
      expect(p.loading, isFalse);
    });

    test('con otra vista (CEO) la caché de esa vista; la de almacén elegido no se usa', () async {
      final repo = _GatedRepo()..gate = Completer<void>();
      final cache = _FakeCache()..ceo = ceoSummaryFromJson(_ceoJson());
      final p = _bare(repo, cache: cache)..syncSession(_session(roles: const ['Ceo Empresa']));

      final all = p.ensureLoaded();
      await _settle();
      expect(p.ceo, same(cache.ceo));
      repo.gate!.complete();
      await all;

      // Con un almacén elegido (otra consulta) lo guardado no corresponde.
      final repo2 = _GatedRepo()..gate = Completer<void>();
      final p2 = _bare(repo2, cache: cache)..syncSession(_session(roles: const ['Ceo Empresa']));
      final one = p2.selectSucursal(2);
      await _settle();
      expect(p2.ceo, isNull);
      repo2.gate!.complete();
      await one;
    });

    test('pantalla general: lo guardado aplica siempre (es el mes en curso)', () async {
      final repo = _GatedRepo()..gate = Completer<void>();
      final cache = _FakeCache()..warehouses = warehouseSalesFromJson(_warehousesJson());
      final p = _bare(repo, cache: cache)..syncSession(_session(roles: const ['jefe de almacén']));

      final load = p.ensureLoaded();
      await _settle();
      expect(p.warehouses, same(cache.warehouses));

      repo.gate!.complete();
      await load;
    });

    test('conviven: el pedido adelantado en el login y lo guardado (lo guardado se ve hasta que llega)', () async {
      final repo = _GatedRepo()..gate = Completer<void>();
      final cache = _FakeCache()..executive = saved();
      final p = _bare(repo, cache: cache)
        ..prefetch(const UserEntity(id: 9, name: 'Ana', usuario: 'ana', roles: ['Vendedor'], companyId: 7))
        ..syncSession(_session());

      final load = p.ensureLoaded();
      await _settle();
      expect(p.executive, same(cache.executive));

      repo.gate!.complete();
      await load;
      expect(repo.started, ['ejecutivo']);
      expect(p.executive, isNot(same(cache.executive)));
    });

    test('se borra al cerrar sesión y al cambiar de usuario o empresa, pero no con la primera sesión', () async {
      final cache = _FakeCache();
      final p = _bare(_GatedRepo(), cache: cache);

      p.syncSession(_session());
      expect(cache.clears, 0, reason: 'la primera sesión no borra: lo guardado puede ser de ella misma');

      p.syncSession(_session()); // mismo usuario y empresa: nada
      expect(cache.clears, 0);

      p.syncSession(_session(companyId: 8)); // otra empresa
      expect(cache.clears, 1);

      p.syncSession(null); // cerró sesión
      expect(cache.clears, 2);

      p.syncSession(null); // ya sin sesión: no vuelve a borrar
      expect(cache.clears, 2);
    });

    test('sin caché configurada nada de esto estorba', () async {
      final repo = _GatedRepo();
      final p = _bare(repo)..syncSession(_session());
      await p.ensureLoaded();
      p.syncSession(null);

      expect(p.executive, isNull);
      expect(p.showingCache, isFalse);
    });
  });

  group('Inicio rápido: la pantalla', () {
    Future<InicioProvider> pumpWith(
      WidgetTester tester, {
      required _GatedRepo repo,
      required _FakeCache cache,
      bool disableAnimations = false,
    }) async {
      final provider = _bare(repo, cache: cache)..syncSession(_session());
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<ThemeProvider>(create: (_) => ThemeProvider(storage: _FakeThemeStorage())),
            ChangeNotifierProvider<AuthProvider>.value(value: _auth(_session())),
            ChangeNotifierProvider<ShellNavigation>.value(value: ShellNavigation()),
            ChangeNotifierProvider<InicioProvider>.value(value: provider),
          ],
          child: MaterialApp(
            theme: AppTheme.light,
            builder: (context, child) =>
                MediaQuery(data: MediaQuery.of(context).copyWith(disableAnimations: disableAnimations), child: child!),
            home: const Scaffold(body: InicioPage()),
          ),
        ),
      );
      // El primer cuadro dispara la carga; el segundo ya trae lo guardado.
      await tester.pump();
      await tester.pump();
      return provider;
    }

    testWidgets('lo guardado se ve de inmediato con "Actualizando…" y sus cifras ya vienen completas', (tester) async {
      tester.view.physicalSize = const Size(1080, 12000);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      final repo = _GatedRepo()..gate = Completer<void>();
      final cache = _FakeCache()..executive = executiveSummaryFromJson(_executiveJson());

      await pumpWith(tester, repo: repo, cache: cache);

      expect(find.text('Actualizando…'), findsOneWidget);
      // Ninguna cifra está contando desde cero: lo que se ve es su valor final.
      final counters = tester.widgetList<AppCountUp>(find.byType(AppCountUp)).toList();
      expect(counters, isNotEmpty);
      for (final c in counters) {
        expect(find.text(c.format(c.value)), findsWidgets, reason: 'cifra ${c.format(c.value)} a la vista desde el primer cuadro');
      }

      repo.gate!.complete();
      await tester.pumpAndSettle();
      expect(find.text('Actualizando…'), findsNothing);
    });

    testWidgets('si no se pudo actualizar, avisa que se ven los últimos datos guardados', (tester) async {
      tester.view.physicalSize = const Size(1080, 12000);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      final repo = _GatedRepo()
        ..gate = Completer<void>()
        ..failure = const NetworkFailure('Sin conexión a internet');
      final cache = _FakeCache()..executive = executiveSummaryFromJson(_executiveJson());

      await pumpWith(tester, repo: repo, cache: cache);
      repo.gate!.complete();
      await tester.pumpAndSettle();

      expect(find.text('No se pudo actualizar. Se muestran los últimos datos guardados.'), findsOneWidget);
      expect(find.text('Actualizando…'), findsNothing);
      expect(find.byType(AppCountUp), findsWidgets, reason: 'el resumen guardado sigue a la vista');
    });

    testWidgets('sin lo guardado, las cifras cuentan desde cero cuando llegan los datos', (tester) async {
      tester.view.physicalSize = const Size(1080, 12000);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      final repo = _GatedRepo()..gate = Completer<void>();

      await pumpWith(tester, repo: repo, cache: _FakeCache());
      expect(find.byType(AppCountUp), findsNothing, reason: 'esqueleto de carga');

      repo.gate!.complete();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      final counters = tester.widgetList<AppCountUp>(find.byType(AppCountUp)).toList();
      expect(counters, isNotEmpty);
      final moving = counters.where((c) => c.value > 0 && !find.text(c.format(c.value)).evaluate().isNotEmpty);
      expect(moving, isNotEmpty, reason: 'al principio todavía no muestran su valor final');
      await tester.pumpAndSettle();
    });
  });

  group('InicioCacheDataSource', () {
    late FakeSecureStorage storage;
    var clock = DateTime(2026, 10, 31, 10);
    late InicioCacheDataSourceImpl cache;

    setUp(() {
      storage = FakeSecureStorage();
      clock = DateTime(2026, 10, 31, 10);
      cache = InicioCacheDataSourceImpl(storage: storage, now: () => clock);
    });

    test('guarda y vuelve a leer lo mismo', () async {
      await cache.write('sesion-1', 'ejecutivo', {'a': 1, 'b': [1, 2]});
      expect(await cache.read('sesion-1', 'ejecutivo'), {'a': 1, 'b': [1, 2]});
    });

    test('con otra sesión no se lee: nunca se mezclan datos de dos usuarios', () async {
      await cache.write('sesion-1', 'ejecutivo', {'a': 1});
      expect(await cache.read('sesion-2', 'ejecutivo'), isNull);
    });

    test('vence a las 24 horas', () async {
      await cache.write('s', 'ceo', {'a': 1});

      clock = clock.add(const Duration(hours: 23));
      expect(await cache.read('s', 'ceo'), isNotNull);

      clock = clock.add(const Duration(hours: 2));
      expect(await cache.read('s', 'ceo'), isNull);
    });

    test('cada vista tiene la suya', () async {
      await cache.write('s', 'ejecutivo', {'v': 'e'});
      await cache.write('s', 'ceo', {'v': 'c'});
      expect(await cache.read('s', 'ejecutivo'), {'v': 'e'});
      expect(await cache.read('s', 'ceo'), {'v': 'c'});
      expect(await cache.read('s', 'jefe'), isNull);
    });

    test('lo ilegible o con otra forma se ignora, sin fallar', () async {
      storage.values['inicio_cache_v1_ceo'] = '{no es json';
      expect(await cache.read('s', 'ceo'), isNull);

      storage.values['inicio_cache_v1_ceo'] = '[1,2]';
      expect(await cache.read('s', 'ceo'), isNull);

      storage.values['inicio_cache_v1_ceo'] = jsonEncode({'s': 's', 't': 'ayer', 'd': {}});
      expect(await cache.read('s', 'ceo'), isNull);
    });

    test('si no se puede escribir, no rompe', () async {
      storage.failWrites = true;
      await cache.write('s', 'ceo', {'a': 1});
      expect(await cache.read('s', 'ceo'), isNull);
    });

    test('clear borra las cuatro vistas y nada más', () async {
      storage.values['auth_token_v1'] = 'tok';
      for (final v in ['general', 'ejecutivo', 'jefe', 'ceo']) {
        await cache.write('s', v, {'v': v});
      }

      await cache.clear();

      for (final v in ['general', 'ejecutivo', 'jefe', 'ceo']) {
        expect(await cache.read('s', v), isNull);
      }
      expect(storage.values['auth_token_v1'], 'tok');
    });

    test('la huella de la sesión es estable, distinta por token y no deja el token escrito', () {
      expect(sessionScope('12|abcdef'), sessionScope('12|abcdef'));
      expect(sessionScope('12|abcdef'), isNot(sessionScope('13|abcdef')));
      expect(sessionScope('12|abcdef'), isNot(contains('abcdef')));
    });
  });

  group('InicioRemoteDataSource + caché', () {
    late FakeSecureStorage storage;
    late InicioCacheDataSourceImpl cache;

    setUp(() {
      storage = FakeSecureStorage();
      cache = InicioCacheDataSourceImpl(storage: storage, now: _now);
    });

    InicioRemoteDataSourceImpl source(http.Client client, {bool withCache = true}) =>
        InicioRemoteDataSourceImpl(client: client, cache: withCache ? cache : null);

    http.Client ok(Object body) => MockClient((request) async => http.Response(jsonEncode(body), 200));

    test('una respuesta buena se guarda sin hacer esperar, y se vuelve a leer con la misma sesión', () async {
      final ds = source(ok(_executiveJson()));

      final fresh = await ds.getExecutiveSummary('tok', DateTime(2026, 10, 1), DateTime(2026, 10, 31));
      await Future<void>.delayed(Duration.zero);

      expect(storage.values.containsKey('inicio_cache_v1_ejecutivo'), isTrue);
      final back = await ds.cachedExecutiveSummary('tok');
      expect(back, isNotNull);
      expect(back!.vendedor, fresh.vendedor);
      expect(back.desde, fresh.desde);
      expect(back.hasta, fresh.hasta);
    });

    test('con otro token (otra sesión) no se ve lo guardado', () async {
      final ds = source(ok(_executiveJson()));
      await ds.getExecutiveSummary('tok', DateTime(2026, 10, 1), DateTime(2026, 10, 31));
      await Future<void>.delayed(Duration.zero);

      expect(await ds.cachedExecutiveSummary('otro-token'), isNull);
    });

    test('una respuesta con error no guarda nada', () async {
      final ds = source(MockClient((request) async => http.Response('{"message":"x"}', 500)));

      await expectLater(
        ds.getExecutiveSummary('tok', DateTime(2026, 10, 1), DateTime(2026, 10, 31)),
        throwsA(isA<ServerException>()),
      );
      await Future<void>.delayed(Duration.zero);

      expect(storage.writes, 0);
    });

    test('las cuatro vistas se guardan y se leen (el CEO, solo "todos los almacenes")', () async {
      await source(ok(_warehousesJson())).getWarehouseSales('tok');
      await source(ok(_teamJson())).getTeamSummary('tok', DateTime(2026, 10, 1), DateTime(2026, 10, 31));
      final ceoSource = source(ok(_ceoJson()));
      await ceoSource.getCeoSummary('tok', DateTime(2026, 10, 1), DateTime(2026, 10, 31));
      await Future<void>.delayed(Duration.zero);

      expect(await ceoSource.cachedWarehouseSales('tok'), hasLength(2));
      expect((await ceoSource.cachedTeamSummary('tok'))!.jefe, 'MARIO GOMEZ');
      expect(await ceoSource.cachedCeoSummary('tok'), isNotNull);

      // Con un almacén elegido, la consulta es otra: no pisa lo guardado de "todos".
      storage.writes = 0;
      await source(ok(_ceoJson(sucursal: 2))).getCeoSummary('tok', DateTime(2026, 10, 1), DateTime(2026, 10, 31), sucursal: 2);
      await Future<void>.delayed(Duration.zero);
      expect(storage.writes, 0);
    });

    test('lo guardado que ya no se puede leer (cambió el formato) se ignora, sin fallar', () async {
      final ds = source(ok(_executiveJson()));
      await cache.write(sessionScope('tok'), 'ejecutivo', [1, 2, 3]); // ya no es un objeto

      expect(await ds.cachedExecutiveSummary('tok'), isNull);
    });

    test('sin caché configurada: todo funciona y no hay nada guardado', () async {
      final ds = source(ok(_executiveJson()), withCache: false);

      final fresh = await ds.getExecutiveSummary('tok', DateTime(2026, 10, 1), DateTime(2026, 10, 31));
      await Future<void>.delayed(Duration.zero);

      expect(fresh.vendedor, isNotEmpty);
      expect(await ds.cachedExecutiveSummary('tok'), isNull);
      await ds.clearCache();
      expect(storage.writes, 0);
    });

    test('clearCache borra lo guardado', () async {
      final ds = source(ok(_executiveJson()));
      await ds.getExecutiveSummary('tok', DateTime(2026, 10, 1), DateTime(2026, 10, 31));
      await Future<void>.delayed(Duration.zero);

      await ds.clearCache();

      expect(await ds.cachedExecutiveSummary('tok'), isNull);
    });
  });

  group('InicioRepository + caché', () {
    test('lee lo guardado con el token de la sesión; sin sesión devuelve null', () async {
      final authStorage = FakeSecureStorage();
      final auth = AuthLocalDataSourceImpl(storage: authStorage);
      final cacheStorage = FakeSecureStorage();
      final repo = InicioRepositoryImpl(
        remoteDataSource: InicioRemoteDataSourceImpl(
          client: MockClient((request) async => http.Response(jsonEncode(_executiveJson()), 200)),
          cache: InicioCacheDataSourceImpl(storage: cacheStorage, now: _now),
        ),
        authLocalDataSource: auth,
      );

      expect(await repo.cachedExecutiveSummary(), isNull, reason: 'sin sesión');

      await auth.saveSession('tok', const UserModel(id: 9, name: 'Ana', usuario: 'ana'));
      final fresh = await repo.getExecutiveSummary(DateTime(2026, 10, 1), DateTime(2026, 10, 31));
      expect(fresh.isRight, isTrue);
      await Future<void>.delayed(Duration.zero);

      expect((await repo.cachedExecutiveSummary())!.vendedor, 'KEDER ALONSO RUIZ');

      // Otra sesión en el mismo teléfono: no ve lo del anterior.
      await auth.saveSession('otro', const UserModel(id: 10, name: 'Otro', usuario: 'otro'));
      expect(await repo.cachedExecutiveSummary(), isNull);

      await repo.clearCache();
      await auth.saveSession('tok', const UserModel(id: 9, name: 'Ana', usuario: 'ana'));
      expect(await repo.cachedExecutiveSummary(), isNull);
    });
  });
}

// ---------------------------------------------------------------- dobles para la velocidad

Future<void> _settle() async {
  for (var i = 0; i < 6; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

/// Un provider sin sesión todavía (como justo después del login, antes de que llegue `/auth`).
InicioProvider _bare(_FakeRepo repo, {_FakeCache? cache, VoidCallback? onExpired}) => InicioProvider(
  getWarehouseSalesUseCase: GetWarehouseSalesUseCase(repository: repo),
  getExecutiveSummaryUseCase: GetExecutiveSummaryUseCase(repository: repo),
  getTeamSummaryUseCase: GetTeamSummaryUseCase(repository: repo),
  getCeoSummaryUseCase: GetCeoSummaryUseCase(repository: repo),
  getCachedInicioUseCase: cache == null ? null : GetCachedInicioUseCase(repository: cache),
  clearInicioCacheUseCase: cache == null ? null : ClearInicioCacheUseCase(repository: cache),
  onSessionExpired: onExpired,
  now: _now,
);

/// El repositorio de siempre, pero anota cuándo se PIDE cada vista y puede retener las respuestas.
class _GatedRepo extends _FakeRepo {
  /// Mientras exista y no se complete, ninguna respuesta llega.
  Completer<void>? gate;

  /// Las vistas que se han pedido, en orden.
  final started = <String>[];

  @override
  Future<Either<Failure, List<WarehouseSalesEntity>>> getWarehouseSales() async {
    started.add('general');
    await gate?.future;
    return super.getWarehouseSales();
  }

  @override
  Future<Either<Failure, ExecutiveSummaryEntity>> getExecutiveSummary(DateTime desde, DateTime hasta) async {
    started.add('ejecutivo');
    await gate?.future;
    return super.getExecutiveSummary(desde, hasta);
  }

  @override
  Future<Either<Failure, TeamSummaryEntity>> getTeamSummary(DateTime desde, DateTime hasta) async {
    started.add('jefe');
    await gate?.future;
    return super.getTeamSummary(desde, hasta);
  }

  @override
  Future<Either<Failure, CeoSummaryEntity>> getCeoSummary(DateTime desde, DateTime hasta, {int? sucursal}) async {
    started.add('ceo');
    await gate?.future;
    return super.getCeoSummary(desde, hasta, sucursal: sucursal);
  }
}

/// Lo "guardado" de cada vista, con una espera opcional para simular un disco lento.
class _FakeCache implements InicioCacheRepository {
  List<WarehouseSalesEntity>? warehouses;
  ExecutiveSummaryEntity? executive;
  TeamSummaryEntity? team;
  CeoSummaryEntity? ceo;
  Completer<void>? gate;
  int clears = 0;

  @override
  Future<List<WarehouseSalesEntity>?> cachedWarehouseSales() async {
    await gate?.future;
    return warehouses;
  }

  @override
  Future<ExecutiveSummaryEntity?> cachedExecutiveSummary() async {
    await gate?.future;
    return executive;
  }

  @override
  Future<TeamSummaryEntity?> cachedTeamSummary() async {
    await gate?.future;
    return team;
  }

  @override
  Future<CeoSummaryEntity?> cachedCeoSummary() async {
    await gate?.future;
    return ceo;
  }

  @override
  Future<void> clearCache() async => clears++;
}
