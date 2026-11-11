import '../../domain/entities/user_entity.dart';

class UserModel extends UserEntity {
  const UserModel({
    required super.id,
    required super.name,
    required super.usuario,
    super.email,
    super.telefono,
    super.roles,
    super.companyId,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] as int,
      name: (json['name'] ?? '') as String,
      usuario: (json['usuario'] ?? '') as String,
      email: json['email'] as String?,
      telefono: json['telefono'] as String?,
      roles: _roles(json['roles']),
      companyId: _companyId(json),
    );
  }

  /// `roles` llega como lista de `{name: ...}` (o de textos).
  static List<String> _roles(Object? raw) {
    if (raw is! List) return const [];
    return [
      for (final r in raw)
        if (r is Map && r['name'] is String && (r['name'] as String).isNotEmpty)
          r['name'] as String
        else if (r is String && r.isNotEmpty)
          r,
    ];
  }

  static int? _companyId(Map<String, dynamic> json) {
    final direct = json['company_id'];
    if (direct is int) return direct;
    if (direct is String) return int.tryParse(direct);
    final company = json['company'];
    if (company is Map && company['id'] is int) return company['id'] as int;
    return null;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'usuario': usuario,
        'email': email,
        'telefono': telefono,
      };
}
