class ApiConstants {
  /// Dominio raíz del backend (7power). ÚNICO lugar donde se define el host:
  /// el resto de las URLs se derivan de acá.
  /// Se puede sobreescribir al compilar sin tocar código:
  ///   flutter build apk --dart-define=API_DOMAIN=http://192.168.1.10:8000
  /// En producción el backend vive en una subcarpeta (`/7power/public`).
  static const String baseDomain = String.fromEnvironment(
    'API_DOMAIN',
    defaultValue: 'https://novi-k.com/7power/public',
  );

  static const String baseUrl = "$baseDomain/api";

  // Endpoints (routes/api.php de 7power)
  static const String loginEndpoint = '/login';
  static const String logoutEndpoint = '/logout';

  // Timeouts
  static const Duration connectionTimeout = Duration(seconds: 30);
  static const Duration receiveTimeout = Duration(seconds: 30);

  static const Map<String, String> defaultHeaders = {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  };

  /// Headers de una petición autenticada con el token de Sanctum.
  static Map<String, String> authHeaders(String token) => {
        ...defaultHeaders,
        'Authorization': 'Bearer $token',
      };
}
