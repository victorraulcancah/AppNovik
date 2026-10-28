class AppConstants {
  // App Info
  static const String appName = 'Novik';

  // Storage Keys
  static const String tokenStorageKey = 'auth_token_v1';
  static const String userStorageKey = 'auth_user_v1';
  static const String savedUsuarioKey = 'saved_usuario_v1';
  static const String savedPasswordKey = 'saved_password_v1';

  // Pagination
  static const int defaultPageSize = 20;

  // UI Constants
  static const double defaultBorderRadius = 12.0;
  static const double defaultPadding = 16.0;

  /// Ancho a partir del cual se usa el layout de tablet.
  static const double tabletBreakpoint = 600;

  // Validation
  static const int minPasswordLength = 4;

  // Date Formats
  static const String dateFormat = 'dd/MM/yyyy';
  static const String dateTimeFormat = 'dd/MM/yyyy HH:mm';
}
