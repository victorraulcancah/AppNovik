import 'user_model.dart';

/// Respuesta de `POST /login`: token de Sanctum + usuario.
class AuthSessionModel {
  final String token;
  final UserModel user;

  const AuthSessionModel({required this.token, required this.user});

  factory AuthSessionModel.fromJson(Map<String, dynamic> json) {
    return AuthSessionModel(
      token: json['token'] as String,
      user: UserModel.fromJson(json['user'] as Map<String, dynamic>),
    );
  }
}
