import 'dart:async';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:http/http.dart' as http;
import '../../core/constants/api_constants.dart';
import '../../core/network/api_request.dart';
import '../../domain/entities/inicio_entity.dart';
import '../models/inicio_model.dart';
import 'inicio_cache_datasource.dart';

abstract class InicioRemoteDataSource {
  Future<List<WarehouseSalesEntity>> getWarehouseSales(String token);

  Future<ExecutiveSummaryEntity> getExecutiveSummary(String token, DateTime desde, DateTime hasta);

  Future<TeamSummaryEntity> getTeamSummary(String token, DateTime desde, DateTime hasta);

  Future<CeoSummaryEntity> getCeoSummary(String token, DateTime desde, DateTime hasta, {int? sucursal});

  /// Lo último que se vio de cada vista con esta sesión (para mostrarlo al instante mientras llega lo
  /// nuevo). `null` si no hay, venció o no se puede leer.
  Future<List<WarehouseSalesEntity>?> cachedWarehouseSales(String token);

  Future<ExecutiveSummaryEntity?> cachedExecutiveSummary(String token);

  Future<TeamSummaryEntity?> cachedTeamSummary(String token);

  Future<CeoSummaryEntity?> cachedCeoSummary(String token);

  /// Borra lo guardado (al cerrar sesión).
  Future<void> clearCache();
}

class InicioRemoteDataSourceImpl implements InicioRemoteDataSource {
  final http.Client client;

  /// Sin caché (pruebas, o si no se quiere) todo funciona igual, solo que sin el adelanto.
  final InicioCacheDataSource? cache;

  InicioRemoteDataSourceImpl({http.Client? client, this.cache}) : client = client ?? http.Client();

  static String _two(int v) => v.toString().padLeft(2, '0');

  static String _day(DateTime d) => '${d.year.toString().padLeft(4, '0')}-${_two(d.month)}-${_two(d.day)}';

  /// Las fechas como las manda la web (`startAndEndOfDays`): del primer segundo al último del día.
  Map<String, List<String>> _range(DateTime desde, DateTime hasta) => {
    'fechas[]': ['${_day(desde)} 00:00:00', '${_day(hasta)} 23:59:59'],
  };

  /// Guarda la respuesta buena sin hacer esperar a quien la pidió.
  void _remember(String token, String view, Object body) {
    final store = cache;
    if (store != null) unawaited(store.write(sessionScope(token), view, body));
  }

  Future<Map<String, dynamic>> _get(
    String token,
    String path,
    Map<String, List<String>> query, {
    required String view,
    bool remember = true,
  }) async {
    final uri = Uri.parse('${ApiConstants.baseUrl}$path').replace(queryParameters: query);
    final body = await sendApiRequest(() => client.get(uri, headers: ApiConstants.authHeaders(token)));
    final map = body is Map<String, dynamic> ? body : const <String, dynamic>{};
    if (remember && map.isNotEmpty) _remember(token, view, map);
    return map;
  }

  /// Lee y convierte lo guardado; si no se puede convertir (cambió el formato) se ignora.
  Future<T?> _cached<T>(String token, String view, T Function(Object json) parse) async {
    final store = cache;
    if (store == null) return null;
    try {
      final stored = await store.read(sessionScope(token), view);
      return stored == null ? null : parse(stored);
    } catch (e) {
      debugPrint('Caché de Inicio ($view) no se pudo usar: $e');
      return null;
    }
  }

  @override
  Future<List<WarehouseSalesEntity>> getWarehouseSales(String token) async {
    final uri = Uri.parse('${ApiConstants.baseUrl}/ventas/reporte-almacenes');
    final body = await sendApiRequest(() => client.get(uri, headers: ApiConstants.authHeaders(token)));
    final result = warehouseSalesFromJson(body);
    // Solo se guarda si se pudo leer: así lo guardado siempre se puede volver a leer.
    if (body != null) _remember(token, 'general', body as Object);
    return result;
  }

  @override
  Future<ExecutiveSummaryEntity> getExecutiveSummary(String token, DateTime desde, DateTime hasta) async =>
      executiveSummaryFromJson(await _get(token, '/ventas/resumen-ejecutivo', _range(desde, hasta), view: 'ejecutivo'));

  @override
  Future<TeamSummaryEntity> getTeamSummary(String token, DateTime desde, DateTime hasta) async =>
      teamSummaryFromJson(await _get(token, '/ventas/resumen-equipo', _range(desde, hasta), view: 'jefe'));

  @override
  Future<CeoSummaryEntity> getCeoSummary(String token, DateTime desde, DateTime hasta, {int? sucursal}) async =>
      ceoSummaryFromJson(
        await _get(
          token,
          '/ventas/resumen-ceo',
          {
            ..._range(desde, hasta),
            if (sucursal != null) 'sucursal': ['$sucursal'],
          },
          view: 'ceo',
          // Solo la vista de "todos los almacenes" se guarda: es la que se ve al entrar.
          remember: sucursal == null,
        ),
      );

  @override
  Future<List<WarehouseSalesEntity>?> cachedWarehouseSales(String token) =>
      _cached(token, 'general', warehouseSalesFromJson);

  @override
  Future<ExecutiveSummaryEntity?> cachedExecutiveSummary(String token) =>
      _cached(token, 'ejecutivo', (j) => executiveSummaryFromJson(j as Map<String, dynamic>));

  @override
  Future<TeamSummaryEntity?> cachedTeamSummary(String token) =>
      _cached(token, 'jefe', (j) => teamSummaryFromJson(j as Map<String, dynamic>));

  @override
  Future<CeoSummaryEntity?> cachedCeoSummary(String token) =>
      _cached(token, 'ceo', (j) => ceoSummaryFromJson(j as Map<String, dynamic>));

  @override
  Future<void> clearCache() async => cache?.clear();
}
