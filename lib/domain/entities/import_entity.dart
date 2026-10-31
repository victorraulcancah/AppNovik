/// Qué se sube con una importación masiva de Excel.
enum ImportKind {
  productos('Productos'),
  marcas('Marcas'),
  categorias('Categorías');

  final String label;
  const ImportKind(this.label);
}

/// Una fila del Excel que el servidor no pudo importar y por qué.
class ImportFailureEntity {
  final int row;
  final List<String> errors;

  const ImportFailureEntity({required this.row, required this.errors});
}

/// Respuesta del servidor a una importación: las filas con error no frenan al resto.
class ImportResultEntity {
  final String message;
  final List<ImportFailureEntity> failures;

  const ImportResultEntity({this.message = 'Importación exitosa', this.failures = const []});

  bool get hasFailures => failures.isNotEmpty;
}
