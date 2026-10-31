import 'dart:typed_data';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../../core/constants/app_constants.dart';
import '../../core/utils/format.dart';
import '../../domain/entities/other_document_entity.dart';
import 'receipt_pdf.dart' show loadPdfTheme, pdfBand;

final _date = DateFormat(AppConstants.dateFormat);

/// Los documentos de la web que se pueden bajar en PDF desde Documentos (las guías de remisión y
/// las notas de crédito llevan datos de SUNAT y aún no).
bool hasOtherDocumentPdf(OtherDocumentKind kind) =>
    kind == OtherDocumentKind.traslado || kind == OtherDocumentKind.entradaStock;

const _line = PdfColor(0.9, 0.9, 0.9);
const _rule = PdfColor(0.75, 0.74, 0.74);

final _money = NumberFormat('#,##0.00', 'en_US');

String _moneda(double v) => 'S/. ${_money.format(v)}';

/// El PDF de un traslado de stock o de una entrada de stock, con el mismo diseño que genera la
/// web: título con el número, "Información general", tabla de productos y totales. Con
/// [showAmounts] en `false` (Jefe de Almacén) una entrada de stock sale sin costos ni total.
Future<Uint8List> buildOtherDocumentPdf({
  required OtherDocumentEntity document,
  bool showAmounts = true,
}) async {
  assert(hasOtherDocumentPdf(document.kind), 'Solo traslados y entradas de stock tienen PDF');
  final d = document;
  final isTransfer = d.kind == OtherDocumentKind.traslado;
  // Los traslados siempre muestran los importes; las entradas, salvo para el Jefe de Almacén.
  final amounts = isTransfer || showAmounts;
  final fecha = d.creado == null ? '-' : _date.format(d.creado!);

  final pdf = pw.Document(title: d.numero, theme: await loadPdfTheme());
  pdf.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(48),
      build: (context) => [
        pw.Center(
          child: pw.Column(
            children: [
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                decoration: pw.BoxDecoration(color: pdfBand, borderRadius: pw.BorderRadius.circular(4)),
                child: pw.Text(
                  isTransfer ? 'TRASLADO STOCK' : 'DOCUMENTO STOCK',
                  style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
                ),
              ),
              pw.SizedBox(height: 4),
              pw.Text('Nro: ${d.numero}', style: const pw.TextStyle(fontSize: 10)),
            ],
          ),
        ),
        pw.SizedBox(height: 16),
        pw.Container(
          width: double.infinity,
          padding: const pw.EdgeInsets.symmetric(vertical: 4),
          decoration: pw.BoxDecoration(color: pdfBand, borderRadius: pw.BorderRadius.circular(4)),
          child: pw.Center(
            child: pw.Text(
              'INFORMACIÓN GENERAL',
              style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
            ),
          ),
        ),
        pw.SizedBox(height: 6),
        if (isTransfer)
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                child: pw.Column(children: [
                  _info('FECHA DE EMISIÓN :', fecha),
                  _info('SUCURSAL SALIDA :', d.desde ?? '-'),
                  _info('SUCURSAL ENTRADA :', d.hacia ?? '-'),
                ]),
              ),
              pw.SizedBox(width: 24),
              pw.Expanded(
                child: pw.Column(children: [
                  _info('MONEDA :', 'SOLES'),
                  _info('USUARIO :', d.usuario ?? '-'),
                ]),
              ),
            ],
          )
        else
          pw.Row(children: [
            pw.Expanded(
              child: pw.Column(children: [
                _info('FECHA DE EMISIÓN :', fecha),
                _info('SUCURSAL :', d.almacen ?? '-'),
                _info('USUARIO :', d.usuario ?? '-'),
              ]),
            ),
            pw.SizedBox(width: 24),
            pw.Expanded(child: pw.SizedBox()),
          ]),
        pw.SizedBox(height: 16),
        _table(d, amounts: amounts, isTransfer: isTransfer),
        pw.SizedBox(height: 16),
        pw.Container(
          width: double.infinity,
          padding: const pw.EdgeInsets.only(bottom: 3),
          decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: _line))),
          child: pw.Text(
            'NRO. DE ITEMS: ${formatQuantity(d.unidades)}',
            textAlign: pw.TextAlign.right,
            style: const pw.TextStyle(fontSize: 8),
          ),
        ),
        if (!isTransfer && amounts)
          pw.Container(
            width: double.infinity,
            padding: const pw.EdgeInsets.symmetric(vertical: 6),
            decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: _line))),
            child: pw.Text(
              'TOTAL: ${_moneda(d.monto)}',
              textAlign: pw.TextAlign.right,
              style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
            ),
          ),
      ],
    ),
  );
  return pdf.save();
}

pw.Widget _info(String label, String value) {
  return pw.Padding(
    padding: const pw.EdgeInsets.symmetric(vertical: 1),
    child: pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Expanded(
          child: pw.Text(label, style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold)),
        ),
        pw.Expanded(child: pw.Text(value, style: const pw.TextStyle(fontSize: 7.5))),
      ],
    ),
  );
}

/// Cantidad, código, descripción (`nombre | marca`) y, con importes, valor/costo unitario y total.
pw.Widget _table(OtherDocumentEntity d, {required bool amounts, required bool isTransfer}) {
  final unitLabel = isTransfer ? 'Valor U.' : 'Costo Neto.';
  final flex = amounts ? const [11, 12, 41, 18, 18] : const [14, 16, 70];
  final headers = ['Cantidad', 'Codigo', 'Descripción', if (amounts) ...[unitLabel, 'Total']];

  pw.Widget cell(String text, int flexValue, {bool header = false, pw.TextAlign align = pw.TextAlign.left}) {
    return pw.Expanded(
      flex: flexValue,
      child: pw.Padding(
        padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: pw.Text(
          text,
          textAlign: align,
          style: pw.TextStyle(
            fontSize: header ? 9 : 8,
            fontWeight: header ? pw.FontWeight.bold : pw.FontWeight.normal,
          ),
        ),
      ),
    );
  }

  pw.TextAlign alignOf(int i) => i >= 3 ? pw.TextAlign.right : pw.TextAlign.left;

  return pw.Column(
    children: [
      pw.Container(
        decoration: pw.BoxDecoration(
          color: pdfBand,
          border: const pw.Border(bottom: pw.BorderSide(color: _rule)),
        ),
        child: pw.Row(children: [
          for (var i = 0; i < headers.length; i++) cell(headers[i], flex[i], header: true, align: alignOf(i)),
        ]),
      ),
      for (final l in d.lines)
        pw.Container(
          decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: _line, width: 0.5))),
          child: pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            cell(formatQuantity(l.cantidad), flex[0]),
            cell(l.codigo ?? '', flex[1]),
            cell('${l.name} | ${l.marca ?? '-'}', flex[2]),
            if (amounts) ...[
              cell(_moneda(l.costo), flex[3], align: pw.TextAlign.right),
              cell(_moneda(l.total), flex[4], align: pw.TextAlign.right),
            ],
          ]),
        ),
    ],
  );
}
