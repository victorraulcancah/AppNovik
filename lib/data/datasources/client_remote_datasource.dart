import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../core/constants/api_constants.dart';
import '../../core/network/api_request.dart';
import '../../domain/entities/client_form_entity.dart';
import '../../domain/entities/sale_entity.dart';
import '../models/client_model.dart';
import '../models/sale_model.dart';

abstract class ClientRemoteDataSource {
  Future<List<UbigeoItemEntity>> getDepartments(String token);
  Future<List<UbigeoItemEntity>> getProvinces(String token, String departmentId);
  Future<List<UbigeoItemEntity>> getDistricts(String token, String provinceId);
  Future<DocumentLookupEntity> lookupDocument(String token, String tipo, String number);
  Future<ClientEntity> createClient({
    required String token,
    required int companyId,
    int? executiveId,
    required NewClientFormEntity form,
  });
}

class ClientRemoteDataSourceImpl implements ClientRemoteDataSource {
  final http.Client client;

  ClientRemoteDataSourceImpl({http.Client? client}) : client = client ?? http.Client();

  Uri _uri(String path, [Map<String, String>? query]) =>
      Uri.parse('${ApiConstants.baseUrl}$path').replace(queryParameters: query);

  Future<dynamic> _get(String token, String path, [Map<String, String>? query]) =>
      sendApiRequest(() => client.get(_uri(path, query), headers: ApiConstants.authHeaders(token)));

  @override
  Future<List<UbigeoItemEntity>> getDepartments(String token) async =>
      ubigeoItemsFromJson(await _get(token, '/ubigeo/search/departments'));

  @override
  Future<List<UbigeoItemEntity>> getProvinces(String token, String departmentId) async =>
      ubigeoItemsFromJson(
        await _get(token, '/ubigeo/search/provinces', {'department_id': departmentId}),
      );

  @override
  Future<List<UbigeoItemEntity>> getDistricts(String token, String provinceId) async =>
      ubigeoItemsFromJson(
        await _get(token, '/ubigeo/search/districts', {'province_id': provinceId}),
      );

  @override
  Future<DocumentLookupEntity> lookupDocument(String token, String tipo, String number) async {
    final body = await _get(token, '/consulta/reniec', {'tipo': tipo, 'search': number});
    return documentLookupFromJson(body as Map<String, dynamic>);
  }

  @override
  Future<ClientEntity> createClient({
    required String token,
    required int companyId,
    int? executiveId,
    required NewClientFormEntity form,
  }) async {
    final body = await sendApiRequest(
      () => client.post(
        _uri('/clientes'),
        headers: ApiConstants.authHeaders(token),
        body: json.encode(newClientToJson(form, companyId: companyId, executiveId: executiveId)),
      ),
    );
    return clientFromJson(body as Map<String, dynamic>);
  }
}
