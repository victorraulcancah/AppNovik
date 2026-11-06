import 'package:flutter/foundation.dart';

/// Recuerda si la última petición a la API falló por falta de conexión. La app lo muestra
/// como un aviso arriba (`AppConnectionBanner`) y se apaga solo con la siguiente respuesta
/// del servidor, sea cual sea.
class ConnectionMonitor {
  ConnectionMonitor._();

  static final ValueNotifier<bool> offline = ValueNotifier<bool>(false);

  static void reachedServer() {
    if (offline.value) offline.value = false;
  }

  static void lostConnection() {
    if (!offline.value) offline.value = true;
  }
}
