import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../../core/constants/api_constants.dart';
import '../../core/errors/exceptions.dart';
import '../../core/network/api_request.dart';
import '../../domain/entities/import_entity.dart';
import '../../domain/entities/price_list_entity.dart';
import '../models/price_list_model.dart';

abstract class PriceListRemoteDataSource {
  Future<PriceListPageEntity> getPriceLists(
    String token, {
    required int companyId,
    required int page,
    required int pageSize,
    required PriceListFiltersEntity filters,
  });

  Future<PriceListEntity> savePriceList(
    String token, {
    required int companyId,
    required PriceListFormEntity form,
    int? id,
  });

  Future<PriceListProductPageEntity> getProducts(
    String token, {
    required int listPriceId,
    required int page,
    required int pageSize,
    required PriceListProductFiltersEntity filters,
  });

  Future<PriceListProductEntity> updatePrice(
    String token, {
    required int listPriceId,
    required int productId,
    required double precio,
  });

  Future<Uint8List> exportTemplate(String token, {required int listPriceId});

  Future<ImportResultEntity> importPrices(
    String token, {
    required int listPriceId,
    required int companyId,
    required String fileName,
    required Uint8List bytes,
  });
}

class PriceListRemoteDataSourceImpl implements PriceListRemoteDataSource {
  final http.Client client;

  PriceListRemoteDataSourceImpl({http.Client? client})
    : client = client ?? http.Client();

  /// Lo que manda la web (`/lista-de-precios`): la empresa, la paginación, los términos de búsqueda
  /// (`search[]`, uno por chip) y los filtros de las columnas Moneda y Estado.
  static List<MapEntry<String, String>> listParams({
    required int companyId,
    required int page,
    required int pageSize,
    required PriceListFiltersEntity filters,
  }) => [
    MapEntry('company_id', '$companyId'),
    MapEntry('pagination[current]', '$page'),
    MapEntry('pagination[pageSize]', '$pageSize'),
    for (final term in filters.terms) MapEntry('search[]', term),
    if (filters.currency != null)
      MapEntry('filters[tipo_moneda][]', filters.currency!),
    if (filters.active != null)
      MapEntry('filters[estado][]', '${filters.active}'),
  ];

  /// Lo que manda la web en el detalle (`/lista-de-precios/details`): la lista, la paginación y
  /// la búsqueda (`search[]`) y el filtro de la columna Tipo.
  static List<MapEntry<String, String>> productParams({
    required int listPriceId,
    required int page,
    required int pageSize,
    required PriceListProductFiltersEntity filters,
  }) => [
    MapEntry('list_price_id', '$listPriceId'),
    MapEntry('pagination[current]', '$page'),
    MapEntry('pagination[pageSize]', '$pageSize'),
    if (filters.search.isNotEmpty) MapEntry('search[]', filters.search),
    if (filters.tipo != null) MapEntry('filters[tipo][]', filters.tipo!),
  ];

  Uri _uri(String path, [List<MapEntry<String, String>> params = const []]) {
    final base = Uri.parse('${ApiConstants.baseUrl}$path');
    if (params.isEmpty) return base;
    // Los corchetes se arman a mano (`pagination[current]=1`, `search[]=x`).
    final query = params
        .map(
          (e) =>
              '${Uri.encodeQueryComponent(e.key)}=${Uri.encodeQueryComponent(e.value)}',
        )
        .join('&');
    return base.replace(query: query);
  }

  @override
  Future<PriceListPageEntity> getPriceLists(
    String token, {
    required int companyId,
    required int page,
    required int pageSize,
    required PriceListFiltersEntity filters,
  }) async {
    final body = await sendApiRequest(
      () => client.get(
        _uri(
          '/lista-de-precios',
          listParams(
            companyId: companyId,
            page: page,
            pageSize: pageSize,
            filters: filters,
          ),
        ),
        headers: ApiConstants.authHeaders(token),
      ),
      retry: true,
    );
    return priceListPageFromJson(body as Map<String, dynamic>);
  }

  @override
  Future<PriceListEntity> savePriceList(
    String token, {
    required int companyId,
    required PriceListFormEntity form,
    int? id,
  }) async {
    final payload = jsonEncode({
      'company_id': companyId,
      'name': form.name,
      'estado': form.active,
      // La moneda solo se elige al crear.
      if (id == null) 'tipo_moneda': form.currency,
    });
    try {
      final body = await sendApiRequest(
        () => id == null
            ? client.post(
                _uri('/lista-de-precios/storeOnlyList'),
                headers: ApiConstants.authHeaders(token),
                body: payload,
              )
            : client.put(
                _uri('/lista-de-precios/storeOnlyList/$id'),
                headers: ApiConstants.authHeaders(token),
                body: payload,
              ),
      );
      return priceListFromJson(body as Map<String, dynamic>);
    } on ValidationException catch (e) {
      // Como la web: un nombre repetido en la empresa dice "La lista ya existe".
      if (RegExp(
        r'unique|taken|already|ya (ha sido|existe|está)|en uso',
        caseSensitive: false,
      ).hasMatch(e.message)) {
        throw const ValidationException('La lista ya existe');
      }
      rethrow;
    }
  }

  @override
  Future<PriceListProductPageEntity> getProducts(
    String token, {
    required int listPriceId,
    required int page,
    required int pageSize,
    required PriceListProductFiltersEntity filters,
  }) async {
    final body = await sendApiRequest(
      () => client.get(
        _uri(
          '/lista-de-precios/details',
          productParams(
            listPriceId: listPriceId,
            page: page,
            pageSize: pageSize,
            filters: filters,
          ),
        ),
        headers: ApiConstants.authHeaders(token),
      ),
      retry: true,
    );
    return priceListProductPageFromJson(body as Map<String, dynamic>);
  }

  @override
  Future<PriceListProductEntity> updatePrice(
    String token, {
    required int listPriceId,
    required int productId,
    required double precio,
  }) async {
    final body = await sendApiRequest(
      () => client.patch(
        _uri('/lista-de-precios/$listPriceId'),
        headers: ApiConstants.authHeaders(token),
        body: jsonEncode({'precio': precio, 'product_id': productId}),
      ),
    );
    return priceListProductFromJson(body as Map<String, dynamic>);
  }

  @override
  Future<Uint8List> exportTemplate(String token, {required int listPriceId}) =>
      sendApiBytes(
        () => client.post(
          _uri('/lista-de-precios/$listPriceId/export'),
          headers: ApiConstants.authHeaders(token),
        ),
      );

  @override
  Future<ImportResultEntity> importPrices(
    String token, {
    required int listPriceId,
    required int companyId,
    required String fileName,
    required Uint8List bytes,
  }) async {
    final uri = _uri('/lista-de-precios/$listPriceId/import');
    final body = await sendApiRequest(() async {
      // Como la web: el Excel en `file`, la lista en `list_price_id` y la empresa en `company_id`,
      // en un formulario multipart.
      final request = http.MultipartRequest('POST', uri)
        ..headers.addAll(ApiConstants.authHeaders(token))
        ..fields['list_price_id'] = '$listPriceId'
        ..fields['company_id'] = '$companyId'
        ..files.add(
          http.MultipartFile.fromBytes('file', bytes, filename: fileName),
        );
      return http.Response.fromStream(await client.send(request));
    }, timeout: const Duration(minutes: 3));
    return priceListImportResultFromJson(body);
  }
}
