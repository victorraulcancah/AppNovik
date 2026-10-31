import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../domain/entities/document_entity.dart' show DownloadedFile;
import 'share_file.dart';

/// Descarga un archivo al dispositivo: abre el "Guardar como" del sistema (carpeta Descargas,
/// Drive, etc.) y avisa cuando quedó guardado. El aviso trae "Compartir" por si se prefiere
/// mandarlo por WhatsApp o correo. Si se cancela el diálogo no pasa nada.
Future<void> downloadFile(BuildContext context, DownloadedFile file) async {
  final messenger = ScaffoldMessenger.of(context);
  void snack(SnackBar bar) => messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(bar);

  try {
    final saved = await FilePicker.saveFile(
      fileName: file.name,
      bytes: file.bytes,
      mimeType: mimeTypeOf(file.name),
    );
    if (saved == null) return;
    snack(SnackBar(
      content: Text('${file.name} guardado'),
      action: SnackBarAction(label: 'Compartir', onPressed: () => shareDownloadedFile(file)),
    ));
  } catch (_) {
    snack(const SnackBar(content: Text('No se pudo guardar el archivo')));
  }
}
