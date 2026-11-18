import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import '../../core/constants/api_constants.dart';
import '../../core/errors/exceptions.dart';
import '../../core/network/api_request.dart';
import '../../domain/entities/client_form_entity.dart' show UbigeoItemEntity;
import '../../domain/entities/user_record_entity.dart';
import '../models/client_model.dart' show ubigeoItemsFromJson;
import '../models/user_record_model.dart';

abstract class UserRecordRemoteDataSource {
  Future<UserPageEntity> getUsers(
    String token, {
    required int companyId,
    required int page,
    required int pageSize,
    required UserFiltersEntity filters,
  });

  Future<UserCatalogsEntity> getCatalogs(String token, {required int companyId});

  Future<UserRecordEntity> saveUser(
    String token, {
    required int companyId,
    required UserFormEntity form,
    int? id,
  });

  Future<void> uploadPhoto(String token, {required int id, required Uint8List bytes, required String name});

  Future<Uint8List?> getPhoto(String token, int id);

  Future<List<UserOption>> getRoles(String token);

  Future<UserOption> saveRole(String token, {required String name, int? id});

  Future<void> deleteRole(String token, int id);

  Future<List<UbigeoItemEntity>> getDepartments(String token);
  Future<List<UbigeoItemEntity>> getProvinces(String token, String departmentId);
  Future<List<UbigeoItemEntity>> getDistricts(String token, String provinceId);
}

class UserRecordRemoteDataSourceImpl implements UserRecordRemoteDataSource {
  final http.Client client;

  UserRecordRemoteDataSourceImpl({http.Client? client}) : client = client ?? http.Client();

  /// Parámetros de la lista: los mismos que arma la web (`company_id`, `pagination[...]`, `search` y
  /// los filtros de columna `filters[estado][]` y `filters[roles.name][]`).
  static List<MapEntry<String, String>> listParams({
    required int companyId,
    required UserFiltersEntity filters,
    int? page,
    int? pageSize,
  }) =>
      [
        MapEntry('company_id', '$companyId'),
        if (page != null) MapEntry('pagination[current]', '$page'),
        if (pageSize != null) MapEntry('pagination[pageSize]', '$pageSize'),
        if (filters.search.isNotEmpty) MapEntry('search', filters.search),
        if (filters.estado != null) MapEntry('filters[estado][]', '${filters.estado}'),
        if (filters.role != null) MapEntry('filters[roles.name][]', filters.role!),
      ];

  Uri _uri(String path, {List<MapEntry<String, String>> params = const []}) {
    final base = Uri.parse('${ApiConstants.baseUrl}$path');
    if (params.isEmpty) return base;
    // Los corchetes se arman a mano (`pagination[current]=1`).
    final query = params
        .map((e) => '${Uri.encodeQueryComponent(e.key)}=${Uri.encodeQueryComponent(e.value)}')
        .join('&');
    return base.replace(query: query);
  }

  Future<dynamic> _get(String token, String path, {List<MapEntry<String, String>> params = const []}) =>
      sendApiRequest(() => client.get(_uri(path, params: params), headers: ApiConstants.authHeaders(token)));

  @override
  Future<UserPageEntity> getUsers(
    String token, {
    required int companyId,
    required int page,
    required int pageSize,
    required UserFiltersEntity filters,
  }) async {
    final body = await sendApiRequest(
      () => client.get(
        _uri(
          '/usuarios',
          params: listParams(companyId: companyId, filters: filters, page: page, pageSize: pageSize),
        ),
        headers: ApiConstants.authHeaders(token),
      ),
      // Es una consulta: si la conexión se corta antes de la respuesta, se repite una vez.
      retry: true,
    );
    return userPageFromJson(body as Map<String, dynamic>);
  }

  @override
  Future<UserCatalogsEntity> getCatalogs(String token, {required int companyId}) async {
    final results = await Future.wait([
      _get(token, '/roles/list'),
      _get(token, '/almacenes/list', params: [MapEntry('company_id', '$companyId')]),
      _get(token, '/lista-de-precios/list', params: [MapEntry('company_id', '$companyId')]),
      _get(token, '/metodos-de-pago/list'),
      _get(token, '/usuarios/permisos'),
    ]);
    return UserCatalogsEntity(
      roles: userOptionsFromJson(results[0]),
      warehouses: userOptionsFromJson(results[1]),
      listPrices: userOptionsFromJson(results[2]),
      paymentMethods: userOptionsFromJson(results[3]),
      permissions: userPermissionsFromJson(results[4]),
    );
  }

  @override
  Future<UserRecordEntity> saveUser(
    String token, {
    required int companyId,
    required UserFormEntity form,
    int? id,
  }) async {
    final editing = id != null;
    final body = await sendApiRequest(
      () {
        final uri = _uri('/usuarios${editing ? '/$id' : ''}');
        final headers = ApiConstants.authHeaders(token);
        final data = json.encode(userFormToJson(form, companyId: companyId, editing: editing));
        return editing ? client.put(uri, headers: headers, body: data) : client.post(uri, headers: headers, body: data);
      },
    );
    return userRecordFromJson(body as Map<String, dynamic>);
  }

  @override
  Future<void> uploadPhoto(String token, {required int id, required Uint8List bytes, required String name}) async {
    final uri = _uri('/usuarios/$id/foto');
    await sendApiRequest(() async {
      final request = http.MultipartRequest('POST', uri)
        ..headers.addAll(ApiConstants.authHeaders(token))
        ..files.add(http.MultipartFile.fromBytes('foto', bytes, filename: name));
      return http.Response.fromStream(await client.send(request));
    });
  }

  @override
  Future<Uint8List?> getPhoto(String token, int id) async {
    final bytes = await sendApiBytes(
      () => client.get(_uri('/usuarios/$id/foto'), headers: ApiConstants.authHeaders(token)),
    );
    // Sin foto el servidor responde 204, sin contenido.
    return bytes.isEmpty ? null : bytes;
  }

  @override
  Future<List<UserOption>> getRoles(String token) async => userOptionsFromJson(await _get(token, '/roles/list'));

  @override
  Future<UserOption> saveRole(String token, {required String name, int? id}) async {
    final body = await sendApiRequest(() {
      final uri = _uri('/roles${id == null ? '' : '/$id'}');
      final headers = ApiConstants.authHeaders(token);
      final data = json.encode({'name': name});
      return id == null ? client.post(uri, headers: headers, body: data) : client.put(uri, headers: headers, body: data);
    });
    final roles = userOptionsFromJson([body]);
    if (roles.isEmpty) throw const ServerException('Respuesta inesperada del servidor');
    return roles.first;
  }

  @override
  Future<void> deleteRole(String token, int id) async {
    // Responde 204 sin contenido: no hay JSON que leer.
    await sendApiBytes(() => client.delete(_uri('/roles/$id'), headers: ApiConstants.authHeaders(token)));
  }

  @override
  Future<List<UbigeoItemEntity>> getDepartments(String token) async =>
      ubigeoItemsFromJson(await _get(token, '/ubigeo/search/departments'));

  @override
  Future<List<UbigeoItemEntity>> getProvinces(String token, String departmentId) async =>
      ubigeoItemsFromJson(
        await _get(token, '/ubigeo/search/provinces', params: [MapEntry('department_id', departmentId)]),
      );

  @override
  Future<List<UbigeoItemEntity>> getDistricts(String token, String provinceId) async =>
      ubigeoItemsFromJson(
        await _get(token, '/ubigeo/search/districts', params: [MapEntry('province_id', provinceId)]),
      );
}
