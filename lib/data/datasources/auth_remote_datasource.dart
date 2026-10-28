import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../../core/constants/api_constants.dart';
import '../../core/errors/exceptions.dart';
import '../models/auth_session_model.dart';

abstract class AuthRemoteDataSource {
  Future<AuthSessionModel> login(String usuario, String password);
  Future<void> logout(String token);
}

class AuthRemoteDataSourceImpl implements AuthRemoteDataSource {
  final http.Client client;

  AuthRemoteDataSourceImpl({http.Client? client})
      : client = client ?? http.Client();

  @override
  Future<AuthSessionModel> login(String usuario, String password) async {
    try {
      final response = await client
          .post(
            Uri.parse('${ApiConstants.baseUrl}${ApiConstants.loginEndpoint}'),
            headers: ApiConstants.defaultHeaders,
            body: json.encode({'usuario': usuario, 'password': password}),
          )
          .timeout(ApiConstants.connectionTimeout);

      if (response.statusCode == 200) {
        return AuthSessionModel.fromJson(json.decode(response.body));
      } else if (response.statusCode == 401 || response.statusCode == 422) {
        throw AuthException(_errorMessage(response.body));
      } else if (response.statusCode >= 500) {
        throw const ServerException('Error del servidor');
      } else {
        throw ServerException('Error al iniciar sesión: ${response.statusCode}');
      }
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

  @override
  Future<void> logout(String token) async {
    try {
      await client
          .post(
            Uri.parse('${ApiConstants.baseUrl}${ApiConstants.logoutEndpoint}'),
            headers: ApiConstants.authHeaders(token),
          )
          .timeout(ApiConstants.connectionTimeout);
    } on SocketException {
      throw const NetworkException('Sin conexión a internet');
    } on TimeoutException {
      throw const NetworkException('Tiempo de espera agotado');
    }
  }

  String _errorMessage(String body) {
    try {
      final data = json.decode(body);
      if (data is Map && data['error'] is String) return data['error'];
    } catch (_) {}
    return 'Credenciales incorrectas';
  }
}
