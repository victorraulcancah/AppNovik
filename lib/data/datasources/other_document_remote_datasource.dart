import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import '../../core/constants/api_constants.dart';
import '../../core/network/api_request.dart';
import '../../domain/entities/other_document_entity.dart';
import '../models/other_document_model.dart';

abstract class OtherDocumentRemoteDataSource {
  Future<OtherDocumentPageEntity> getPage({
    required String token,
    required int companyId,
    required OtherDocumentKind kind,
    required OtherDocumentFilters filters,
    int? number,
    required int page,
    required int pageSize,
  });

  Future<void> deleteTransfer(String token, int id);
}

class OtherDocumentRemoteDataSourceImpl implements OtherDocumentRemoteDataSource {
  final http.Client client;

  OtherDocumentRemoteDataSourceImpl({http.Client? client}) : client = client ?? http.Client();

  static final _day = DateFormat('yyyy-MM-dd');

  static String _path(OtherDocumentKind kind) => switch (kind) {
        OtherDocumentKind.traslado => '/stock-transfer',
        OtherDocumentKind.guia => '/guia-remision',
        OtherDocumentKind.notaCredito => '/nota-credito',
        OtherDocumentKind.entradaStock => '/stock',
      };

  /// Columna por la que se busca el número del documento.
  static String _numberColumn(OtherDocumentKind kind) =>
      kind == OtherDocumentKind.guia || kind == OtherDocumentKind.notaCredito
          ? 'numero'
          : 'nro_documento';

  @override
  Future<OtherDocumentPageEntity> getPage({
    required String token,
    required int companyId,
    required OtherDocumentKind kind,
    required OtherDocumentFilters filters,
    int? number,
    required int page,
    required int pageSize,
  }) async {
    // El mismo filtro de "Creado" que la web: del día desde las 05:00 (medianoche de Perú en
    // UTC) hasta las 04:59:59 del día siguiente a la fecha final.
    final range = filters.hasRange
        ? [
            '${_day.format(filters.desde!)} 05:00:00',
            '${_day.format(filters.hasta!.add(const Duration(days: 1)))} 04:59:59',
          ]
        : null;

    // Con un número buscado no se manda el rango: se busca en toda la empresa.
    final filterParams = number != null
        ? {'filters[${_numberColumn(kind)}]': ['$number']}
        : (range != null ? {'filters[created_at][]': range} : <String, List<String>>{});

    final uri = Uri.parse('${ApiConstants.baseUrl}${_path(kind)}').replace(queryParameters: {
      // Los traslados se piden con la empresa; los demás la toman del usuario.
      if (kind == OtherDocumentKind.traslado) 'company_id': ['$companyId'],
      'pagination[current]': ['$page'],
      'pagination[pageSize]': ['$pageSize'],
      ...filterParams,
    });

    final body = await sendApiRequest(
      () => client.get(uri, headers: ApiConstants.authHeaders(token)),
    );
    return otherDocumentPageFromJson(body as Map<String, dynamic>, kind);
  }

  @override
  Future<void> deleteTransfer(String token, int id) async {
    await sendApiRequest(
      () => client.delete(
        Uri.parse('${ApiConstants.baseUrl}/stock-transfer/$id'),
        headers: ApiConstants.authHeaders(token),
      ),
    );
  }
}
