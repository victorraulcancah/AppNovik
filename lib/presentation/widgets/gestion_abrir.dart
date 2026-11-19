import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/gestion_provider.dart';
import '../utils/gestion_receipt.dart';

/// Trae una venta o una cotización completa y abre su comprobante (el mismo de Documentos y Reportes). Si no se
/// pudo, lo dice con el motivo del servidor.
Future<void> abrirComprobanteGestion(
  BuildContext context, {
  required bool cotizacion,
  required int id,
  int nroDocumento = 0,
}) async {
  final gestion = context.read<GestionProvider>();
  final result = await gestion.abrirDocumento(cotizacion: cotizacion, id: id, nroDocumento: nroDocumento);
  if (!context.mounted) return;
  if (result.isLeft) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(result.left.message)));
    return;
  }
  await GestionReceipt.open(context, result.right);
}

/// El número de un documento escrito como enlace (azul y subrayado; en rojo si está anulado).
class GestionDocumentoLink extends StatelessWidget {
  final String texto;
  final bool anulado;

  const GestionDocumentoLink({super.key, required this.texto, this.anulado = false});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final color = anulado
        ? (dark ? const Color(0xFFFDA4AF) : const Color(0xFFBE123C))
        : (dark ? const Color(0xFF93C5FD) : const Color(0xFF1D4ED8));
    return Text(
      texto,
      style: theme.textTheme.bodyMedium?.copyWith(
        color: color,
        decoration: TextDecoration.underline,
        decorationColor: color,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}
