import '../../domain/entities/user_entity.dart';

class UserModel extends UserEntity {
  const UserModel({
    required super.id,
    required super.name,
    required super.usuario,
    super.email,
    super.telefono,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] as int,
      name: (json['name'] ?? '') as String,
      usuario: (json['usuario'] ?? '') as String,
      email: json['email'] as String?,
      telefono: json['telefono'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'usuario': usuario,
        'email': email,
        'telefono': telefono,
      };
}
