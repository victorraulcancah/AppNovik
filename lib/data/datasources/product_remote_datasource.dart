import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../../core/constants/api_constants.dart';
import '../../core/errors/exceptions.dart';
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

    try {
      final response = await client
          .get(uri, headers: ApiConstants.authHeaders(token))
          .timeout(ApiConstants.connectionTimeout);

      if (response.statusCode == 200) {
        return ProductPageModel.fromJson(json.decode(response.body));
      } else if (response.statusCode == 401) {
        throw const AuthException('Sesión expirada');
      } else if (response.statusCode == 403) {
        throw const ServerException('No tienes permiso para ver productos');
      } else if (response.statusCode >= 500) {
        throw const ServerException('Error del servidor');
      } else {
        throw ServerException('Error al cargar productos: ${response.statusCode}');
      }
    } on AppException {
      rethrow;
    } on SocketException {
      throw const NetworkException('Sin conexión a internet');
    } on TimeoutException {
      throw const NetworkException('Tiempo de espera agotado');
    } on FormatException catch (e) {
      throw ServerException('Respuesta inválida del servidor: ${e.message}');
    } catch (e) {
      throw ServerException('Error de conexión: $e');
    }
  }
}
