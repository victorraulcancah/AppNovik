/// Credenciales que el usuario pidió recordar en el dispositivo.
class SavedCredentialsEntity {
  final String usuario;
  final String password;

  const SavedCredentialsEntity({required this.usuario, required this.password});
}
