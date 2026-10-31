import 'dart:typed_data';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../../core/constants/app_constants.dart';
import '../../core/utils/format.dart';
import '../../domain/entities/company_entity.dart';
import '../../domain/entities/document_entity.dart';
import '../../domain/entities/guide_form_entity.dart';
import '../../domain/entities/other_document_entity.dart';
import 'receipt_pdf.dart' show loadPdfTheme, pdfBand, pdfSafe;

final _date = DateFormat(AppConstants.dateFormat);

String _day(DateTime? d) => d == null ? '-' : _date.format(d);

/// `Distrito / Provincia / Departamento`, como lo escribe la web en el documento.
String _ubigeo(String? value) => value == null || value.isEmpty ? '-' : value.replaceAll(', ', ' / ');

/// Guía de remisión electrónica remitente: el mismo documento que arma la web, con la cabecera
/// de la empresa, la información general (cliente, fechas, motivo, peso, ubigeo y direcciones de
/// partida y de destino, y el transportista) y los productos que se trasladan.
Future<Uint8List> buildGuidePdf({
  required OtherDocumentEntity document,
  required CompanyEntity company,
  Uint8List? logo,
}) {
  assert(document.kind == OtherDocumentKind.guia && document.guia != null);
  final g = document.guia!;
  final sale = document.comprobante;
  final public = g.tipoGuia == '01';
  final motivo = g.codTraslado == null
      ? '-'
      : '${g.codTraslado} - ${guideTransferReasons[g.codTraslado] ?? ''}';

  return _build(
    document: document,
    company: company,
    logo: logo,
    title: 'GUÍA DE REMISIÓN\nELECTRÓNICA REMITENTE',
    titleSize: 10,
    leftFields: [
      ('RUC/DNI :', sale?.clienteDocumento ?? '-'),
      ('CLIENTE :', sale?.cliente ?? '-'),
      ('FECHA DE EMISIÓN :', _day(g.fechaEmision)),
      ('FECHA DE TRASLADO :', _day(g.fechaTraslado)),
      ('MOTIVO TRASLADO :', motivo),
      ('PESO :', '${formatQuantity(g.pesoTotal)} KG.'),
      ('SUCURSAL :', sale?.almacen ?? '-'),
      ('UBIGEO DE PARTIDA :', _ubigeo(g.ubigeoSalida)),
      ('DIRECCIÓN DE PARTIDA :', g.direccionSalida ?? '-'),
    ],
    rightFields: [
      ('UBIGEO DE DESTINO :', _ubigeo(g.ubigeoLlegada)),
      ('DIRECCIÓN DE DESTINO :', g.direccionLlegada ?? '-'),
      ('DOCUMENTO ASOCIADO :', document.comprobanteNumero ?? '-'),
    ],
    rightTitle: 'TRANSPORTISTA',
    rightSecondary: [
      ('DNI / RUC :', g.documentoTransportista ?? '-'),
      ('RAZON SOCIAL :', g.transportista ?? '-'),
      if (public) ('REGISTRO MTC :', g.matricula ?? '-'),
      if (!public) ...[
        ('PLACA VEHICULO :', g.placaChofer ?? '-'),
        ('DNI CHOFER :', g.dniChofer ?? '-'),
      ],
    ],
    // La guía solo lleva cantidad, código y descripción.
    withPrices: false,
    footer: (bold) => [
      if (g.observaciones != null)
        pw.Padding(
          padding: const pw.EdgeInsets.only(top: 10),
          child: pw.RichText(
            text: pw.TextSpan(children: [
              pw.TextSpan(text: 'OBSERVACIONES: ', style: bold.copyWith(fontSize: 8)),
              pw.TextSpan(text: pdfSafe(g.observaciones!), style: const pw.TextStyle(fontSize: 8)),
            ]),
          ),
        ),
      pw.Container(
        margin: const pw.EdgeInsets.only(top: 12),
        padding: const pw.EdgeInsets.only(top: 3),
        decoration: const pw.BoxDecoration(border: pw.Border(top: pw.BorderSide(width: 1.2))),
        child: pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.Text(
            'NRO. DE ITEMS: ${formatQuantity(_items(sale))}',
            style: const pw.TextStyle(fontSize: 8),
          ),
        ),
      ),
    ],
  );
}

/// Nota de crédito electrónica: igual que la de la web, con el documento que se anula, el motivo,
/// los productos, el desglose (sub total, descuento, valor de venta e IGV) y el total.
Future<Uint8List> buildCreditNotePdf({
  required OtherDocumentEntity document,
  required CompanyEntity company,
  Uint8List? logo,
}) {
  assert(document.kind == OtherDocumentKind.notaCredito && document.nota != null);
  final n = document.nota!;
  final sale = document.comprobante;
  final symbol = (sale?.esDolares ?? false) ? r'$.' : 'S/.';
  String money(double v) => formatMoney(v, symbol: symbol);

  final total = (sale?.items ?? const <DocumentItemEntity>[]).fold<double>(0, (s, i) => s + i.subtotal);
  final subTotal = total / 1.18;
  final igv = total - total / 1.18;
  final discount = (sale?.items ?? const <DocumentItemEntity>[]).fold<double>(0, (s, i) => s + i.descuento);

  return _build(
    document: document,
    company: company,
    logo: logo,
    title: 'NOTA DE CRÉDITO',
    titleSize: 13,
    leftFields: [
      ('RUC/DNI :', sale?.clienteDocumento ?? '-'),
      ('CLIENTE :', sale?.cliente ?? '-'),
      ('FECHA DE EMISIÓN :', _day(n.fechaEmision)),
    ],
    rightFields: [
      ('DOCUMENTO ASOCIADO :', document.comprobanteNumero ?? '-'),
      ('SUCURSAL :', sale?.almacen ?? '-'),
      ('DESCRIPCION :', n.descripcion ?? '-'),
    ],
    withPrices: true,
    symbol: symbol,
    footer: (bold) {
      pw.Widget amount(String label, String value) => pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Text(label, style: bold.copyWith(fontSize: 9)),
              pw.Text(value, style: const pw.TextStyle(fontSize: 9)),
            ],
          );

      return [
        pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.Padding(
            padding: const pw.EdgeInsets.only(top: 10),
            child: pw.Text(
              'NRO. DE ITEMS: ${formatQuantity(_items(sale))}',
              style: const pw.TextStyle(fontSize: 8),
            ),
          ),
        ),
        pw.Container(
          margin: const pw.EdgeInsets.only(top: 3),
          padding: const pw.EdgeInsets.symmetric(vertical: 6),
          decoration: const pw.BoxDecoration(
            border: pw.Border(top: pw.BorderSide(width: 1.2), bottom: pw.BorderSide(width: 1.2)),
          ),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              amount('Sub Total:', money(subTotal)),
              amount('Descuento:', money(discount)),
              amount('Valor Venta:', money(subTotal)),
              amount('IGV:', money(igv)),
            ],
          ),
        ),
        pw.Container(
          width: double.infinity,
          alignment: pw.Alignment.centerRight,
          padding: const pw.EdgeInsets.symmetric(vertical: 6),
          decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(width: 1.2))),
          child: pw.Text('TOTAL: ${money(total)}', style: bold.copyWith(fontSize: 11)),
        ),
      ];
    },
  );
}

double _items(DocumentEntity? sale) =>
    (sale?.items ?? const <DocumentItemEntity>[]).fold<double>(0, (s, i) => s + i.cantidad);

/// Estructura común de los dos documentos: cabecera, información general, tabla y cierre.
Future<Uint8List> _build({
  required OtherDocumentEntity document,
  required CompanyEntity company,
  required Uint8List? logo,
  required String title,
  required double titleSize,
  required List<(String, String)> leftFields,
  required List<(String, String)> rightFields,
  String? rightTitle,
  List<(String, String)> rightSecondary = const [],
  required bool withPrices,
  String symbol = 'S/.',
  required List<pw.Widget> Function(pw.TextStyle bold) footer,
}) async {
  final bold = pw.TextStyle(fontWeight: pw.FontWeight.bold);
  final image = logo == null ? null : _tryImage(logo);
  final items = document.comprobante?.items ?? const <DocumentItemEntity>[];

  pw.Widget field((String, String) f) => pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 3),
        child: pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          pw.Expanded(child: pw.Text(f.$1, style: bold.copyWith(fontSize: 8))),
          pw.SizedBox(width: 6),
          pw.Expanded(child: pw.Text(pdfSafe(f.$2), style: const pw.TextStyle(fontSize: 8))),
        ]),
      );

  pw.Widget cell(String text, {bool header = false, pw.Alignment align = pw.Alignment.centerLeft}) =>
      pw.Container(
        alignment: align,
        color: header ? pdfBand : null,
        padding: pw.EdgeInsets.symmetric(horizontal: 5, vertical: header ? 3 : 4),
        child: pw.Text(
          pdfSafe(text),
          style: header ? bold.copyWith(fontSize: 8) : const pw.TextStyle(fontSize: 8),
        ),
      );

  String money(double v) => formatMoney(v, symbol: symbol);

  final rows = <pw.TableRow>[
    pw.TableRow(children: [
      cell('CANTIDAD', header: true),
      cell('CÓDIGO', header: true),
      cell('DESCRIPCIÓN', header: true),
      if (withPrices) ...[
        cell('VALOR U.', header: true, align: pw.Alignment.centerRight),
        cell('Total', header: true, align: pw.Alignment.centerRight),
      ],
    ]),
    for (final i in items)
      pw.TableRow(
        decoration: const pw.BoxDecoration(
          border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey300, width: 0.5)),
        ),
        children: [
          cell(formatQuantity(i.cantidad)),
          cell(i.codigo ?? ''),
          cell(i.marca != null && i.marca!.isNotEmpty ? '${i.name} | ${i.marca}' : i.name),
          if (withPrices) ...[
            cell(money(i.precio), align: pw.Alignment.centerRight),
            cell(money(i.subtotal), align: pw.Alignment.centerRight),
          ],
        ],
      ),
  ];

  final pdf = pw.Document(
    title: document.numero,
    author: company.razonSocial,
    theme: await loadPdfTheme(),
  );
  pdf.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.fromLTRB(32, 28, 32, 28),
      build: (context) => [
        pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.center, children: [
          pw.SizedBox(
            width: 90,
            height: 70,
            child: image == null ? pw.SizedBox() : pw.Image(image, fit: pw.BoxFit.contain),
          ),
          pw.SizedBox(width: 14),
          pw.Expanded(
            flex: 3,
            child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
              pw.Text(pdfSafe(company.razonSocial), style: bold.copyWith(fontSize: 13)),
              pw.SizedBox(height: 3),
              pw.Text(pdfSafe(company.direccion ?? '-'), style: const pw.TextStyle(fontSize: 8)),
              pw.RichText(
                text: pw.TextSpan(children: [
                  pw.TextSpan(text: 'Cel: ', style: bold.copyWith(fontSize: 8)),
                  pw.TextSpan(text: pdfSafe(company.telefono ?? '-'), style: const pw.TextStyle(fontSize: 8)),
                ]),
              ),
              pw.RichText(
                text: pw.TextSpan(children: [
                  pw.TextSpan(text: 'Email: ', style: bold.copyWith(fontSize: 8)),
                  pw.TextSpan(text: pdfSafe(company.email ?? '-'), style: const pw.TextStyle(fontSize: 8)),
                ]),
              ),
              pw.RichText(
                text: pw.TextSpan(children: [
                  pw.TextSpan(text: 'Web: ', style: bold.copyWith(fontSize: 8)),
                  pw.TextSpan(text: pdfSafe(company.web ?? '-'), style: const pw.TextStyle(fontSize: 8)),
                ]),
              ),
            ]),
          ),
          pw.SizedBox(width: 14),
          pw.Expanded(
            flex: 2,
            child: pw.Container(
              padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 12),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.grey700, width: 0.8),
                borderRadius: pw.BorderRadius.circular(10),
              ),
              child: pw.Column(children: [
                pw.Text('RUC: ${company.ruc ?? '-'}', style: const pw.TextStyle(fontSize: 10)),
                pw.SizedBox(height: 6),
                pw.Text(
                  title,
                  textAlign: pw.TextAlign.center,
                  style: bold.copyWith(fontSize: titleSize),
                ),
                pw.SizedBox(height: 6),
                pw.Text('Nro: ${document.numero}', style: const pw.TextStyle(fontSize: 10)),
              ]),
            ),
          ),
        ]),
        pw.SizedBox(height: 14),
        pw.Container(
          width: double.infinity,
          alignment: pw.Alignment.center,
          color: pdfBand,
          padding: const pw.EdgeInsets.symmetric(vertical: 4),
          child: pw.Text('INFORMACIÓN GENERAL', style: bold.copyWith(fontSize: 9)),
        ),
        pw.SizedBox(height: 8),
        pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          pw.Expanded(child: pw.Column(children: [for (final f in leftFields) field(f)])),
          pw.SizedBox(width: 24),
          pw.Expanded(
            child: pw.Column(children: [
              for (final f in rightFields) field(f),
              if (rightTitle != null)
                pw.Padding(
                  padding: const pw.EdgeInsets.only(top: 4, bottom: 3),
                  child: pw.Align(
                    alignment: pw.Alignment.centerRight,
                    child: pw.Text(rightTitle, style: bold.copyWith(fontSize: 8)),
                  ),
                ),
              for (final f in rightSecondary) field(f),
            ]),
          ),
        ]),
        pw.SizedBox(height: 10),
        pw.Table(
          columnWidths: withPrices
              ? const {
                  0: pw.FixedColumnWidth(54),
                  1: pw.FixedColumnWidth(70),
                  2: pw.FlexColumnWidth(),
                  3: pw.FixedColumnWidth(70),
                  4: pw.FixedColumnWidth(70),
                }
              : const {
                  0: pw.FixedColumnWidth(54),
                  1: pw.FixedColumnWidth(90),
                  2: pw.FlexColumnWidth(),
                },
          children: rows,
        ),
        ...footer(bold),
      ],
    ),
  );
  return pdf.save();
}

pw.MemoryImage? _tryImage(Uint8List bytes) {
  try {
    return pw.MemoryImage(bytes);
  } catch (_) {
    return null;
  }
}
