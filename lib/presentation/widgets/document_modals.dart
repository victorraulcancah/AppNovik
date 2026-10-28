import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/constants/app_constants.dart';
import '../../core/utils/format.dart';
import '../../domain/entities/document_entity.dart';
import '../components/components.dart';

String _dateTime(DateTime? d) =>
    d == null ? '-' : DateFormat(AppConstants.dateTimeFormat).format(d);

/// Estado del documento como badge: en ventas, activo o eliminado; en
/// cotizaciones, usada, reservada o sin reserva.
({String label, AppBadgeTone tone}) documentStatus(DocumentEntity d) {
  if (d.kind == DocumentKind.cotizacion) {
    if (!d.activo) return (label: 'Usada', tone: AppBadgeTone.neutral);
    return d.reservado == true
        ? (label: 'Reservada', tone: AppBadgeTone.success)
        : (label: 'Sin reserva', tone: AppBadgeTone.warning);
  }
  return d.activo
      ? (label: 'Activo', tone: AppBadgeTone.success)
      : (label: 'Eliminado', tone: AppBadgeTone.danger);
}

/// Modal "ver detalle" de una venta o cotización: general, productos y pagos.
Future<bool?> showDocumentDetail(BuildContext context, DocumentEntity d) {
  final status = documentStatus(d);

  return showAppModal(
    context,
    title: d.numero,
    subtitle: d.cliente,
    icon: d.kind == DocumentKind.cotizacion
        ? Icons.request_quote_outlined
        : Icons.receipt_long_outlined,
    primaryLabel: null,
    secondaryLabel: 'Cerrar',
    tabs: [
      AppTabItem(
        label: 'General',
        icon: Icons.info_outline,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppDetailRow(label: 'Comprobante', value: d.comprobante),
            AppDetailRow(label: 'Cliente', value: d.cliente),
            AppDetailRow(label: 'Fecha', value: _dateTime(d.creado)),
            AppDetailRow(
              label: 'Total',
              value: formatMoney(d.monto, symbol: d.simboloMoneda),
            ),
            AppDetailRow(label: 'Registrado por', value: d.usuario),
            AppDetailRow(label: 'Vendedor', value: d.vendedor),
            AppDetailRow(label: 'Almacén', value: d.almacen),
            AppDetailRow(
              label: 'Estado',
              valueWidget: AppStatusBadge(label: status.label, tone: status.tone),
            ),
            if (!d.activo && d.kind == DocumentKind.venta) ...[
              AppDetailRow(label: 'Anulado por', value: d.anuladoPor ?? 'Sin registro'),
              if (d.anuladoAt != null)
                AppDetailRow(label: 'Anulado el', value: _dateTime(d.anuladoAt)),
            ],
            if (d.observaciones != null && d.observaciones!.isNotEmpty)
              AppDetailRow(label: 'Observaciones', value: d.observaciones),
          ],
        ),
      ),
      AppTabItem(
        label: 'Productos',
        icon: Icons.shopping_bag_outlined,
        badge: d.items.length,
        child: d.items.isEmpty
            ? const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: Text('Sin productos')),
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final i in d.items)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: AppItemCard(
                        title: i.name,
                        subtitle: [
                          if (i.codigo != null && i.codigo!.isNotEmpty) i.codigo!,
                          if (i.marca != null && i.marca!.isNotEmpty) i.marca!,
                        ].join(' · '),
                        columns: [
                          AppItemColumn('Cant.', formatQuantity(i.cantidad)),
                          AppItemColumn(
                            'Precio',
                            formatMoney(i.precio, symbol: i.dolares ? r'$' : 'S/'),
                          ),
                          AppItemColumn(
                            'Subtotal',
                            formatMoney(i.subtotal, symbol: i.dolares ? r'$' : 'S/'),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
      ),
      if (d.pagos.isNotEmpty)
        AppTabItem(
          label: 'Pagos',
          icon: Icons.payments_outlined,
          badge: d.pagos.length,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final p in d.pagos)
                AppDetailRow(
                  label: p.metodo,
                  value: formatMoney(p.monto, symbol: d.simboloMoneda),
                ),
            ],
          ),
        ),
    ],
  );
}
