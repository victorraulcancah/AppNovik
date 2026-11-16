import 'dart:convert';
import 'dart:typed_data';

import 'package:app_novik/core/constants/api_constants.dart';
import 'package:app_novik/data/datasources/account_statement_remote_datasource.dart';
import 'package:app_novik/domain/entities/account_statement_entity.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

final _query = StatementQuery(clientId: 7, from: DateTime(2026, 11, 1), to: DateTime(2026, 11, 18));

String _apiPath(String path) => Uri.parse('${ApiConstants.baseUrl}$path').path;

void main() {
  late http.Request last;

  AccountStatementRemoteDataSourceImpl source(String body, {int status = 200, List<int>? bytes}) =>
      AccountStatementRemoteDataSourceImpl(
        client: MockClient((request) async {
          last = request;
          return bytes != null ? http.Response.bytes(bytes, status) : http.Response(body, status);
        }),
      );

  test('busca clientes como la web: validar_vendedor y un máximo de 10', () async {
    final ds = source(jsonEncode([
      {'id': 3, 'name': 'ANA', 'last_name': 'RUIZ', 'dni_ruc': '12345678', 'tipo': 'p', 'credito': 100},
    ]));

    final clients = await ds.searchClients('t', 5, 'ana');

    expect(last.method, 'GET');
    expect(last.url.path, _apiPath('/clientes/list'));
    expect(last.url.queryParameters, {'company_id': '5', 'limit': '10', 'validar_vendedor': 'true', 'search': 'ana'});
    expect(clients.single.name, 'ANA RUIZ');
    expect(clients.single.credito, 100);
    expect(last.headers['Authorization'], 'Bearer t');
  });

  test('sin texto no manda search', () async {
    final ds = source('[]');
    await ds.searchClients('t', 5, '');
    expect(last.url.queryParameters.containsKey('search'), isFalse);
  });

  test('la pestaña principal manda cliente, fechas de día completo y paginación', () async {
    final ds = source(jsonEncode({'data': [], 'total': 0}));

    await ds.getStatement('t', _query, page: 2, pageSize: 30);

    expect(last.method, 'GET');
    expect(last.url.path, _apiPath('/ventas/estado-de-cuenta'));
    final q = last.url.queryParametersAll;
    expect(q['client_id'], ['7']);
    expect(q['fechas[]'], ['2026-11-01 00:00:00', '2026-11-18 23:59:59']);
    expect(q['pagination[current]'], ['2']);
    expect(q['pagination[pageSize]'], ['30']);
    expect(q.containsKey('agrupado'), isFalse);
    expect(q.containsKey('filters[description][]'), isFalse);
  });

  test('por producto manda la búsqueda como filtro de descripción', () async {
    final ds = source(jsonEncode({'data': [], 'total': 0}));
    final query = StatementQuery(clientId: 7, from: _query.from, to: _query.to, search: ' sub ');

    await ds.getStatement('t', query, page: 1, pageSize: 30);

    expect(last.url.queryParametersAll['filters[description][]'], ['sub']);
  });

  test('agrupado manda agrupado y no la búsqueda', () async {
    final ds = source(jsonEncode({'data': [], 'total': 0}));
    final query = StatementQuery(clientId: 7, from: _query.from, to: _query.to, agrupado: true, search: 'sub');

    await ds.getStatement('t', query, page: 1, pageSize: 30);

    expect(last.url.queryParametersAll['agrupado'], ['true']);
    expect(last.url.queryParametersAll.containsKey('filters[description][]'), isFalse);
  });

  test('pedidos y pagos usan sus rutas', () async {
    final ds = source(jsonEncode({'data': [], 'total': 0}));

    await ds.getOrders('t', _query, page: 1, pageSize: 30);
    expect(last.url.path, _apiPath('/ventas/estado-de-cuenta/pedidos'));

    await ds.getPayments('t', _query, page: 1, pageSize: 30);
    expect(last.url.path, _apiPath('/ventas/estado-de-cuenta/pagos'));
  });

  test('el Excel de cada pestaña se pide con POST a su ruta', () async {
    final ds = source('', bytes: [1, 2, 3]);

    final main = await ds.exportExcel('t', StatementTab.estadoDeCuenta, _query);
    expect(last.method, 'POST');
    expect(last.url.path, _apiPath('/ventas/export/estado-de-cuenta'));
    expect(main.bytes, Uint8List.fromList([1, 2, 3]));
    expect(main.name, 'Estado de cuenta.xlsx');

    await ds.exportExcel('t', StatementTab.pedidos, _query);
    expect(last.url.path, _apiPath('/ventas/export/estado-de-cuenta-pedidos'));

    await ds.exportExcel('t', StatementTab.pagos, _query);
    expect(last.url.path, _apiPath('/ventas/export/estado-de-cuenta-pagos'));
    expect(last.url.queryParametersAll['client_id'], ['7']);
  });

  test('el PDF se pide con POST y el modo agrupado', () async {
    final ds = source('', bytes: [37, 80, 68, 70]);
    final query = StatementQuery(clientId: 7, from: _query.from, to: _query.to, agrupado: true);

    final pdf = await ds.exportPdf('t', query);

    expect(last.method, 'POST');
    expect(last.url.path, _apiPath('/ventas/export/estado-de-cuenta-pdf'));
    expect(last.url.queryParametersAll['agrupado'], ['true']);
    expect(pdf, Uint8List.fromList([37, 80, 68, 70]));
  });
}
