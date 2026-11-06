import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';
import '../../domain/entities/document_entity.dart';
import '../../domain/entities/other_document_entity.dart';
import '../components/components.dart';
import '../pdf/receipt_pdf.dart';
import '../providers/auth_provider.dart';
import '../providers/documents_provider.dart';
import '../providers/other_documents_provider.dart';
import '../utils/download_file.dart';
import '../utils/success_snack.dart';
import '../widgets/document_modals.dart';
import '../widgets/guide_form.dart';

/// Comprobante de una venta o cotización en PDF: se ve en pantalla (A4 o ticket) y se
/// puede descargar, compartir o imprimir. Con boleta o factura emitidas ofrece también
/// la constancia de SUNAT (CDR) y la nota de crédito, como la web.
class ReceiptPage extends StatefulWidget {
  final DocumentEntity document;

  const ReceiptPage({super.key, required this.document});

  @override
  State<ReceiptPage> createState() => _ReceiptPageState();
}

class _ReceiptPageState extends State<ReceiptPage> {
  bool _ticket = false;
  bool _downloadingCdr = false;

  /// Se creó una guía de remisión desde esta pantalla.
  bool _guideCreated = false;
  Future<Uint8List?>? _logo;

  @override
  void initState() {
    super.initState();
    _logo = context.read<DocumentsProvider>().companyLogo();
  }

  bool _can(String permission) =>
      context.read<AuthProvider>().session?.can(permission) ?? false;

  void _snack(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<Uint8List> _build() async {
    final company = context.read<AuthProvider>().session!.company;
    return buildReceiptPdf(
      document: widget.document,
      company: company,
      logo: await _logo,
      ticket: _ticket,
    );
  }

  Future<void> _downloadCdr() async {
    setState(() => _downloadingCdr = true);
    final result = await context.read<DocumentsProvider>().downloadCdr(widget.document);
    if (!mounted) return;
    setState(() => _downloadingCdr = false);
    if (result.isLeft) return _snack(result.left.message);
    await downloadFile(context, result.right);
  }

  /// Abre el formulario de la guía de remisión de esta venta (como el botón de la web).
  Future<void> _createGuide() async {
    final created = await showGuideForm(context, document: widget.document);
    if (created == null || !mounted) return;
    setState(() => _guideCreated = true);
    showSuccessSnack(context, 'Guía creada con éxito');
    // Si ya se miraron las guías en Documentos, la lista se actualiza con la nueva.
    final others = context.read<OtherDocumentsProvider>();
    if (others.stateOf(OtherDocumentKind.guia).loadedOnce) {
      others.refresh(OtherDocumentKind.guia);
    }
  }

  Future<void> _creditNote() async {
    final done = await showCreditNoteForm(context, widget.document);
    if (done == true && mounted) {
      showSuccessSnack(context, 'Nota de crédito creada con éxito');
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.document;
    final scheme = Theme.of(context).colorScheme;
    final canCreditNote = d.sePuedeAnularConNotaCredito && _can('documentos.ventas.destroy');
    final boleta = d.boleta;
    // Como en la web: la guía se crea sobre una venta activa que aún no tiene; sin comprobante
    // electrónico es una guía local.
    final hasGuide = boleta?.tieneGuia == true || _guideCreated;
    final canGuide = d.activo && !d.esCotizacion && _can('documentos.guia_remision.store');

    return Scaffold(
      body: Column(
        children: [
          AppPageHeader(
            icon: Icons.receipt_long_outlined,
            title: d.numero,
            subtitle: '${d.comprobante} · ${d.cliente}',
            trailing: IconButton(
              tooltip: 'Cerrar',
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.close),
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
            child: Row(
              children: [
                if (!d.esCotizacion) ...[
                  SegmentedButton<bool>(
                    showSelectedIcon: false,
                    selected: {_ticket},
                    onSelectionChanged: (s) => setState(() => _ticket = s.first),
                    segments: const [
                      ButtonSegment(value: false, icon: Icon(Icons.description_outlined), label: Text('A4')),
                      ButtonSegment(value: true, icon: Icon(Icons.receipt_outlined), label: Text('Ticket')),
                    ],
                  ),
                  const SizedBox(width: 8),
                ],
                if (boleta != null && boleta.tieneCdr)
                  OutlinedButton.icon(
                    onPressed: _downloadingCdr ? null : _downloadCdr,
                    icon: _downloadingCdr
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.folder_zip_outlined, size: 18),
                    label: const Text('CDR'),
                  ),
                if (!d.esCotizacion && d.activo && hasGuide) ...[
                  const SizedBox(width: 8),
                  const OutlinedButton(
                    onPressed: null,
                    child: Text('Guía de remisión creada'),
                  ),
                ] else if (canGuide) ...[
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: _createGuide,
                    icon: const Icon(Icons.local_shipping_outlined, size: 18),
                    label: Text(boleta == null ? 'Guía de remisión local' : 'Guía de remisión'),
                  ),
                ],
                if (canCreditNote) ...[
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: _creditNote,
                    style: OutlinedButton.styleFrom(foregroundColor: scheme.error),
                    icon: const Icon(Icons.block, size: 18),
                    label: const Text('Nota de crédito'),
                  ),
                ],
                if (boleta != null && boleta.tieneNotaCredito)
                  const Padding(
                    padding: EdgeInsets.only(left: 8),
                    child: AppStatusBadge(label: 'Con nota de crédito', tone: AppBadgeTone.warning),
                  ),
              ],
            ),
          ),
          Expanded(
            child: PdfPreview(
              key: ValueKey(_ticket),
              build: (_) => _build(),
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
                child: Center(child: Text('No se pudo generar el PDF: $error')),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
