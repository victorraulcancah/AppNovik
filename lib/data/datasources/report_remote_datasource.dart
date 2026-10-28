import 'package:http/http.dart' as http;
import '../../core/constants/api_constants.dart';
import '../../core/network/api_request.dart';
import '../../domain/entities/report_entity.dart';
import '../models/report_model.dart';

abstract class ReportRemoteDataSource {
  Future<ExecutiveSummaryEntity> getExecutiveSummary({
    required String token,
    required DateTime desde,
    required DateTime hasta,
  });
}

class ReportRemoteDataSourceImpl implements ReportRemoteDataSource {
  final http.Client client;

  ReportRemoteDataSourceImpl({http.Client? client}) : client = client ?? http.Client();

  static String _day(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  @override
  Future<ExecutiveSummaryEntity> getExecutiveSummary({
    required String token,
    required DateTime desde,
    required DateTime hasta,
  }) async {
    // Mismo parámetro que la web: `fechas[]` con el primer y el último día.
    final uri = Uri.parse('${ApiConstants.baseUrl}/ventas/resumen-ejecutivo').replace(
      queryParameters: {
        'fechas[]': [_day(desde), _day(hasta)],
      },
    );
    final body = await sendApiRequest(
      () => client.get(uri, headers: ApiConstants.authHeaders(token)),
    );
    return executiveSummaryFromJson(body as Map<String, dynamic>);
  }
}
