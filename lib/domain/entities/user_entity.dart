class UserEntity {
  final int id;
  final String name;
  final String usuario;
  final String? email;
  final String? telefono;

  /// Roles y empresa tal como los devuelve `POST /login` (el contexto completo llega con `/auth`).
  /// Sirven para adelantar trabajo mientras `/auth` responde; vacíos si no vienen.
  final List<String> roles;
  final int? companyId;

  const UserEntity({
    required this.id,
    required this.name,
    required this.usuario,
    this.email,
    this.telefono,
    this.roles = const [],
    this.companyId,
  });
}
