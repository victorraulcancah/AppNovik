import 'dart:async';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Almacenamiento seguro en memoria para las pruebas: cuenta lecturas, escrituras y borrados, y
/// permite retener las escrituras ([writeGate]) para comprobar que algo NO las espera.
class FakeSecureStorage implements FlutterSecureStorage {
  final Map<String, String> values = {};

  int reads = 0;
  int writes = 0;
  int deletes = 0;

  /// Claves cuya escritura ya empezó (aunque no haya terminado).
  final List<String> writesStarted = [];

  /// Mientras exista y no se complete, las escrituras quedan esperando.
  Completer<void>? writeGate;

  /// Hace fallar las escrituras.
  bool failWrites = false;

  @override
  dynamic noSuchMethod(Invocation invocation) {
    final args = invocation.namedArguments;
    switch (invocation.memberName) {
      case #read:
        reads++;
        return Future<String?>.value(values[args[#key] as String]);
      case #write:
        final key = args[#key] as String;
        final value = args[#value] as String?;
        writes++;
        writesStarted.add(key);
        return Future<void>(() async {
          await writeGate?.future;
          if (failWrites) throw StateError('disco lleno');
          if (value == null) {
            values.remove(key);
          } else {
            values[key] = value;
          }
        });
      case #delete:
        deletes++;
        values.remove(args[#key] as String);
        return Future<void>.value();
    }
    return super.noSuchMethod(invocation);
  }
}
