import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../core/constants/api_constants.dart';
import '../../core/network/api_request.dart';
import '../../domain/entities/product_form_entity.dart';
import '../models/product_form_model.dart';
import '../models/product_model.dart';

abstract class ProductRemoteDataSource {
  Future<ProductPageModel> getProducts({
    required String token,
    required int companyId,
    required int page,
    required int pageSize,
    required List<String> search,
    String? tipo,
  });

  Future<ProductCatalogsEntity> getCatalogs(String token);

  Future<ProductModel> saveProduct({
    required String token,
    required int companyId,
    required ProductFormEntity form,
    int? id,
  });
}

class ProductRemoteDataSourceImpl implements ProductRemoteDataSource {
  final http.Client client;

  ProductRemoteDataSourceImpl({http.Client? client})
      : client = client ?? http.Client();

  @override
  Future<ProductPageModel> getProducts({
    required String token,
    required int companyId,
    required int page,
    required int pageSize,
    required List<String> search,
    String? tipo,
  }) async {
    // Mismos parámetros que usa la web (`/productos`).
    final uri = Uri.parse('${ApiConstants.baseUrl}${ApiConstants.productosEndpoint}')
        .replace(queryParameters: {
      'company_id': ['$companyId'],
      'pagination[current]': ['$page'],
      'pagination[pageSize]': ['$pageSize'],
      if (search.isNotEmpty) 'search[]': search,
      if (tipo != null) 'tipo_producto': [tipo],
    });

    final body = await sendApiRequest(
      () => client.get(uri, headers: ApiConstants.authHeaders(token)),
    );
    return ProductPageModel.fromJson(body as Map<String, dynamic>);
  }

  @override
  Future<ProductCatalogsEntity> getCatalogs(String token) async {
    Future<List<CatalogItemEntity>> list(String path) async {
      final uri = Uri.parse('${ApiConstants.baseUrl}$path');
      final body = await sendApiRequest(
        () => client.get(uri, headers: ApiConstants.authHeaders(token)),
      );
      return catalogFromJson(body);
    }

    final results = await Future.wait([
      list('/marcas'),
      list('/categorias'),
      list('/medidas/list'),
      list('/proveedores/list'),
      list('/canales'),
      list('/giros-negocio'),
    ]);
    return ProductCatalogsEntity(
      marcas: results[0],
      categorias: results[1],
      medidas: results[2],
      proveedores: results[3],
      canales: results[4],
      giros: results[5],
    );
  }

  @override
  Future<ProductModel> saveProduct({
    required String token,
    required int companyId,
    required ProductFormEntity form,
    int? id,
  }) async {
    final editing = id != null;
    final uri = Uri.parse(
      '${ApiConstants.baseUrl}${ApiConstants.productosEndpoint}${editing ? '/$id' : ''}',
    );
    final payload = json.encode(form.toJson(companyId: companyId, editing: editing));
    final headers = ApiConstants.authHeaders(token);

    final body = await sendApiRequest(
      () => editing
          ? client.put(uri, headers: headers, body: payload)
          : client.post(uri, headers: headers, body: payload),
    );
    return ProductModel.fromJson(body as Map<String, dynamic>);
  }
}
