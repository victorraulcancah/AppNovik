class UserEntity {
  final int id;
  final String name;
  final String usuario;
  final String? email;
  final String? telefono;

  const UserEntity({
    required this.id,
    required this.name,
    required this.usuario,
    this.email,
    this.telefono,
  });
}
