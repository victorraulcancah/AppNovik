import 'package:flutter/material.dart';

import '../pages/barcode_scan_page.dart';

/// Escanear un código de barras con la cámara. Devuelve el código leído o `null` si se cerró sin
/// leer nada. [scan] se puede cambiar en las pruebas (la cámara no corre en ellas).
class BarcodeScanner {
  BarcodeScanner._();

  static Future<String?> Function(BuildContext context) scan = _open;

  static Future<String?> _open(BuildContext context) => Navigator.of(context).push<String>(
        MaterialPageRoute(fullscreenDialog: true, builder: (_) => const BarcodeScanPage()),
      );
}
