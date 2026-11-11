import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../core/constants/app_constants.dart';
import '../../core/errors/exceptions.dart';
import '../../domain/entities/saved_credentials_entity.dart';
import '../models/user_model.dart';

abstract class AuthLocalDataSource {
  Future<void> saveSession(String token, UserModel user);
  Future<String?> getToken();
  Future<UserModel?> getUser();
  Future<void> clear();

  Future<SavedCredentialsEntity?> getSavedCredentials();
  Future<void> saveCredentials(String usuario, String password);
  Future<void> clearSavedCredentials();
}

class AuthLocalDataSourceImpl implements AuthLocalDataSource {
  final FlutterSecureStorage storage;

  AuthLocalDataSourceImpl({FlutterSecureStorage? storage})
      : storage = storage ?? const FlutterSecureStorage();

  /// El token se lee del almacenamiento seguro una sola vez y luego vive en memoria: cada
  /// petición a la API lo pide y cada lectura cuesta una ida al cifrado del teléfono. Por eso esta
  /// clase debe ser una sola instancia para toda la app (ver `DependencyInjection`).
  String? _token;
  bool _tokenKnown = false;

  /// Escritura de la sesión en curso; `clear()` la espera para que un cierre de sesión inmediato
  /// no deje el token guardado después de borrarlo.
  Future<void>? _saving;

  @override
  Future<void> saveSession(String token, UserModel user) {
    // Desde aquí las peticiones ya usan el token nuevo, aunque el disco termine después.
    _token = token;
    _tokenKnown = true;
    final write = _write(token, user);
    _saving = write;
    return write;
  }

  Future<void> _write(String token, UserModel user) async {
    try {
      // Las dos escrituras van juntas: no dependen una de la otra.
      await Future.wait([
        storage.write(key: AppConstants.tokenStorageKey, value: token),
        storage.write(
          key: AppConstants.userStorageKey,
          value: json.encode(user.toJson()),
        ),
      ]);
    } catch (e) {
      throw CacheException('No se pudo guardar la sesión: $e');
    }
  }

  @override
  Future<String?> getToken() async {
    if (_tokenKnown) return _token;
    try {
      final stored = await storage.read(key: AppConstants.tokenStorageKey);
      _token = stored;
      _tokenKnown = true;
      return stored;
    } catch (e) {
      throw CacheException('No se pudo leer la sesión: $e');
    }
  }

  @override
  Future<UserModel?> getUser() async {
    try {
      final raw = await storage.read(key: AppConstants.userStorageKey);
      if (raw == null) return null;
      return UserModel.fromJson(json.decode(raw));
    } catch (e) {
      throw CacheException('No se pudo leer la sesión: $e');
    }
  }

  @override
  Future<void> clear() async {
    _token = null;
    _tokenKnown = true;
    try {
      // Si el login todavía está guardando en segundo plano, primero termina (y su error no importa).
      await _saving?.catchError((Object _) {});
      await Future.wait([
        storage.delete(key: AppConstants.tokenStorageKey),
        storage.delete(key: AppConstants.userStorageKey),
      ]);
    } catch (e) {
      throw CacheException('No se pudo cerrar la sesión: $e');
    }
  }

  @override
  Future<SavedCredentialsEntity?> getSavedCredentials() async {
    try {
      final usuario = await storage.read(key: AppConstants.savedUsuarioKey);
      final password = await storage.read(key: AppConstants.savedPasswordKey);
      if (usuario == null || password == null) return null;
      return SavedCredentialsEntity(usuario: usuario, password: password);
    } catch (e) {
      throw CacheException('No se pudieron leer las credenciales: $e');
    }
  }

  @override
  Future<void> saveCredentials(String usuario, String password) async {
    try {
      await storage.write(key: AppConstants.savedUsuarioKey, value: usuario);
      await storage.write(key: AppConstants.savedPasswordKey, value: password);
    } catch (e) {
      throw CacheException('No se pudieron guardar las credenciales: $e');
    }
  }

  @override
  Future<void> clearSavedCredentials() async {
    try {
      await storage.delete(key: AppConstants.savedUsuarioKey);
      await storage.delete(key: AppConstants.savedPasswordKey);
    } catch (e) {
      throw CacheException('No se pudieron borrar las credenciales: $e');
    }
  }
}
