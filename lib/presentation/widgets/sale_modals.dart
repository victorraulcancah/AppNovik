import 'package:flutter/material.dart';
import '../../core/utils/format.dart';
import '../../domain/entities/document_entity.dart';
import '../components/components.dart';
import 'document_modals.dart';

/// Confirmación de una venta recién registrada: número, cliente, total y pagos.
/// Desde aquí se puede abrir el detalle completo del documento.
Future<void> showSaleRegistered(BuildContext context, DocumentEntity sale) async {
  final verDetalle = await showAppModal(
    context,
    title: 'Venta registrada',
    subtitle: sale.numero,
    icon: Icons.check_circle_outline,
    primaryLabel: 'Ver detalle',
    secondaryLabel: 'Nueva venta',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppDetailRow(label: 'Comprobante', value: sale.comprobante),
        AppDetailRow(label: 'Cliente', value: sale.cliente),
        AppDetailRow(label: 'Almacén', value: sale.almacen),
        AppDetailRow(
          label: 'Total',
          value: formatMoney(sale.monto, symbol: sale.simboloMoneda),
        ),
        for (final p in sale.pagos)
          AppDetailRow(label: p.metodo, value: formatMoney(p.monto, symbol: sale.simboloMoneda)),
      ],
    ),
  );
  if (verDetalle == true && context.mounted) {
    await showDocumentDetail(context, sale);
  }
}
