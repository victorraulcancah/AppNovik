import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import '../../domain/entities/document_entity.dart' show DownloadedFile;
import '../components/components.dart';
import '../utils/download_file.dart';
import 'pdf_zoom_page.dart';

/// El PDF del estado de cuenta que arma el servidor: se ve en pantalla y se puede acercar,
/// descargar, compartir o imprimir.
class AccountStatementPdfPage extends StatelessWidget {
  final Uint8List pdf;
  final String fileName;
  final String clientName;

  const AccountStatementPdfPage({super.key, required this.pdf, required this.fileName, required this.clientName});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          AppPageHeader(
            icon: Icons.picture_as_pdf_outlined,
            title: 'Estado de cuenta',
            subtitle: clientName,
            trailing: IconButton(
              tooltip: 'Cerrar',
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.close),
            ),
          ),
          Expanded(
            child: PdfPreview(
              build: (_) async => pdf,
              pdfFileName: fileName,
              canChangePageFormat: false,
              canChangeOrientation: false,
              canDebug: false,
              allowSharing: true,
              allowPrinting: true,
              actions: [
                PdfPreviewAction(
                  icon: const Icon(Icons.zoom_in),
                  onPressed: (context, build, pageFormat) =>
                      openPdfZoom(context, pdf: pdf, title: 'Estado de cuenta', subtitle: clientName),
                ),
                PdfPreviewAction(
                  icon: const Icon(Icons.download_outlined),
                  onPressed: (context, build, pageFormat) =>
                      downloadFile(context, DownloadedFile(name: fileName, bytes: pdf)),
                ),
              ],
              loadingWidget: const CircularProgressIndicator(),
              onError: (context, error) => Padding(
                padding: const EdgeInsets.all(24),
                child: Center(child: Text('No se pudo mostrar el PDF: $error')),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
