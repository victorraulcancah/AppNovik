import 'package:app_novik/data/datasources/theme_local_datasource.dart';
import 'package:app_novik/presentation/providers/theme_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeThemeStorage implements ThemeLocalDataSource {
  ThemeMode? saved;

  @override
  Future<ThemeMode?> read() async => saved;

  @override
  Future<void> write(ThemeMode mode) async => saved = mode;
}

void main() {
  test('sin preferencia guardada sigue al sistema', () async {
    final provider = ThemeProvider(storage: _FakeThemeStorage());
    await provider.load();

    expect(provider.mode, ThemeMode.system);
  });

  test('carga la preferencia guardada', () async {
    final storage = _FakeThemeStorage()..saved = ThemeMode.dark;
    final provider = ThemeProvider(storage: storage);
    await provider.load();

    expect(provider.mode, ThemeMode.dark);
  });

  test('al elegir un tema lo guarda y notifica', () async {
    final storage = _FakeThemeStorage();
    final provider = ThemeProvider(storage: storage);
    var notified = 0;
    provider.addListener(() => notified++);

    await provider.setMode(ThemeMode.light);

    expect(provider.mode, ThemeMode.light);
    expect(storage.saved, ThemeMode.light);
    expect(notified, 1);
  });
}
