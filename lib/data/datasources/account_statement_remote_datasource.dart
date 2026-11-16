import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import '../../core/constants/api_constants.dart';
import '../../core/network/api_request.dart';
import '../../domain/entities/account_statement_entity.dart';
import '../../domain/entities/document_entity.dart' show DownloadedFile;
import '../../domain/entities/sale_entity.dart' show ClientEntity;
import '../models/account_statement_model.dart';
import '../models/sale_model.dart' show clientsFromJson;

abstract class AccountStatementRemoteDataSource {
  Future<List<ClientEntity>> searchClients(String token, int companyId, String search);
  Future<StatementPageEntity> getStatement(String token, StatementQuery query, {required int page, required int pageSize});
  Future<StatementPageEntity> getOrders(String token, StatementQuery query, {required int page, required int pageSize});
  Future<StatementPageEntity> getPayments(String token, StatementQuery query, {required int page, required int pageSize});
  Future<DownloadedFile> exportExcel(String token, StatementTab tab, StatementQuery query);
  Future<Uint8List> exportPdf(String token, StatementQuery query);
}

class AccountStatementRemoteDataSourceImpl implements AccountStatementRemoteDataSource {
  final http.Client client;

  AccountStatementRemoteDataSourceImpl({http.Client? client}) : client = client ?? http.Client();

  static final _dateTime = DateFormat('yyyy-MM-dd HH:mm:ss');

  Uri _uri(String path, Map<String, dynamic> query) =>
      Uri.parse('${ApiConstants.baseUrl}$path').replace(queryParameters: query);

  /// `fechas[]`: desde las 00:00:00 del primer día hasta las 23:59:59 del último (como la web).
  List<String> _dates(StatementQuery q) => [
        _dateTime.format(DateTime(q.from.year, q.from.month, q.from.day)),
        _dateTime.format(DateTime(q.to.year, q.to.month, q.to.day, 23, 59, 59)),
      ];

  Map<String, dynamic> _params(StatementQuery q, {bool agrupado = false}) => {
        'client_id': '${q.clientId}',
        'fechas[]': _dates(q),
        if (agrupado) 'agrupado': 'true',
      };

  Map<String, dynamic> _paged(Map<String, dynamic> params, int page, int pageSize) => {
        ...params,
        'pagination[current]': '$page',
        'pagination[pageSize]': '$pageSize',
      };

  Future<dynamic> _get(String token, Uri uri) =>
      sendApiRequest(() => client.get(uri, headers: ApiConstants.authHeaders(token)));

  @override
  Future<List<ClientEntity>> searchClients(String token, int companyId, String search) async =>
      clientsFromJson(
        await _get(
          token,
          _uri('/clientes/list', {
            'company_id': '$companyId',
            'limit': '10',
            'validar_vendedor': 'true',
            if (search.isNotEmpty) 'search': search,
          }),
        ),
      );

  @override
  Future<StatementPageEntity> getStatement(String token, StatementQuery query, {required int page, required int pageSize}) async {
    final search = query.search?.trim() ?? '';
    final params = {
      ..._params(query, agrupado: query.agrupado),
      // Solo la vista por producto se filtra por código o descripción.
      if (!query.agrupado && search.isNotEmpty) 'filters[description][]': search,
    };
    final body = await _get(token, _uri('/ventas/estado-de-cuenta', _paged(params, page, pageSize)));
    return statementPageFromJson(body as Map<String, dynamic>, agrupado: query.agrupado);
  }

  @override
  Future<StatementPageEntity> getOrders(String token, StatementQuery query, {required int page, required int pageSize}) async {
    final body = await _get(token, _uri('/ventas/estado-de-cuenta/pedidos', _paged(_params(query), page, pageSize)));
    return statementOrdersFromJson(body as Map<String, dynamic>);
  }

  @override
  Future<StatementPageEntity> getPayments(String token, StatementQuery query, {required int page, required int pageSize}) async {
    final body = await _get(token, _uri('/ventas/estado-de-cuenta/pagos', _paged(_params(query), page, pageSize)));
    return statementPaymentsFromJson(body as Map<String, dynamic>);
  }

  @override
  Future<DownloadedFile> exportExcel(String token, StatementTab tab, StatementQuery query) async {
    final suffix = switch (tab) {
      StatementTab.estadoDeCuenta => '',
      StatementTab.pedidos => '-pedidos',
      StatementTab.pagos => '-pagos',
    };
    final uri = _uri('/ventas/export/estado-de-cuenta$suffix', _params(query, agrupado: query.agrupado));
    final bytes = await sendApiBytes(() => client.post(uri, headers: ApiConstants.authHeaders(token)));
    return DownloadedFile(name: '${tab.fileName}.xlsx', bytes: bytes);
  }

  @override
  Future<Uint8List> exportPdf(String token, StatementQuery query) {
    final uri = _uri('/ventas/export/estado-de-cuenta-pdf', _params(query, agrupado: query.agrupado));
    return sendApiBytes(() => client.post(uri, headers: ApiConstants.authHeaders(token)));
  }
}
