import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';
import '../../domain/entities/document_entity.dart' show DownloadedFile;
import '../../domain/entities/other_document_entity.dart';
import '../components/components.dart';
import '../pdf/other_document_pdf.dart';
import '../providers/auth_provider.dart';
import '../providers/documents_provider.dart';
import '../utils/download_file.dart';
import 'pdf_zoom_page.dart';

/// El PDF de un traslado, una entrada de stock, una guía de remisión o una nota de crédito: se ve
/// en pantalla y se puede descargar, compartir o imprimir.
class OtherDocumentPdfPage extends StatefulWidget {
  final OtherDocumentEntity document;
  final bool showAmounts;

  /// Vista previa de una guía que aún no se crea: lleva el aviso "sin guardar" y no tiene un
  /// número real, así que el archivo se llama distinto.
  final bool preview;

  const OtherDocumentPdfPage({
    super.key,
    required this.document,
    this.showAmounts = true,
    this.preview = false,
  });

  @override
  State<OtherDocumentPdfPage> createState() => _OtherDocumentPdfPageState();
}

class _OtherDocumentPdfPageState extends State<OtherDocumentPdfPage> {
  Future<Uint8List?>? _logo;

  OtherDocumentEntity get d => widget.document;

  String get _fileName => widget.preview ? 'guia-de-remision-vista-previa.pdf' : '${d.numero}.pdf';

  @override
  void initState() {
    super.initState();
    // El logo de la empresa solo va en la guía y en la nota de crédito.
    if (otherDocumentPdfNeedsCompany(d.kind)) {
      _logo = context.read<DocumentsProvider>().companyLogo();
    }
  }

  Future<Uint8List> _build() async {
    if (!otherDocumentPdfNeedsCompany(d.kind)) {
      return buildOtherDocumentPdf(document: d, showAmounts: widget.showAmounts);
    }
    final company = context.read<AuthProvider>().session!.company;
    return buildOtherDocumentPdf(document: d, company: company, logo: await _logo);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          AppPageHeader(
            icon: Icons.picture_as_pdf_outlined,
            title: d.numero,
            subtitle: widget.preview ? 'VISTA PREVIA — sin guardar' : d.kind.label,
            trailing: IconButton(
              tooltip: 'Cerrar',
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.close),
            ),
          ),
          Expanded(
            child: PdfPreview(
              build: (_) => _build(),
              pdfFileName: _fileName,
              canChangePageFormat: false,
              canChangeOrientation: false,
              canDebug: false,
              allowSharing: true,
              allowPrinting: true,
              // Descargar guarda el PDF en el dispositivo; el botón de compartir lo manda por
              // WhatsApp, correo, etc.
              actions: [
                // La lupa abre el documento en una pantalla para acercarlo con los dedos.
                PdfPreviewAction(
                  icon: const Icon(Icons.zoom_in),
                  onPressed: (context, build, pageFormat) async {
                    final bytes = await build(pageFormat);
                    if (context.mounted) {
                      await openPdfZoom(context, pdf: bytes, title: d.numero, subtitle: widget.preview ? 'VISTA PREVIA — sin guardar' : d.kind.label);
                    }
                  },
                ),
                PdfPreviewAction(
                  icon: const Icon(Icons.download_outlined),
                  onPressed: (context, build, pageFormat) async {
                    final bytes = await build(pageFormat);
                    if (context.mounted) {
                      await downloadFile(context, DownloadedFile(name: _fileName, bytes: bytes));
                    }
                  },
                ),
              ],
              loadingWidget: const CircularProgressIndicator(),
              onError: (context, error) => Padding(
                padding: const EdgeInsets.all(24),
                child: Center(child: Text('No se pudo generar el PDF: $error')),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
