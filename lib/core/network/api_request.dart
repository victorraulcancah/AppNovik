import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../constants/api_constants.dart';
import '../errors/exceptions.dart';

/// Hace una petición a la API de 7power y devuelve el JSON de la respuesta.
/// Traduce los errores del backend y de la red a las excepciones de la app.
Future<dynamic> sendApiRequest(Future<http.Response> Function() request) async {
  try {
    final response = await request().timeout(ApiConstants.connectionTimeout);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return json.decode(response.body);
    } else if (response.statusCode == 401) {
      throw AuthException(apiErrorMessage(response.body) ?? 'Sesión expirada');
    } else if (response.statusCode == 403) {
      throw const ServerException('No tienes permiso para esta acción');
    } else if (response.statusCode == 422 || response.statusCode == 400) {
      throw ValidationException(apiErrorMessage(response.body) ?? 'Datos inválidos');
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
String? apiErrorMessage(String body) {
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
