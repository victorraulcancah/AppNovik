import 'package:flutter/material.dart';
import '../../domain/entities/user_entity.dart';
import '../../domain/usecases/auth_usecases.dart';

enum AuthStatus { initial, loading, authenticated, unauthenticated, error }

class AuthProvider extends ChangeNotifier {
  final LoginUseCase _loginUseCase;
  final LogoutUseCase _logoutUseCase;
  final GetLoggedUserUseCase _getLoggedUserUseCase;

  AuthProvider({
    required LoginUseCase loginUseCase,
    required LogoutUseCase logoutUseCase,
    required GetLoggedUserUseCase getLoggedUserUseCase,
  })  : _loginUseCase = loginUseCase,
        _logoutUseCase = logoutUseCase,
        _getLoggedUserUseCase = getLoggedUserUseCase;

  AuthStatus status = AuthStatus.initial;
  UserEntity? user;
  String? errorMessage;

  bool get isAuthenticated => status == AuthStatus.authenticated;

  /// Restaura la sesión guardada en el dispositivo (se llama al abrir la app).
  Future<void> checkAuthStatus() async {
    final result = await _getLoggedUserUseCase();
    result.fold(
      (failure) {
        user = null;
        status = AuthStatus.unauthenticated;
      },
      (logged) {
        user = logged;
        status = logged != null
            ? AuthStatus.authenticated
            : AuthStatus.unauthenticated;
      },
    );
    notifyListeners();
  }

  Future<bool> login(String usuario, String password) async {
    status = AuthStatus.loading;
    errorMessage = null;
    notifyListeners();

    final result = await _loginUseCase(usuario, password);
    final ok = result.fold(
      (failure) {
        errorMessage = failure.message;
        status = AuthStatus.error;
        return false;
      },
      (logged) {
        user = logged;
        status = AuthStatus.authenticated;
        return true;
      },
    );
    notifyListeners();
    return ok;
  }

  Future<void> logout() async {
    await _logoutUseCase();
    user = null;
    errorMessage = null;
    status = AuthStatus.unauthenticated;
    notifyListeners();
  }
}
