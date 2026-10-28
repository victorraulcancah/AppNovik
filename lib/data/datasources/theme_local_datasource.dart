import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../core/constants/app_constants.dart';

/// Guarda la preferencia de tema del usuario en el dispositivo.
abstract class ThemeLocalDataSource {
  /// `null` si el usuario nunca eligió (se sigue al sistema).
  Future<ThemeMode?> read();
  Future<void> write(ThemeMode mode);
}

class ThemeLocalDataSourceImpl implements ThemeLocalDataSource {
  final FlutterSecureStorage storage;

  ThemeLocalDataSourceImpl({FlutterSecureStorage? storage})
      : storage = storage ?? const FlutterSecureStorage();

  @override
  Future<ThemeMode?> read() async {
    try {
      final value = await storage.read(key: AppConstants.themeStorageKey);
      for (final mode in ThemeMode.values) {
        if (mode.name == value) return mode;
      }
    } catch (_) {
      // Sin acceso al almacenamiento: se usa el tema del sistema.
    }
    return null;
  }

  @override
  Future<void> write(ThemeMode mode) async {
    try {
      await storage.write(key: AppConstants.themeStorageKey, value: mode.name);
    } catch (_) {
      // La preferencia no se guarda, pero el cambio sigue valiendo esta sesión.
    }
  }
}
