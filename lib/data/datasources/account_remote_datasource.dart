import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../../core/constants/api_constants.dart';
import '../../core/errors/exceptions.dart';

/// Un error de validación del servidor: el campo al que pertenece (`actual`, `nueva`...) y su texto.
typedef AccountFieldError = ({String field, String message});

abstract class AccountRemoteDataSource {
  /// Cambia la contraseña de quien tiene la sesión (`POST /usuarios/cambiar-password`). Devuelve el
  /// error de validación del servidor, o `null` si se cambió.
  Future<AccountFieldError?> changePassword(
    String token, {
    required String actual,
    required String nueva,
    required String confirmacion,
  });
}

class AccountRemoteDataSourceImpl implements AccountRemoteDataSource {
  final http.Client client;

  AccountRemoteDataSourceImpl({http.Client? client}) : client = client ?? http.Client();

  @override
  Future<AccountFieldError?> changePassword(
    String token, {
    required String actual,
    required String nueva,
    required String confirmacion,
  }) async {
    try {
      final response = await client
          .post(
            Uri.parse('${ApiConstants.baseUrl}/usuarios/cambiar-password'),
            headers: ApiConstants.authHeaders(token),
            // Los mismos nombres que la web: `nueva_confirmation` es la confirmación de Laravel.
            body: json.encode({'actual': actual, 'nueva': nueva, 'nueva_confirmation': confirmacion}),
          )
          .timeout(ApiConstants.connectionTimeout);

      if (response.statusCode >= 200 && response.statusCode < 300) return null;
      if (response.statusCode == 422) return _firstError(response.body);
      if (response.statusCode == 401) throw const AuthException('Sesión expirada');
      if (response.statusCode == 429) {
        throw const ServerException('Demasiados intentos. Espera un minuto e intenta de nuevo.');
      }
      if (response.statusCode >= 500) throw const ServerException('Error del servidor');
      throw ServerException('Error de la solicitud: ${response.statusCode}');
    } on AppException {
      rethrow;
    } on SocketException {
      throw const NetworkException('Sin conexión a internet');
    } on TimeoutException {
      throw const NetworkException('Tiempo de espera agotado');
    } catch (e) {
      throw ServerException('Error de conexión: $e');
    }
  }

  /// `{"message": "...", "errors": {"actual": ["..."]}}` de Laravel: el primer campo con su primer texto.
  AccountFieldError _firstError(String body) {
    try {
      final data = json.decode(body);
      if (data is Map) {
        final errors = data['errors'];
        if (errors is Map && errors.isNotEmpty) {
          final first = errors.values.first;
          final text = first is List && first.isNotEmpty ? '${first.first}' : '$first';
          return (field: '${errors.keys.first}', message: text);
        }
        if (data['message'] is String) return (field: '', message: data['message'] as String);
      }
    } catch (_) {}
    return (field: '', message: 'Datos inválidos');
  }
}
