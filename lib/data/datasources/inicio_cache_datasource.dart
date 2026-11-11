import 'dart:convert';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Última respuesta buena de cada vista del Inicio, para mostrarla al instante mientras se pide la
/// nueva. Va en el almacenamiento seguro del teléfono (son cifras de ventas de la empresa).
///
/// - Una sola entrada por vista (`general`, `ejecutivo`, `jefe`, `ceo`): lo último que se vio.
/// - Cada entrada lleva la huella de la sesión (el token) con la que se guardó: con otra sesión no
///   se lee, así nunca se mezclan datos de dos usuarios.
/// - Vence a las 24 horas.
/// - Se borra al cerrar sesión ([clear]).
abstract class InicioCacheDataSource {
  /// El JSON guardado de [view] para esa sesión, o `null` si no hay, venció o es de otra sesión.
  Future<Object?> read(String scope, String view);

  /// Guarda [body] (el JSON ya decodificado de la respuesta).
  Future<void> write(String scope, String view, Object body);

  Future<void> clear();
}

/// Huella corta y estable del token (FNV-1a de 64 bits): sirve para saber de qué sesión es un dato
/// guardado sin dejar el token escrito en otro sitio.
String sessionScope(String token) {
  var hash = 0xcbf29ce484222325;
  for (final unit in token.codeUnits) {
    hash ^= unit;
    hash = (hash * 0x100000001b3) & 0xFFFFFFFFFFFFFFFF;
  }
  return hash.toUnsigned(64).toRadixString(16);
}

class InicioCacheDataSourceImpl implements InicioCacheDataSource {
  static const maxAge = Duration(hours: 24);
  static const views = ['general', 'ejecutivo', 'jefe', 'ceo'];

  final FlutterSecureStorage storage;
  final DateTime Function() _now;

  InicioCacheDataSourceImpl({FlutterSecureStorage? storage, DateTime Function()? now})
    : storage = storage ?? const FlutterSecureStorage(),
      _now = now ?? DateTime.now;

  static String _key(String view) => 'inicio_cache_v1_$view';

  @override
  Future<Object?> read(String scope, String view) async {
    try {
      final raw = await storage.read(key: _key(view));
      if (raw == null) return null;
      final entry = json.decode(raw);
      if (entry is! Map || entry['s'] != scope) return null;
      final savedAt = entry['t'];
      if (savedAt is! int) return null;
      final age = _now().difference(DateTime.fromMillisecondsSinceEpoch(savedAt));
      if (age > maxAge || age.isNegative) return null;
      return entry['d'];
    } catch (e) {
      // La caché es un adelanto: si no se puede leer, se pide normalmente.
      debugPrint('Caché de Inicio ilegible: $e');
      return null;
    }
  }

  @override
  Future<void> write(String scope, String view, Object body) async {
    try {
      await storage.write(
        key: _key(view),
        value: json.encode({'s': scope, 't': _now().millisecondsSinceEpoch, 'd': body}),
      );
    } catch (e) {
      debugPrint('No se pudo guardar la caché de Inicio: $e');
    }
  }

  @override
  Future<void> clear() async {
    try {
      await Future.wait([for (final v in views) storage.delete(key: _key(v))]);
    } catch (e) {
      debugPrint('No se pudo borrar la caché de Inicio: $e');
    }
  }
}
