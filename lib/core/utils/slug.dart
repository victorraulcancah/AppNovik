/// Replica `convertToSlug()` de 7power: el permiso de un módulo es `<slug>.index`
/// (por ejemplo "Estado de Cuenta" -> "estado-de-cuenta").
String toSlug(String name) {
  const accents = {
    'á': 'a', 'é': 'e', 'í': 'i', 'ó': 'o', 'ú': 'u', 'ü': 'u', 'ñ': 'n',
  };
  var value = name.toLowerCase();
  accents.forEach((from, to) => value = value.replaceAll(from, to));
  return value
      .replaceAll(RegExp(r'[^\w\s-]'), '')
      .trim()
      .replaceAll(RegExp(r'\s+'), '-')
      .replaceAll(RegExp(r'-+'), '-');
}
