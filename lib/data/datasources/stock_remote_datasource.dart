import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import '../../core/constants/api_constants.dart';
import '../../core/network/api_request.dart';
import '../../domain/entities/product_form_entity.dart';
import '../../domain/entities/other_document_entity.dart';
import '../../domain/entities/stock_entity.dart';
import '../../domain/entities/stock_manage_entity.dart';
import '../models/other_document_model.dart';
import '../models/product_form_model.dart';
import '../models/stock_model.dart';

abstract class StockRemoteDataSource {
  Future<List<CatalogItemEntity>> getWarehouses(String token, int companyId);
  Future<List<PriceListEntity>> getPriceLists(String token, int companyId);
  Future<Uint8List> exportStock({
    required String token,
    required int warehouseId,
    int? priceListId,
    required List<String> search,
  });
  Future<StockPageModel> getStock({
    required String token,
    required int companyId,
    required int warehouseId,
    int? priceListId,
    required List<String> search,
    required bool includeZero,
    required int page,
    required int pageSize,
    String? tipo,
  });

  Future<List<StockProductEntity>> searchProducts(String token, int companyId, String search);

  Future<void> addStock({
    required String token,
    required int warehouseId,
    required List<({int productId, double? costo, int stock})> items,
  });

  Future<Uint8List> downloadStockTemplate(String token);

  Future<StockImportResultEntity> importStock({
    required String token,
    required int companyId,
    required int warehouseId,
    required String fileName,
    required Uint8List bytes,
  });

  Future<OtherDocumentEntity> transferStock({
    required String token,
    required int companyId,
    required int userId,
    required int from,
    required int to,
    required List<({int productId, double cantidad})> items,
  });
}

class StockRemoteDataSourceImpl implements StockRemoteDataSource {
  final http.Client client;

  StockRemoteDataSourceImpl({http.Client? client}) : client = client ?? http.Client();

  Future<dynamic> _get(String token, String path, [Map<String, dynamic>? query]) {
    final uri = Uri.parse('${ApiConstants.baseUrl}$path').replace(queryParameters: query);
    return sendApiRequest(() => client.get(uri, headers: ApiConstants.authHeaders(token)));
  }

  @override
  Future<List<CatalogItemEntity>> getWarehouses(String token, int companyId) async =>
      catalogFromJson(await _get(token, '/almacenes/list', {'company_id': '$companyId'}));

  @override
  Future<List<PriceListEntity>> getPriceLists(String token, int companyId) async =>
      priceListsFromJson(
        await _get(token, '/lista-de-precios/list', {'company_id': '$companyId'}),
      );

  @override
  Future<Uint8List> exportStock({
    required String token,
    required int warehouseId,
    int? priceListId,
    required List<String> search,
  }) {
    // Igual que la web: el Excel trae todos los productos del almacén y solo lo acota la búsqueda.
    final uri = Uri.parse('${ApiConstants.baseUrl}/almacenes/export').replace(queryParameters: {
      'warehouse_id': ['$warehouseId'],
      if (priceListId != null) 'list_price_id': ['$priceListId'],
      if (search.isNotEmpty) 'search[]': search,
    });
    return sendApiBytes(() => client.post(uri, headers: ApiConstants.authHeaders(token)));
  }

  @override
  Future<StockPageModel> getStock({
    required String token,
    required int companyId,
    required int warehouseId,
    int? priceListId,
    required List<String> search,
    required bool includeZero,
    required int page,
    required int pageSize,
    String? tipo,
  }) async {
    // Los mismos parámetros que usa la web en el detalle del almacén.
    final body = await _get(token, '/almacenes/details', {
      'company_id': ['$companyId'],
      'warehouse_id': ['$warehouseId'],
      if (priceListId != null) 'list_price_id': ['$priceListId'],
      if (search.isNotEmpty) 'search[]': search,
      if (includeZero) 'include_0': ['true'],
      // El filtro de la columna "Tipo" de la tabla de la web.
      if (tipo != null) 'filters[tipo][]': [tipo],
      'pagination[current]': ['$page'],
      'pagination[pageSize]': ['$pageSize'],
    });
    return StockPageModel.fromJson(body as Map<String, dynamic>);
  }

  @override
  Future<List<StockProductEntity>> searchProducts(String token, int companyId, String search) async {
    // Los mismos parámetros que el buscador de la web para stock y transferencias.
    final body = await _get(token, '/productos/search', {
      'company_id': '$companyId',
      'search': search,
      'without_defaults': 'true',
    });
    return stockProductsFromJson(body);
  }

  @override
  Future<void> addStock({
    required String token,
    required int warehouseId,
    required List<({int productId, double? costo, int stock})> items,
  }) async {
    final uri = Uri.parse('${ApiConstants.baseUrl}/stock');
    final payload = json.encode({
      'warehouse_id': warehouseId,
      'datos': [
        for (final i in items) {'product_id': i.productId, 'costo': i.costo, 'stock': i.stock},
      ],
    });
    await sendApiRequest(
      () => client.post(uri, headers: ApiConstants.authHeaders(token), body: payload),
    );
  }

  @override
  Future<Uint8List> downloadStockTemplate(String token) {
    // La plantilla de la web: la lista de productos con costo y stock en blanco.
    final uri = Uri.parse('${ApiConstants.baseUrl}/stock/export');
    return sendApiBytes(() => client.post(uri, headers: ApiConstants.authHeaders(token)));
  }

  @override
  Future<StockImportResultEntity> importStock({
    required String token,
    required int companyId,
    required int warehouseId,
    required String fileName,
    required Uint8List bytes,
  }) async {
    final uri = Uri.parse('${ApiConstants.baseUrl}/stock/import');
    final body = await sendApiRequest(() async {
      // Como la web: el Excel en `file`, y el almacén y la empresa como texto, en multipart.
      final request = http.MultipartRequest('POST', uri)
        ..headers.addAll(ApiConstants.authHeaders(token))
        ..fields['warehouse_id'] = '$warehouseId'
        ..fields['company_id'] = '$companyId'
        ..files.add(http.MultipartFile.fromBytes('file', bytes, filename: fileName));
      return http.Response.fromStream(await client.send(request));
    });
    return stockImportResultFromJson(body);
  }

  @override
  Future<OtherDocumentEntity> transferStock({
    required String token,
    required int companyId,
    required int userId,
    required int from,
    required int to,
    required List<({int productId, double cantidad})> items,
  }) async {
    final uri = Uri.parse('${ApiConstants.baseUrl}/stock-transfer');
    final payload = json.encode({
      'from': from,
      'to': to,
      'user_id': userId,
      'company_id': companyId,
      'products': [
        for (final i in items) {'product_id': i.productId, 'cantidad': i.cantidad},
      ],
    });
    final body = await sendApiRequest(
      () => client.post(uri, headers: ApiConstants.authHeaders(token), body: payload),
    );
    return otherDocumentFromJson(body as Map<String, dynamic>, OtherDocumentKind.traslado);
  }
}
