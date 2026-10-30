import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';
import '../../domain/entities/document_entity.dart';
import '../components/components.dart';
import '../pdf/receipt_pdf.dart';
import '../providers/auth_provider.dart';
import '../providers/documents_provider.dart';
import '../utils/share_file.dart';
import '../widgets/document_modals.dart';

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
    await shareDownloadedFile(result.right);
  }

  Future<void> _creditNote() async {
    final done = await showCreditNoteForm(context, widget.document);
    if (done == true && mounted) {
      _snack('Nota de crédito creada con éxito');
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.document;
    final scheme = Theme.of(context).colorScheme;
    final canCreditNote = d.sePuedeAnularConNotaCredito && _can('documentos.ventas.destroy');
    final boleta = d.boleta;

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
