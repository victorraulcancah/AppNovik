import 'package:http/http.dart' as http;
import '../../core/constants/api_constants.dart';
import '../../core/network/api_request.dart';
import '../../domain/entities/product_form_entity.dart';
import '../../domain/entities/stock_entity.dart';
import '../models/product_form_model.dart';
import '../models/stock_model.dart';

abstract class StockRemoteDataSource {
  Future<List<CatalogItemEntity>> getWarehouses(String token, int companyId);
  Future<List<PriceListEntity>> getPriceLists(String token, int companyId);
  Future<StockPageModel> getStock({
    required String token,
    required int companyId,
    required int warehouseId,
    int? priceListId,
    required List<String> search,
    required bool includeZero,
    required int page,
    required int pageSize,
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
  Future<StockPageModel> getStock({
    required String token,
    required int companyId,
    required int warehouseId,
    int? priceListId,
    required List<String> search,
    required bool includeZero,
    required int page,
    required int pageSize,
  }) async {
    // Los mismos parámetros que usa la web en el detalle del almacén.
    final body = await _get(token, '/almacenes/details', {
      'company_id': ['$companyId'],
      'warehouse_id': ['$warehouseId'],
      if (priceListId != null) 'list_price_id': ['$priceListId'],
      if (search.isNotEmpty) 'search[]': search,
      if (includeZero) 'include_0': ['true'],
      'pagination[current]': ['$page'],
      'pagination[pageSize]': ['$pageSize'],
    });
    return StockPageModel.fromJson(body as Map<String, dynamic>);
  }
}
