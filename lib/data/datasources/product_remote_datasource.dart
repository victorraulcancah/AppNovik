import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../../core/constants/api_constants.dart';
import '../../core/errors/exceptions.dart';
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

    final body = await _send(() => client.get(uri, headers: ApiConstants.authHeaders(token)));
    return ProductPageModel.fromJson(body as Map<String, dynamic>);
  }

  @override
  Future<ProductCatalogsEntity> getCatalogs(String token) async {
    Future<List<CatalogItemEntity>> list(String path) async {
      final uri = Uri.parse('${ApiConstants.baseUrl}$path');
      final body = await _send(() => client.get(uri, headers: ApiConstants.authHeaders(token)));
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

    final body = await _send(
      () => editing
          ? client.put(uri, headers: headers, body: payload)
          : client.post(uri, headers: headers, body: payload),
    );
    return ProductModel.fromJson(body as Map<String, dynamic>);
  }

  /// Hace la petición y devuelve el JSON; traduce los errores del backend.
  Future<dynamic> _send(Future<http.Response> Function() request) async {
    try {
      final response = await request().timeout(ApiConstants.connectionTimeout);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return json.decode(response.body);
      } else if (response.statusCode == 401) {
        throw AuthException(_message(response.body) ?? 'Sesión expirada');
      } else if (response.statusCode == 403) {
        throw const ServerException('No tienes permiso para esta acción');
      } else if (response.statusCode == 422 || response.statusCode == 400) {
        throw ValidationException(_message(response.body) ?? 'Datos inválidos');
      } else if (response.statusCode >= 500) {
        throw const ServerException('Error del servidor');
      } else {
        throw ServerException('Error de la solicitud: ${response.statusCode}');
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

  /// Mensaje de error del backend: `{"error": {"codigo": ["..."]}}`,
  /// `{"error": "texto"}` o `{"message": "texto"}`.
  String? _message(String body) {
    try {
      final data = json.decode(body);
      if (data is! Map) return null;
      final error = data['error'];
      if (error is String) return error;
      if (error is Map && error.isNotEmpty) {
        final field = error.keys.first.toString();
        final first = error.values.first;
        final text = first is List && first.isNotEmpty ? first.first.toString() : '$first';
        return switch (field) {
          'codigo' => 'El código ya existe',
          'sku' => 'El SKU ya existe',
          'cod_barra' => 'El código de barras ya existe',
          _ => text,
        };
      }
      final message = data['message'];
      if (message is String) return message;
    } catch (_) {}
    return null;
  }
}
