import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import '../../domain/entities/document_entity.dart' show DownloadedFile;
import '../../domain/entities/other_document_entity.dart';
import '../components/components.dart';
import '../pdf/other_document_pdf.dart';
import '../utils/download_file.dart';

/// El PDF de un traslado o una entrada de stock: se ve en pantalla y se puede descargar,
/// compartir o imprimir.
class OtherDocumentPdfPage extends StatelessWidget {
  final OtherDocumentEntity document;
  final bool showAmounts;

  const OtherDocumentPdfPage({super.key, required this.document, this.showAmounts = true});

  @override
  Widget build(BuildContext context) {
    final d = document;

    return Scaffold(
      body: Column(
        children: [
          AppPageHeader(
            icon: Icons.picture_as_pdf_outlined,
            title: d.numero,
            subtitle: d.kind.label,
            trailing: IconButton(
              tooltip: 'Cerrar',
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.close),
            ),
          ),
          Expanded(
            child: PdfPreview(
              build: (_) => buildOtherDocumentPdf(document: d, showAmounts: showAmounts),
              pdfFileName: '${d.numero}.pdf',
              canChangePageFormat: false,
              canChangeOrientation: false,
              canDebug: false,
              allowSharing: true,
              allowPrinting: true,
              // Descargar guarda el PDF en el dispositivo; el botón de compartir lo manda por
              // WhatsApp, correo, etc.
              actions: [
                PdfPreviewAction(
                  icon: const Icon(Icons.download_outlined),
                  onPressed: (context, build, pageFormat) async {
                    final bytes = await build(pageFormat);
                    if (context.mounted) {
                      await downloadFile(context, DownloadedFile(name: '${d.numero}.pdf', bytes: bytes));
                    }
                  },
                ),
              ],
              loadingWidget: const CircularProgressIndicator(),
              onError: (context, error) => Padding(
                padding: const EdgeInsets.all(24),
                child: Center(child: Text('No se pudo generar el PDF: \$error')),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
