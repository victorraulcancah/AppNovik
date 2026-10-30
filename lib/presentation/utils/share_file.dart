import 'package:share_plus/share_plus.dart';
import '../../domain/entities/document_entity.dart';

String _mimeType(String name) {
  final lower = name.toLowerCase();
  if (lower.endsWith('.xlsx')) {
    return 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
  }
  if (lower.endsWith('.zip')) return 'application/zip';
  if (lower.endsWith('.pdf')) return 'application/pdf';
  return 'application/octet-stream';
}

/// Abre el menú de compartir del sistema con el archivo (guardarlo, enviarlo por
/// WhatsApp o correo, abrirlo con otra app).
Future<void> shareDownloadedFile(DownloadedFile file) {
  return SharePlus.instance.share(
    ShareParams(
      files: [XFile.fromData(file.bytes, name: file.name, mimeType: _mimeType(file.name))],
      fileNameOverrides: [file.name],
    ),
  );
}
