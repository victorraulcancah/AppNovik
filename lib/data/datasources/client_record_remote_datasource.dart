import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import '../../core/constants/api_constants.dart';
import '../../core/network/api_request.dart';
import '../../domain/entities/client_record_entity.dart';
import '../models/client_record_model.dart';

abstract class ClientRecordRemoteDataSource {
  Future<ClientPageEntity> getClients(
    String token, {
    required int companyId,
    required int page,
    required int pageSize,
    required ClientFiltersEntity filters,
  });

  Future<ClientFilterCatalogsEntity> getFilterCatalogs(String token);

  Future<ClientFormCatalogsEntity> getFormCatalogs(String token, {required int companyId});

  Future<ClientRecordEntity> saveClient(
    String token, {
    required int companyId,
    required ClientFormEntity form,
    int? id,
  });

  Future<Uint8List> exportClients(
    String token, {
    required int companyId,
    required ClientFiltersEntity filters,
  });

  Future<CategoriesConfigEntity> getCategories(String token);

  /// Devuelve el recálculo si el cambio de ciclo lo disparó.
  Future<CategoryCalcEntity?> saveCategories(
    String token, {
    required List<ClientCategoryEntity> categorias,
    required String ciclo,
  });

  Future<CategoryCalcEntity> calculateCategories(String token, {required String ciclo});
}

/// Roles que pueden ser ejecutivo comercial de un cliente (los mismos que acepta la web).
const clientExecutiveRoles = ['Vendedor', 'Ceo Empresa'];

class ClientRecordRemoteDataSourceImpl implements ClientRecordRemoteDataSource {
  final http.Client client;

  ClientRecordRemoteDataSourceImpl({http.Client? client}) : client = client ?? http.Client();

  /// Parámetros de la lista: los mismos que arma la web (`company_id`, `pagination[...]`,
  /// `search[]`, `filters[columna][]`).
  static List<MapEntry<String, String>> listParams({
    required int companyId,
    required ClientFiltersEntity filters,
    int? page,
    int? pageSize,
  }) =>
      [
        MapEntry('company_id', '$companyId'),
        if (page != null) MapEntry('pagination[current]', '$page'),
        if (pageSize != null) MapEntry('pagination[pageSize]', '$pageSize'),
        for (final term in filters.search) MapEntry('search[]', term),
        if (filters.tipo != null) MapEntry('filters[tipo][]', filters.tipo!),
        if (filters.estado != null) MapEntry('filters[estado][]', '${filters.estado}'),
        for (final c in filters.categorias) MapEntry('filters[categoria_cliente_id][]', c),
        for (final e in filters.ejecutivos) MapEntry('filters[ejecutivo_comercial_id][]', e),
        for (final d in filters.departamentos) MapEntry('filters[department_id][]', d),
      ];

  Uri _uri(String path, {List<MapEntry<String, String>> params = const []}) {
    final base = Uri.parse('${ApiConstants.baseUrl}$path');
    if (params.isEmpty) return base;
    // Los corchetes y las repeticiones (`search[]=a&search[]=b`) se arman a mano.
    final query = params
        .map((e) => '${Uri.encodeQueryComponent(e.key)}=${Uri.encodeQueryComponent(e.value)}')
        .join('&');
    return base.replace(query: query);
  }

  Future<dynamic> _get(String token, String path, {List<MapEntry<String, String>> params = const []}) =>
      sendApiRequest(() => client.get(_uri(path, params: params), headers: ApiConstants.authHeaders(token)));

  @override
  Future<ClientPageEntity> getClients(
    String token, {
    required int companyId,
    required int page,
    required int pageSize,
    required ClientFiltersEntity filters,
  }) async {
    final body = await _get(
      token,
      '/clientes',
      params: listParams(companyId: companyId, filters: filters, page: page, pageSize: pageSize),
    );
    return clientPageFromJson(body as Map<String, dynamic>);
  }

  @override
  Future<ClientFilterCatalogsEntity> getFilterCatalogs(String token) async {
    final results = await Future.wait([
      _get(token, '/clientes/categorias'),
      _get(token, '/clientes/ejecutivos'),
      _get(token, '/clientes/ubicaciones'),
    ]);
    return clientFilterCatalogsFromJson(
      categorias: results[0],
      ejecutivos: results[1],
      ubicaciones: results[2],
    );
  }

  @override
  Future<ClientFormCatalogsEntity> getFormCatalogs(String token, {required int companyId}) async {
    final results = await Future.wait([
      _get(token, '/usuarios/list', params: [
        MapEntry('company_id', '$companyId'),
        for (var i = 0; i < clientExecutiveRoles.length; i++) MapEntry('roles[$i]', clientExecutiveRoles[i]),
      ]),
      _get(token, '/lista-de-precios/list', params: [MapEntry('company_id', '$companyId')]),
      _get(token, '/metodos-de-pago/list'),
      _get(token, '/categorias-cliente'),
    ]);
    final categories = categoriesConfigFromJson(results[3] as Map<String, dynamic>);
    return ClientFormCatalogsEntity(
      ejecutivos: clientOptionsFromJson(results[0]),
      listasDePrecios: clientOptionsFromJson(results[1]),
      metodosDePago: clientOptionsFromJson(results[2]),
      categorias: categories.categorias,
    );
  }

  @override
  Future<ClientRecordEntity> saveClient(
    String token, {
    required int companyId,
    required ClientFormEntity form,
    int? id,
  }) async {
    final editing = id != null;
    final uri = _uri(editing ? '/clientes/$id' : '/clientes');
    final payload = json.encode(clientFormToJson(form, companyId: companyId, editing: editing));
    final body = await sendApiRequest(
      () => editing
          ? client.put(uri, headers: ApiConstants.authHeaders(token), body: payload)
          : client.post(uri, headers: ApiConstants.authHeaders(token), body: payload),
    );
    return clientRecordFromJson(body as Map<String, dynamic>);
  }

  @override
  Future<Uint8List> exportClients(
    String token, {
    required int companyId,
    required ClientFiltersEntity filters,
  }) =>
      sendApiBytes(
        () => client.post(
          _uri('/clientes/export', params: listParams(companyId: companyId, filters: filters)),
          headers: ApiConstants.authHeaders(token),
        ),
      );

  @override
  Future<CategoriesConfigEntity> getCategories(String token) async =>
      categoriesConfigFromJson(await _get(token, '/categorias-cliente') as Map<String, dynamic>);

  @override
  Future<CategoryCalcEntity?> saveCategories(
    String token, {
    required List<ClientCategoryEntity> categorias,
    required String ciclo,
  }) async {
    for (final c in categorias) {
      await sendApiRequest(
        () => client.put(
          _uri('/categorias-cliente/${c.id}'),
          headers: ApiConstants.authHeaders(token),
          body: json.encode({
            'nombre': c.nombre,
            'rangos': {
              for (final e in c.rangos.entries) e.key: {'desde': e.value.desde, 'hasta': e.value.hasta},
            },
          }),
        ),
      );
    }
    // El ciclo se guarda al final: si cambió, el backend pone a regir los rangos de ese ciclo
    // y recalcula las categorías en ese momento.
    final body = await sendApiRequest(
      () => client.post(
        _uri('/categorias-cliente/ciclo'),
        headers: ApiConstants.authHeaders(token),
        body: json.encode({'tipo': ciclo}),
      ),
    );
    final calculo = body is Map ? body['calculo'] : null;
    return calculo == null ? null : categoryCalcFromJson(calculo);
  }

  @override
  Future<CategoryCalcEntity> calculateCategories(String token, {required String ciclo}) async {
    await sendApiRequest(
      () => client.post(
        _uri('/categorias-cliente/ciclo'),
        headers: ApiConstants.authHeaders(token),
        body: json.encode({'tipo': ciclo}),
      ),
    );
    final body = await sendApiRequest(
      () => client.post(_uri('/categorias-cliente/recalcular'), headers: ApiConstants.authHeaders(token)),
    );
    return categoryCalcFromJson(body);
  }
}
