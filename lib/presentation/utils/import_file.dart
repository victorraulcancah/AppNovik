import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart' show rootBundle;

import '../../domain/entities/document_entity.dart' show DownloadedFile;
import '../../domain/entities/import_entity.dart';

/// Un Excel elegido del dispositivo para subirlo.
typedef PickedImportFile = ({String name, Uint8List bytes});

/// Abre el selector de archivos del sistema (solo Excel `.xlsx`, lo único que acepta el
/// servidor). Devuelve `null` si se cancela.
Future<PickedImportFile?> pickImportFile() async {
  final file = await FilePicker.pickFile(
    type: FileType.custom,
    allowedExtensions: const ['xlsx'],
  );
  if (file == null) return null;
  return (name: file.name, bytes: await file.readAsBytes());
}

/// Las mismas plantillas que descarga la web (`docs/Plantilla *.xlsx`), incluidas en la app.
Future<DownloadedFile> loadImportTemplate(ImportKind kind) async {
  final (asset, name) = switch (kind) {
    ImportKind.productos => ('plantilla_productos.xlsx', 'Plantilla Productos.xlsx'),
    ImportKind.marcas => ('plantilla_marcas.xlsx', 'Plantilla Marcas.xlsx'),
    ImportKind.categorias => ('plantilla_categorias.xlsx', 'Plantilla Categorías.xlsx'),
  };
  final data = await rootBundle.load('assets/docs/$asset');
  return DownloadedFile(
    name: name,
    bytes: data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
  );
}
