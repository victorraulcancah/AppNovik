import 'dart:typed_data';
import 'package:flutter/services.dart' show rootBundle;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../../core/constants/app_constants.dart';
import '../../core/utils/format.dart';
import '../../domain/entities/company_entity.dart';
import '../../domain/entities/document_entity.dart';

/// Datos de la cabecera del comprobante. Según la configuración del almacén salen los
/// del almacén, los del vendedor o los de la empresa (las mismas reglas que la web).
class ReceiptHeader {
  final String direccion;
  final String telefono;
  final String email;
  final String web;

  const ReceiptHeader({
    required this.direccion,
    required this.telefono,
    required this.email,
    required this.web,
  });
}

ReceiptHeader resolveReceiptHeader(DocumentEntity d, CompanyEntity company) {
  final w = d.datosAlmacen;
  final usaDatos = w?.usaDatos ?? false;
  final usaVendedor = w?.usaDatosVendedor ?? false;

  return ReceiptHeader(
    direccion: usaDatos ? (w!.direccion ?? company.direccion ?? '-') : (company.direccion ?? '-'),
    telefono: usaVendedor
        ? (d.vendedorTelefono ?? '-')
        : usaDatos
            ? (w!.telefono ?? company.telefono ?? '-')
            : (company.telefono ?? '-'),
    email: usaVendedor
        ? (d.vendedorEmail ?? company.email ?? '-')
        : usaDatos
            ? (w!.email ?? company.email ?? '-')
            : (company.email ?? '-'),
    web: usaDatos ? (w!.web ?? company.web ?? '-') : (company.web ?? '-'),
  );
}

/// Título del comprobante según el tipo de documento.
String receiptTitle(DocumentEntity d) {
  if (d.esCotizacion) return 'Cotización';
  final b = d.boleta;
  if (b == null) return 'Nota de Venta';
  return b.esFactura ? 'Factura Electrónica' : 'Boleta Electrónica';
}

/// Divisor del IGV: `1 + igv`. La empresa lo guarda como fracción (0.18); si llegara como
/// porcentaje (18) se corrige. Sin dato, 18 %.
double receiptIgvDivisor(CompanyEntity company) {
  final igv = company.igv;
  if (igv == null || igv <= 0) return 1.18;
  return 1 + (igv > 1 ? igv / 100 : igv);
}

/// Roboto dibuja tildes, ñ y signos, pero no emojis ni otros símbolos fuera del plano básico
/// ni caracteres de control: se quitan para no dejar recuadros en el comprobante.
String _safe(String text) {
  final out = StringBuffer();
  for (final rune in text.runes) {
    if (rune > 0xFFFF || (rune < 0x20 && rune != 0x0A)) continue;
    out.writeCharCode(rune);
  }
  return out.toString();
}

final _date = DateFormat(AppConstants.dateFormat);

/// Gris de las franjas (el 10 % de negro sobre blanco, como `bg-black/10` de la web). Va como
/// color sólido: la transparencia no se aplica en el PDF y saldría negro.
const pdfBand = PdfColor(0.9, 0.9, 0.9);

Future<pw.ThemeData>? _theme;

/// La fuente del PDF (Roboto, incluida en la app), cargada una sola vez.
Future<pw.ThemeData> loadPdfTheme() => _theme ??= () async {
      final regular = pw.Font.ttf(await rootBundle.load('assets/fonts/Roboto-Regular.ttf'));
      final bold = pw.Font.ttf(await rootBundle.load('assets/fonts/Roboto-Bold.ttf'));
      return pw.ThemeData.withFont(base: regular, bold: bold);
    }();

/// Genera el PDF del comprobante: A4 como la web, o ticket de 80 mm.
Future<Uint8List> buildReceiptPdf({
  required DocumentEntity document,
  required CompanyEntity company,
  Uint8List? logo,
  bool ticket = false,
}) async {
  final doc = pw.Document(
    title: document.numero,
    author: company.razonSocial,
    theme: await loadPdfTheme(),
  );
  final image = logo == null ? null : _tryImage(logo);
  final data = _ReceiptData(document, company);

  if (ticket) {
    doc.addPage(pw.Page(
      pageFormat: PdfPageFormat.roll80.copyWith(marginLeft: 8, marginRight: 8, marginTop: 8, marginBottom: 12),
      build: (_) => _ticket(data, image),
    ));
  } else {
    doc.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.fromLTRB(32, 28, 32, 28),
      build: (_) => _a4(data, image),
    ));
  }
  return doc.save();
}

pw.MemoryImage? _tryImage(Uint8List bytes) {
  try {
    return pw.MemoryImage(bytes);
  } catch (_) {
    return null;
  }
}

/// Todo lo que se calcula una vez para los dos formatos.
class _ReceiptData {
  final DocumentEntity d;
  final CompanyEntity company;
  final ReceiptHeader header;
  final String symbol;
  final double total;
  final double divisor;

  _ReceiptData(this.d, this.company)
      : header = resolveReceiptHeader(d, company),
        symbol = d.esDolares ? r'$.' : 'S/.',
        total = d.items.fold<double>(0, (s, i) => s + i.subtotal),
        divisor = receiptIgvDivisor(company);

  String money(double v) => formatMoney(v, symbol: symbol);

  /// El desglose Sub Total / IGV solo corresponde a boleta y factura.
  bool get conIgv => d.boleta != null;

  double get items => d.items.fold<double>(0, (s, i) => s + i.cantidad);
  double get subTotal => total / divisor;
  double get igv => total - total / divisor;

  String get fecha => d.creado == null ? '-' : _date.format(d.creado!);
  String get payments => d.pagos.map((p) => p.metodo).join(', ');
  String get sellerLine => d.vendedor;
}

// ---------------------------------------------------------------- A4

List<pw.Widget> _a4(_ReceiptData r, pw.MemoryImage? logo) {
  final d = r.d;
  final bold = pw.TextStyle(fontWeight: pw.FontWeight.bold);

  pw.Widget field(String label, String value) => pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 3),
        child: pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          pw.SizedBox(width: 96, child: pw.Text(label, style: bold.copyWith(fontSize: 8))),
          pw.Expanded(child: pw.Text(_safe(value), style: const pw.TextStyle(fontSize: 8))),
        ]),
      );

  pw.Widget cell(String text, {bool header = false, pw.Alignment align = pw.Alignment.centerLeft}) =>
      pw.Container(
        alignment: align,
        color: header ? pdfBand : null,
        padding: pw.EdgeInsets.symmetric(horizontal: 5, vertical: header ? 3 : 4),
        child: pw.Text(
          _safe(text),
          style: header ? bold.copyWith(fontSize: 8) : const pw.TextStyle(fontSize: 8),
        ),
      );

  final rows = <pw.TableRow>[
    pw.TableRow(children: [
      cell('CANTIDAD', header: true),
      cell('CÓDIGO', header: true),
      cell('DESCRIPCIÓN', header: true),
      cell('VALOR U.', header: true, align: pw.Alignment.centerRight),
      cell('TOTAL', header: true, align: pw.Alignment.centerRight),
    ]),
    for (final i in d.items)
      pw.TableRow(
        decoration: const pw.BoxDecoration(
          border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey300, width: 0.5)),
        ),
        children: [
          cell(formatQuantity(i.cantidad)),
          cell(i.codigo ?? ''),
          cell(i.marca != null && i.marca!.isNotEmpty ? '${i.name} | ${i.marca}' : i.name),
          cell(r.money(i.precio), align: pw.Alignment.centerRight),
          cell(r.money(i.subtotal), align: pw.Alignment.centerRight),
        ],
      ),
  ];

  pw.Widget amount(String label, String value) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.end,
        children: [
          pw.Text(label, style: bold.copyWith(fontSize: 9)),
          pw.Text(value, style: const pw.TextStyle(fontSize: 9)),
        ],
      );

  return [
    pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.center, children: [
      pw.SizedBox(
        width: 90,
        height: 70,
        child: logo == null ? pw.SizedBox() : pw.Image(logo, fit: pw.BoxFit.contain),
      ),
      pw.SizedBox(width: 14),
      pw.Expanded(
        flex: 3,
        child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          pw.Text(_safe(r.company.razonSocial), style: bold.copyWith(fontSize: 13)),
          pw.SizedBox(height: 3),
          pw.Text(_safe(r.header.direccion), style: const pw.TextStyle(fontSize: 8)),
          pw.RichText(text: pw.TextSpan(children: [
            pw.TextSpan(text: 'Cel: ', style: bold.copyWith(fontSize: 8)),
            pw.TextSpan(text: _safe(r.header.telefono), style: const pw.TextStyle(fontSize: 8)),
          ])),
          pw.RichText(text: pw.TextSpan(children: [
            pw.TextSpan(text: 'Email: ', style: bold.copyWith(fontSize: 8)),
            pw.TextSpan(text: _safe(r.header.email), style: const pw.TextStyle(fontSize: 8)),
          ])),
          pw.RichText(text: pw.TextSpan(children: [
            pw.TextSpan(text: 'Web: ', style: bold.copyWith(fontSize: 8)),
            pw.TextSpan(text: _safe(r.header.web), style: const pw.TextStyle(fontSize: 8)),
          ])),
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
            pw.Text('RUC: ${r.company.ruc ?? '-'}', style: const pw.TextStyle(fontSize: 10)),
            pw.SizedBox(height: 6),
            pw.Text(_safe(receiptTitle(d).toUpperCase()),
                textAlign: pw.TextAlign.center, style: bold.copyWith(fontSize: 12)),
            pw.SizedBox(height: 6),
            pw.Text('Nro: ${d.numero}', style: const pw.TextStyle(fontSize: 10)),
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
      pw.Expanded(
        child: pw.Column(children: [
          field('RUC/DNI :', d.clienteDocumento ?? '-'),
          field('CLIENTE :', d.cliente),
          field('FECHA DE EMISIÓN :', r.fecha),
          field('DIRECCIÓN :', d.clienteDireccion ?? '-'),
        ]),
      ),
      pw.SizedBox(width: 24),
      pw.Expanded(
        child: pw.Column(children: [
          field('MONEDA :', d.esDolares ? 'DÓLARES' : 'SOLES'),
          if (!d.esCotizacion) field('CONDICIÓN DE PAGO :', r.payments),
          field('VENDEDOR :', d.vendedor),
          field('SUCURSAL :', d.almacen),
        ]),
      ),
    ]),
    pw.SizedBox(height: 10),
    pw.Table(
      columnWidths: const {
        0: pw.FixedColumnWidth(54),
        1: pw.FixedColumnWidth(70),
        2: pw.FlexColumnWidth(),
        3: pw.FixedColumnWidth(70),
        4: pw.FixedColumnWidth(70),
      },
      children: rows,
    ),
    pw.SizedBox(height: 10),
    pw.Align(
      alignment: pw.Alignment.centerRight,
      child: pw.Text('NRO. DE ITEMS: ${formatQuantity(r.items)}', style: const pw.TextStyle(fontSize: 8)),
    ),
    pw.Container(
      margin: const pw.EdgeInsets.only(top: 3),
      padding: const pw.EdgeInsets.symmetric(vertical: 6),
      decoration: const pw.BoxDecoration(
        border: pw.Border(
          top: pw.BorderSide(width: 1.2),
          bottom: pw.BorderSide(width: 1.2),
        ),
      ),
      child: pw.Row(
        mainAxisAlignment: r.conIgv ? pw.MainAxisAlignment.spaceBetween : pw.MainAxisAlignment.end,
        children: [
          if (r.conIgv) amount('Sub Total:', r.money(r.subTotal)),
          amount(r.conIgv ? 'Descuento:' : 'Desct. Total:', r.money(d.descuento)),
          if (r.conIgv) ...[
            amount('Valor Venta:', r.money(r.subTotal)),
            amount('IGV:', r.money(r.igv)),
          ],
        ],
      ),
    ),
    pw.Container(
      width: double.infinity,
      alignment: pw.Alignment.centerRight,
      padding: const pw.EdgeInsets.symmetric(vertical: 6),
      decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(width: 1.2))),
      child: pw.Text('TOTAL: ${r.money(r.total)}', style: bold.copyWith(fontSize: 11)),
    ),
    if (d.esDolares && d.tipoCambio != null)
      pw.Align(
        alignment: pw.Alignment.centerRight,
        child: pw.Padding(
          padding: const pw.EdgeInsets.only(top: 3),
          child: pw.Text('Tipo de Cambio: S/. ${d.tipoCambio}',
              style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
        ),
      ),
    if (d.esCotizacion) ...[
      pw.SizedBox(height: 10),
      pw.Text(
        d.reservado == true
            ? 'Se reservó el Stock${d.vencimientoStock != null ? ' hasta: ${_date.format(d.vencimientoStock!)}' : ''}'
            : 'No se reservó el Stock',
        style: bold.copyWith(fontSize: 9),
      ),
    ],
    pw.SizedBox(height: 16),
    pw.Container(
      padding: const pw.EdgeInsets.only(top: 6),
      decoration: const pw.BoxDecoration(border: pw.Border(top: pw.BorderSide(width: 1.2))),
      child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.stretch, children: [
        pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.Text('GRACIAS POR SU COMPRA!', style: bold.copyWith(fontSize: 9)),
        ),
        pw.SizedBox(height: 4),
        pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          pw.Expanded(
            child: pw.Column(children: [
              if ((d.datosAlmacen?.usaDatos ?? false) && d.datosAlmacen?.comentarios != null)
                pw.Text(_safe(d.datosAlmacen!.comentarios!),
                    style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
              pw.Text('Representación Impresa de la Factura Electrónica',
                  style: const pw.TextStyle(fontSize: 8)),
              pw.Text('Contrata Factura en Novi-k Perú', style: bold.copyWith(fontSize: 8)),
              pw.Text('GRACIAS POR SU VISITA', style: bold.copyWith(fontSize: 8)),
              pw.Text('Yo vendo con https://novi-k.com', style: bold.copyWith(fontSize: 8)),
            ]),
          ),
          pw.SizedBox(width: 12),
          pw.Expanded(
            child: (d.observaciones ?? '').trim().isEmpty
                ? pw.SizedBox()
                : pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                    pw.Text('Observaciones:', style: bold.copyWith(fontSize: 8)),
                    pw.Text(_safe(d.observaciones!), style: const pw.TextStyle(fontSize: 8)),
                  ]),
          ),
        ]),
      ]),
    ),
  ];
}

// ---------------------------------------------------------------- Ticket

pw.Widget _ticket(_ReceiptData r, pw.MemoryImage? logo) {
  final d = r.d;
  final bold = pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8);
  const base = pw.TextStyle(fontSize: 8);

  pw.Widget line(String left, String right, {bool strong = false}) => pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(left, style: strong ? bold : base),
          pw.Text(right, style: strong ? bold : base),
        ],
      );

  pw.Widget field(String label, String value) => pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 1.5),
        child: pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          pw.SizedBox(width: 52, child: pw.Text(label, style: bold)),
          pw.Expanded(child: pw.Text(_safe(value), style: base)),
        ]),
      );

  // Separador punteado, como el `border-dashed` del ticket de la web.
  final dash = pw.Divider(height: 8, thickness: 0.7, borderStyle: pw.BorderStyle.dashed);

  return pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.stretch, children: [
    if (logo != null) pw.Center(child: pw.SizedBox(height: 50, child: pw.Image(logo))),
    pw.SizedBox(height: 4),
    pw.Center(child: pw.Text(_safe(r.company.razonSocial), style: bold.copyWith(fontSize: 9), textAlign: pw.TextAlign.center)),
    pw.Center(child: pw.Text('RUC: ${r.company.ruc ?? '-'}', style: base)),
    pw.Center(child: pw.Text(_safe(r.header.direccion), style: base, textAlign: pw.TextAlign.center)),
    pw.Center(child: pw.Text('Cel: ${_safe(r.header.telefono)}', style: base)),
    pw.Center(child: pw.Text('Email: ${_safe(r.header.email)}', style: base)),
    pw.Center(child: pw.Text('Web: ${_safe(r.header.web)}', style: base)),
    dash,
    pw.Center(child: pw.Text(_safe(receiptTitle(d).toUpperCase()), style: bold.copyWith(fontSize: 9))),
    pw.Center(child: pw.Text('Nro: ${d.numero}', style: base)),
    dash,
    field('RUC/DNI :', d.clienteDocumento ?? '-'),
    field('CLIENTE :', d.cliente),
    field('FECHA :', r.fecha),
    field('DIRECCIÓN :', d.clienteDireccion ?? '-'),
    field('MONEDA :', d.esDolares ? 'DÓLARES' : 'SOLES'),
    field('VENDEDOR :', d.vendedor),
    field('SUCURSAL :', d.almacen),
    dash,
    pw.Row(children: [
      pw.Expanded(flex: 3, child: pw.Text('CÓDIGO', style: bold)),
      pw.Expanded(flex: 1, child: pw.Text('CANT', style: bold, textAlign: pw.TextAlign.center)),
      pw.Expanded(flex: 2, child: pw.Text('VALOR U.', style: bold, textAlign: pw.TextAlign.right)),
      pw.Expanded(flex: 2, child: pw.Text('TOTAL', style: bold, textAlign: pw.TextAlign.right)),
    ]),
    dash,
    for (final i in d.items)
      pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 2),
        child: pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          pw.Expanded(flex: 3, child: pw.Text(_safe(i.codigo ?? i.name), style: base)),
          pw.Expanded(flex: 1, child: pw.Text(formatQuantity(i.cantidad), style: base, textAlign: pw.TextAlign.center)),
          pw.Expanded(flex: 2, child: pw.Text(formatMoney(i.precio, symbol: ''), style: base, textAlign: pw.TextAlign.right)),
          pw.Expanded(flex: 2, child: pw.Text(formatMoney(i.subtotal, symbol: ''), style: base, textAlign: pw.TextAlign.right)),
        ]),
      ),
    dash,
    pw.Align(alignment: pw.Alignment.centerRight, child: pw.Text('NRO. DE ITEMS: ${formatQuantity(r.items)}', style: base)),
    line(d.boleta != null ? 'Descuento:' : 'Desct. Total:', r.money(d.descuento)),
    dash,
    if (r.conIgv) ...[
      line('Sub Total:', r.money(r.subTotal)),
      line('IGV (${((receiptIgvDivisor(r.company) - 1) * 100).round()}%):', r.money(r.igv)),
    ],
    line('TOTAL:', r.money(r.total), strong: true),
    if (d.esDolares && d.tipoCambio != null)
      pw.Align(alignment: pw.Alignment.centerRight, child: pw.Text('Tipo de Cambio: S/. ${d.tipoCambio}', style: base)),
    if ((d.observaciones ?? '').trim().isNotEmpty) ...[
      dash,
      pw.Text('Observaciones:', style: bold),
      pw.Text(_safe(d.observaciones!), style: base),
    ],
    dash,
    pw.Center(child: pw.Text('GRACIAS POR SU COMPRA!', style: bold)),
    pw.Center(child: pw.Text('Representación Impresa de la Factura Electrónica', style: base, textAlign: pw.TextAlign.center)),
    pw.Center(child: pw.Text('Contrata Factura en Novi-k Perú', style: bold)),
    pw.Center(child: pw.Text('Yo vendo con https://novi-k.com', style: bold)),
  ]);
}
