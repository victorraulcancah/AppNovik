import 'package:flutter/material.dart';
import '../../domain/entities/document_entity.dart';
import '../pages/receipt_page.dart';

/// Abre el comprobante de una venta o cotización (el mismo de Documentos y Reportes). [open] se puede cambiar en las
/// pruebas (el PDF no corre en ellas).
class GestionReceipt {
  GestionReceipt._();

  static Future<void> Function(BuildContext context, DocumentEntity document) open = _open;

  static Future<void> _open(BuildContext context, DocumentEntity document) =>
      Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => ReceiptPage(document: document)));
}
