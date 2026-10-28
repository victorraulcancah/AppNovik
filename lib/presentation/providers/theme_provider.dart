import 'package:flutter/material.dart';
import '../../data/datasources/theme_local_datasource.dart';

/// Tema elegido por el usuario: claro, oscuro o "a modo del sistema".
class ThemeProvider extends ChangeNotifier {
  final ThemeLocalDataSource _storage;

  ThemeProvider({required ThemeLocalDataSource storage}) : _storage = storage;

  ThemeMode mode = ThemeMode.system;

  /// Lee la preferencia guardada (se llama al abrir la app).
  Future<void> load() async {
    final saved = await _storage.read();
    if (saved != null && saved != mode) {
      mode = saved;
      notifyListeners();
    }
  }

  Future<void> setMode(ThemeMode value) async {
    if (value == mode) return;
    mode = value;
    notifyListeners();
    await _storage.write(value);
  }
}
