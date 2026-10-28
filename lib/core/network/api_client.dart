import 'dart:io';
import 'package:http/http.dart' as http;
import '../constants/api_constants.dart';
import '../errors/exceptions.dart';

class NetworkInfo {
  static Future<bool> get isConnected async {
    try {
      final result = await InternetAddress.lookup('google.com');
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } on SocketException catch (_) {
      return false;
    }
  }
}

class ApiClient {
  final http.Client _client;

  ApiClient({http.Client? client}) : _client = client ?? http.Client();

  Future<http.Response> get(
    String endpoint, {
    Map<String, String>? headers,
    Map<String, String>? queryParameters,
  }) async {
    if (!await NetworkInfo.isConnected) {
      throw const NetworkException('Sin conexión a internet');
    }

    final uri = _buildUri(endpoint, queryParameters);
    final mergedHeaders = {...ApiConstants.defaultHeaders, ...?headers};

    try {
      final response = await _client
          .get(uri, headers: mergedHeaders)
          .timeout(ApiConstants.connectionTimeout);

      return _handleResponse(response);
    } catch (e) {
      throw _handleError(e);
    }
  }

  Future<http.Response> post(
    String endpoint, {
    Map<String, String>? headers,
    dynamic body,
  }) async {
    if (!await NetworkInfo.isConnected) {
      throw const NetworkException('Sin conexión a internet');
    }

    final uri = _buildUri(endpoint);
    final mergedHeaders = {...ApiConstants.defaultHeaders, ...?headers};

    try {
      final response = await _client
          .post(uri, headers: mergedHeaders, body: body)
          .timeout(ApiConstants.connectionTimeout);

      return _handleResponse(response);
    } catch (e) {
      throw _handleError(e);
    }
  }

  Uri _buildUri(String endpoint, [Map<String, String>? queryParameters]) {
    final fullUrl = ApiConstants.baseUrl + endpoint;

    if (queryParameters != null && queryParameters.isNotEmpty) {
      return Uri.parse(fullUrl).replace(queryParameters: queryParameters);
    }

    return Uri.parse(fullUrl);
  }

  http.Response _handleResponse(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return response;
    } else if (response.statusCode == 401) {
      throw const AuthException('Sesión expirada');
    } else if (response.statusCode >= 400 && response.statusCode < 500) {
      throw ServerException('Error del cliente: ${response.statusCode}');
    } else if (response.statusCode >= 500) {
      throw ServerException('Error del servidor: ${response.statusCode}');
    } else {
      throw ServerException('Error desconocido: ${response.statusCode}');
    }
  }

  Exception _handleError(dynamic error) {
    if (error is AppException) {
      return error;
    } else if (error is SocketException) {
      return const NetworkException('Error de conexión');
    } else if (error is HttpException) {
      return NetworkException('Error HTTP: ${error.message}');
    } else {
      return AppException('Error inesperado: $error');
    }
  }

  void dispose() {
    _client.close();
  }
}
