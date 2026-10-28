import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import '../../core/constants/api_constants.dart';
import '../../core/network/api_request.dart';
import '../../domain/entities/document_entity.dart';
import '../models/document_model.dart';

abstract class DocumentRemoteDataSource {
  Future<DocumentPageModel> getDocuments({
    required String token,
    required int companyId,
    required DocumentKind kind,
    String? search,
    DateTime? from,
    DateTime? to,
    DocumentTipo? tipo,
    DocumentEstado? estado,
    required bool soloPendientes,
    required int page,
    required int pageSize,
  });
}

class DocumentRemoteDataSourceImpl implements DocumentRemoteDataSource {
  final http.Client client;

  DocumentRemoteDataSourceImpl({http.Client? client}) : client = client ?? http.Client();

  static final _day = DateFormat('yyyy-MM-dd');

  @override
  Future<DocumentPageModel> getDocuments({
    required String token,
    required int companyId,
    required DocumentKind kind,
    String? search,
    DateTime? from,
    DateTime? to,
    DocumentTipo? tipo,
    DocumentEstado? estado,
    required bool soloPendientes,
    required int page,
    required int pageSize,
  }) async {
    final isQuote = kind == DocumentKind.cotizacion;
    final params = <String, dynamic>{
      'company_id': ['$companyId'],
      'pagination[current]': ['$page'],
      'pagination[pageSize]': ['$pageSize'],
      if (search != null && search.isNotEmpty) 'search_input': [search],
      ..._dateFilters(isQuote, from, to),
      if (!isQuote) ..._saleFilters(tipo, estado),
      if (isQuote && soloPendientes) 'pendientes': ['1'],
    };

    final uri = Uri.parse(
      '${ApiConstants.baseUrl}${isQuote ? '/cotizaciones' : '/ventas'}',
    ).replace(queryParameters: params);

    final body = await sendApiRequest(
      () => client.get(uri, headers: ApiConstants.authHeaders(token)),
    );
    return DocumentPageModel.fromJson(body as Map<String, dynamic>, kind);
  }

  /// Las mismas fechas que manda la web: las ventas filtran `created_at` (el
  /// día termina a las 04:59:59 del siguiente, por la zona horaria); las
  /// cotizaciones, el día con `del_dia` o la fecha de emisión en un rango.
  Map<String, dynamic> _dateFilters(bool isQuote, DateTime? from, DateTime? to) {
    if (from == null || to == null) return {};

    if (isQuote) {
      if (_day.format(from) == _day.format(to)) {
        return {'filters[del_dia][0]': [_day.format(from)]};
      }
      return {
        'filters[fecha_emision][0]': ['${_day.format(from)} 00:00:00'],
        'filters[fecha_emision][1]': ['${_day.format(to)} 23:59:59'],
      };
    }

    final next = to.add(const Duration(days: 1));
    return {
      'filters[created_at][0]': ['${_day.format(from)} 00:00:00'],
      'filters[created_at][1]': ['${_day.format(next)} 04:59:59'],
    };
  }

  Map<String, dynamic> _saleFilters(DocumentTipo? tipo, DocumentEstado? estado) {
    return {
      if (tipo == DocumentTipo.boleta) 'filters[boleta.tipo][0]': ['b'],
      if (tipo == DocumentTipo.factura) 'filters[boleta.tipo][0]': ['f'],
      if (tipo == DocumentTipo.notaVenta) 'filters[sin_boleta]': ['true'],
      if (estado == DocumentEstado.activos) 'filters[estado][0]': ['true'],
      if (estado == DocumentEstado.eliminados) 'filters[estado][0]': ['false'],
    };
  }
}
