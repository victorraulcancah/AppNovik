import 'package:flutter/material.dart';
import '../../core/errors/failures.dart';
import '../../domain/entities/saved_credentials_entity.dart';
import '../../domain/entities/session_context_entity.dart';
import '../../domain/entities/user_entity.dart';
import '../../domain/usecases/auth_usecases.dart';

enum AuthStatus {
  initial,
  loading,
  authenticated,
  unauthenticated,
  error,

  /// Hay token pero no se pudo cargar el contexto (sin red, servidor caído).
  contextError,
}

class AuthProvider extends ChangeNotifier {
  final LoginUseCase _loginUseCase;
  final LogoutUseCase _logoutUseCase;
  final GetSessionContextUseCase _getSessionContextUseCase;
  final GetSavedCredentialsUseCase _getSavedCredentialsUseCase;
  final SaveCredentialsUseCase _saveCredentialsUseCase;
  final ClearSavedCredentialsUseCase _clearSavedCredentialsUseCase;

  AuthProvider({
    required LoginUseCase loginUseCase,
    required LogoutUseCase logoutUseCase,
    required GetSessionContextUseCase getSessionContextUseCase,
    required GetSavedCredentialsUseCase getSavedCredentialsUseCase,
    required SaveCredentialsUseCase saveCredentialsUseCase,
    required ClearSavedCredentialsUseCase clearSavedCredentialsUseCase,
  })  : _loginUseCase = loginUseCase,
        _logoutUseCase = logoutUseCase,
        _getSessionContextUseCase = getSessionContextUseCase,
        _getSavedCredentialsUseCase = getSavedCredentialsUseCase,
        _saveCredentialsUseCase = saveCredentialsUseCase,
        _clearSavedCredentialsUseCase = clearSavedCredentialsUseCase;

  AuthStatus status = AuthStatus.initial;
  UserEntity? user;

  /// Empresa, módulos y permisos del usuario. Solo existe con sesión iniciada.
  SessionContextEntity? session;
  String? errorMessage;
  SavedCredentialsEntity? savedCredentials;

  bool get isAuthenticated => status == AuthStatus.authenticated;

  /// Restaura la sesión guardada y vuelve a pedir el contexto al backend, de modo
  /// que los módulos y permisos siempre estén al día (se llama al abrir la app).
  Future<void> checkAuthStatus() async {
    final result = await _getSessionContextUseCase();
    result.fold(
      (failure) {
        _clearSession();
        if (failure is AuthenticationFailure) {
          status = AuthStatus.unauthenticated;
        } else {
          errorMessage = failure.message;
          status = AuthStatus.contextError;
        }
      },
      (context) {
        if (context == null) {
          _clearSession();
          status = AuthStatus.unauthenticated;
        } else {
          _setSession(context);
        }
      },
    );
    notifyListeners();
  }

  /// Reintenta cargar el contexto tras un error de red.
  Future<void> retryContext() async {
    status = AuthStatus.initial;
    errorMessage = null;
    notifyListeners();
    await checkAuthStatus();
  }

  /// Carga las credenciales recordadas para rellenar el formulario de login.
  Future<void> loadSavedCredentials() async {
    final result = await _getSavedCredentialsUseCase();
    savedCredentials = result.fold((_) => null, (saved) => saved);
    notifyListeners();
  }

  /// [remember] guarda las credenciales en el dispositivo; si es `false`, borra las guardadas.
  Future<bool> login(
    String usuario,
    String password, {
    required bool remember,
  }) async {
    status = AuthStatus.loading;
    errorMessage = null;
    notifyListeners();

    final loginResult = await _loginUseCase(usuario, password);
    if (loginResult.isLeft) {
      errorMessage = loginResult.left.message;
      status = AuthStatus.error;
      notifyListeners();
      return false;
    }

    // Con el token guardado, se carga la empresa y los módulos del usuario.
    final contextResult = await _getSessionContextUseCase();
    final context = contextResult.fold((_) => null, (c) => c);
    if (context == null) {
      errorMessage = contextResult.fold(
        (failure) => failure.message,
        (_) => 'No se pudo cargar tu sesión',
      );
      await _logoutUseCase();
      _clearSession();
      status = AuthStatus.error;
      notifyListeners();
      return false;
    }

    if (remember) {
      await _saveCredentialsUseCase(usuario, password);
    } else {
      await _clearSavedCredentialsUseCase();
      savedCredentials = null;
    }

    _setSession(context);
    notifyListeners();
    return true;
  }

  Future<void> logout() async {
    await _logoutUseCase();
    _clearSession();
    errorMessage = null;
    status = AuthStatus.unauthenticated;
    notifyListeners();
  }

  void _setSession(SessionContextEntity context) {
    session = context;
    user = context.user;
    errorMessage = null;
    status = AuthStatus.authenticated;
  }

  /// Descarta todo lo de la empresa anterior para no mezclar datos entre cuentas.
  void _clearSession() {
    session = null;
    user = null;
  }
}
