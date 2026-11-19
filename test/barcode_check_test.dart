import 'package:app_novik/core/utils/barcode_check.dart';
import 'package:flutter_test/flutter_test.dart';

/// El dígito de control descarta las lecturas equivocadas de la cámara (un dígito mal leído o un código cortado).
void main() {
  test('EAN-13, UPC-A y EAN-8 con su dígito de control bien son válidos', () {
    expect(isValidGtin('4006381333931'), isTrue); // EAN-13
    expect(isValidGtin('036000291452'), isTrue); // UPC-A
    expect(isValidGtin('96385074'), isTrue); // EAN-8
  });

  test('un dígito mal leído o un largo distinto no es válido', () {
    expect(isValidGtin('4006381333932'), isFalse); // dígito de control mal
    expect(isValidGtin('4006381333391'), isFalse); // dos dígitos cambiados de lugar
    expect(isValidGtin('400638133393'), isFalse); // cortado (12 dígitos que no cuadran)
    expect(isValidGtin('40063813339'), isFalse); // largo que no es de un GTIN
    expect(isValidGtin(''), isFalse);
  });

  test('con letras o símbolos no es un GTIN', () {
    expect(isValidGtin('40063813339A1'), isFalse);
    expect(isValidGtin('4006-3813-3393'), isFalse);
  });
}
