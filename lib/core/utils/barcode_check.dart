/// ¿Es [code] un GTIN válido (EAN-8, UPC-A o EAN-13) según su dígito de control?
///
/// La cámara a veces lee mal un dígito o corta el código; con el dígito de control se descartan esas lecturas en
/// vez de buscar un producto que no existe. Cualquier otro largo o un texto con letras no es un GTIN: `false`.
bool isValidGtin(String code) {
  if (!RegExp(r'^\d+$').hasMatch(code)) return false;
  if (code.length != 8 && code.length != 12 && code.length != 13) return false;

  final digits = [for (final c in code.split('')) int.parse(c)];
  final check = digits.removeLast();
  var sum = 0;
  // De derecha a izquierda (sin el dígito de control): el primero pesa 3, el siguiente 1, y así.
  for (var i = 0; i < digits.length; i++) {
    final fromRight = digits.length - 1 - i;
    sum += digits[i] * (fromRight.isEven ? 3 : 1);
  }
  return (10 - sum % 10) % 10 == check;
}
