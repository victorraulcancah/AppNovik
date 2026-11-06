import 'package:http/http.dart' as http;
import '../../core/constants/api_constants.dart';
import '../../core/network/api_request.dart';
import '../../domain/entities/inicio_entity.dart';
import '../models/inicio_model.dart';

abstract class InicioRemoteDataSource {
  Future<List<WarehouseSalesEntity>> getWarehouseSales(String token);

  Future<ExecutiveSummaryEntity> getExecutiveSummary(String token, DateTime desde, DateTime hasta);

  Future<TeamSummaryEntity> getTeamSummary(String token, DateTime desde, DateTime hasta);

  Future<CeoSummaryEntity> getCeoSummary(String token, DateTime desde, DateTime hasta, {int? sucursal});
}

class InicioRemoteDataSourceImpl implements InicioRemoteDataSource {
  final http.Client client;

  InicioRemoteDataSourceImpl({http.Client? client}) : client = client ?? http.Client();

  static String _two(int v) => v.toString().padLeft(2, '0');

  static String _day(DateTime d) => '${d.year.toString().padLeft(4, '0')}-${_two(d.month)}-${_two(d.day)}';

  /// Las fechas como las manda la web (`startAndEndOfDays`): del primer segundo al último del día.
  Map<String, List<String>> _range(DateTime desde, DateTime hasta) => {
    'fechas[]': ['${_day(desde)} 00:00:00', '${_day(hasta)} 23:59:59'],
  };

  Future<Map<String, dynamic>> _get(String token, String path, Map<String, List<String>> query) async {
    final uri = Uri.parse('${ApiConstants.baseUrl}$path').replace(queryParameters: query);
    final body = await sendApiRequest(() => client.get(uri, headers: ApiConstants.authHeaders(token)));
    return body is Map<String, dynamic> ? body : const {};
  }

  @override
  Future<List<WarehouseSalesEntity>> getWarehouseSales(String token) async {
    final uri = Uri.parse('${ApiConstants.baseUrl}/ventas/reporte-almacenes');
    final body = await sendApiRequest(() => client.get(uri, headers: ApiConstants.authHeaders(token)));
    return warehouseSalesFromJson(body);
  }

  @override
  Future<ExecutiveSummaryEntity> getExecutiveSummary(String token, DateTime desde, DateTime hasta) async =>
      executiveSummaryFromJson(await _get(token, '/ventas/resumen-ejecutivo', _range(desde, hasta)));

  @override
  Future<TeamSummaryEntity> getTeamSummary(String token, DateTime desde, DateTime hasta) async =>
      teamSummaryFromJson(await _get(token, '/ventas/resumen-equipo', _range(desde, hasta)));

  @override
  Future<CeoSummaryEntity> getCeoSummary(String token, DateTime desde, DateTime hasta, {int? sucursal}) async =>
      ceoSummaryFromJson(
        await _get(token, '/ventas/resumen-ceo', {
          ..._range(desde, hasta),
          if (sucursal != null) 'sucursal': ['$sucursal'],
        }),
      );
}
